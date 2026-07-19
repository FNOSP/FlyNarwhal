package updater

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const (
	ApplicationExecutable     = "FlyNarwhal.exe"
	ApplicationID             = "9A262498-6C63-4816-A346-056028719600"
	installerManifestFileName = "installer-manifest.json"
	installerManifestSchema   = 1
)

var SilentInstallerArguments = []string{
	"/SILENT",
	"/SP-",
	"/SUPPRESSMSGBOXES",
	"/NORESTART",
	"/CLOSEAPPLICATIONS",
}

type Paths struct {
	InstallerPath     string
	InstallDir        string
	CacheRoot         string
	UpdatesDir        string
	ResultPath        string
	LogPath           string
	InstallerIdentity FileIdentity
	InstallerManifest string
}

type FileIdentity struct {
	Path   string `json:"path"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
}

func (identity FileIdentity) matches(other FileIdentity) bool {
	return samePath(identity.Path, other.Path) &&
		identity.Size == other.Size &&
		strings.EqualFold(identity.SHA256, other.SHA256)
}

type installerManifest struct {
	SchemaVersion int          `json:"schemaVersion"`
	Installer     FileIdentity `json:"installer"`
}

func ParseArguments(arguments []string) (string, string, error) {
	if len(arguments) != 2 {
		return "", "", fmt.Errorf("expected exactly two arguments, got %d", len(arguments))
	}
	return arguments[0], arguments[1], nil
}

func ValidatePaths(installerPath string, installDir string, environment map[string]string) (Paths, error) {
	localAppData := strings.TrimSpace(environment["LOCALAPPDATA"])
	if localAppData == "" {
		return Paths{}, errors.New("LOCALAPPDATA is unavailable")
	}

	cacheRoot, err := filepath.Abs(filepath.Join(os.TempDir(), "updates"))
	if err != nil {
		return Paths{}, fmt.Errorf("resolve cache root: %w", err)
	}
	if err := validateExistingDirectory(cacheRoot); err != nil {
		return Paths{}, fmt.Errorf("unsafe update cache root: %w", err)
	}

	canonicalInstallerPath, err := canonicalExistingFile(installerPath)
	if err != nil {
		return Paths{}, fmt.Errorf("invalid installer: %w", err)
	}
	if !strings.EqualFold(filepath.Ext(canonicalInstallerPath), ".exe") {
		return Paths{}, errors.New("installer must have an .exe extension")
	}
	if !isWithinRoot(cacheRoot, canonicalInstallerPath) {
		return Paths{}, errors.New("installer is outside the update cache root")
	}
	if err := validatePathComponents(cacheRoot, filepath.Dir(canonicalInstallerPath)); err != nil {
		return Paths{}, fmt.Errorf("unsafe installer staging directory: %w", err)
	}

	canonicalInstallDir, err := filepath.Abs(filepath.Clean(installDir))
	if err != nil {
		return Paths{}, fmt.Errorf("resolve install directory: %w", err)
	}
	trustedInstallDir, err := filepath.Abs(filepath.Join(localAppData, "FlyNarwhal"))
	if err != nil {
		return Paths{}, fmt.Errorf("resolve trusted install directory: %w", err)
	}
	if !samePath(canonicalInstallDir, trustedInstallDir) {
		return Paths{}, errors.New("install directory does not match the trusted FlyNarwhal directory")
	}
	if err := validateExistingDirectory(trustedInstallDir); err != nil {
		return Paths{}, fmt.Errorf("unsafe installation directory: %w", err)
	}

	updatesDirectory := filepath.Join(trustedInstallDir, "updates")
	if err := ensureSafeDirectory(updatesDirectory); err != nil {
		return Paths{}, fmt.Errorf("unsafe installation updates directory: %w", err)
	}

	installerIdentity, err := identifyFile(canonicalInstallerPath)
	if err != nil {
		return Paths{}, fmt.Errorf("identify installer: %w", err)
	}
	manifestPath := filepath.Join(filepath.Dir(canonicalInstallerPath), installerManifestFileName)
	if err := validateInstallerManifest(manifestPath, installerIdentity); err != nil {
		return Paths{}, err
	}

	return Paths{
		InstallerPath:     canonicalInstallerPath,
		InstallDir:        trustedInstallDir,
		CacheRoot:         cacheRoot,
		UpdatesDir:        updatesDirectory,
		ResultPath:        filepath.Join(updatesDirectory, "install-result.json"),
		LogPath:           filepath.Join(updatesDirectory, "updater.log"),
		InstallerIdentity: installerIdentity,
		InstallerManifest: manifestPath,
	}, nil
}

func VerifyInstallerIdentity(paths Paths) error {
	if err := validatePathComponents(paths.CacheRoot, filepath.Dir(paths.InstallerPath)); err != nil {
		return fmt.Errorf("unsafe installer staging directory: %w", err)
	}
	currentIdentity, err := identifyFile(paths.InstallerPath)
	if err != nil {
		return fmt.Errorf("identify installer: %w", err)
	}
	if !paths.InstallerIdentity.matches(currentIdentity) {
		return errors.New("installer identity changed after validation")
	}
	return validateInstallerManifest(paths.InstallerManifest, currentIdentity)
}

func ValidateApplicationExecutable(paths Paths) (string, error) {
	applicationPath := filepath.Join(paths.InstallDir, ApplicationExecutable)
	if err := validatePathComponents(paths.InstallDir, filepath.Dir(applicationPath)); err != nil {
		return "", fmt.Errorf("unsafe application directory: %w", err)
	}
	canonicalApplicationPath, err := canonicalExistingFile(applicationPath)
	if err != nil {
		return "", fmt.Errorf("invalid application executable: %w", err)
	}
	if !isWithinRoot(paths.InstallDir, canonicalApplicationPath) {
		return "", errors.New("application executable is outside the trusted installation directory")
	}
	return canonicalApplicationPath, nil
}

func identifyFile(filePath string) (FileIdentity, error) {
	return inspectRegularFile(filePath)
}

func validateInstallerManifest(manifestPath string, installerIdentity FileIdentity) error {
	manifestFile, err := os.Open(manifestPath)
	if err != nil {
		return fmt.Errorf("open protected installer manifest: %w", err)
	}
	defer manifestFile.Close()

	manifestInfo, err := manifestFile.Stat()
	if err != nil {
		return fmt.Errorf("stat protected installer manifest: %w", err)
	}
	if !manifestInfo.Mode().IsRegular() || manifestInfo.Size() > 64*1024 {
		return errors.New("installer manifest is not a safe regular file")
	}
	var manifest installerManifest
	if err := json.NewDecoder(io.LimitReader(manifestFile, 64*1024)).Decode(&manifest); err != nil {
		return fmt.Errorf("decode protected installer manifest: %w", err)
	}
	if manifest.SchemaVersion != installerManifestSchema || !installerIdentity.matches(manifest.Installer) {
		return errors.New("installer manifest does not match the staged installer")
	}
	return nil
}

func canonicalExistingFile(filePath string) (string, error) {
	absolutePath, err := filepath.Abs(filepath.Clean(filePath))
	if err != nil {
		return "", err
	}
	fileInfo, err := os.Lstat(absolutePath)
	if err != nil {
		return "", err
	}
	if fileInfo.Mode()&os.ModeSymlink != 0 || fileInfo.Mode()&os.ModeIrregular != 0 || !fileInfo.Mode().IsRegular() {
		return "", errors.New("path is not a regular non-reparse file")
	}
	return absolutePath, nil
}

func validateExistingDirectory(directoryPath string) error {
	fileInfo, err := os.Lstat(directoryPath)
	if err != nil {
		return err
	}
	if fileInfo.Mode()&os.ModeSymlink != 0 || !fileInfo.IsDir() {
		return errors.New("path is not a non-reparse directory")
	}
	return nil
}

func ensureSafeDirectory(directoryPath string) error {
	if err := os.MkdirAll(directoryPath, 0o700); err != nil {
		return err
	}
	return validateExistingDirectory(directoryPath)
}

func validatePathComponents(rootPath string, candidateDirectory string) error {
	if !isWithinRoot(rootPath, candidateDirectory) && !samePath(rootPath, candidateDirectory) {
		return errors.New("directory is outside trusted root")
	}
	currentPath := rootPath
	if err := validateExistingDirectory(currentPath); err != nil {
		return err
	}
	relativePath, err := filepath.Rel(rootPath, candidateDirectory)
	if err != nil {
		return err
	}
	for _, component := range strings.Split(relativePath, string(filepath.Separator)) {
		if component == "." || component == "" {
			continue
		}
		currentPath = filepath.Join(currentPath, component)
		if err := validateExistingDirectory(currentPath); err != nil {
			return err
		}
	}
	return nil
}

func isWithinRoot(rootPath string, candidatePath string) bool {
	relativePath, err := filepath.Rel(rootPath, candidatePath)
	if err != nil {
		return false
	}
	return relativePath != ".." && !strings.HasPrefix(relativePath, ".."+string(filepath.Separator)) && !filepath.IsAbs(relativePath)
}

func samePath(firstPath string, secondPath string) bool {
	return strings.EqualFold(filepath.Clean(firstPath), filepath.Clean(secondPath))
}

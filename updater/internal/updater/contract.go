package updater

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"updater/internal/lang"
)

const (
	ApplicationExecutable     = "FlyNarwhal.exe"
	ApplicationID             = "9A262498-6C63-4816-A346-056028719600"
	UpdaterExecutable         = "updater.exe"
	installerManifestFileName = "installer-manifest.json"
	installerManifestSchema   = 1
)

var baseSilentInstallerArguments = []string{
	"/SP-",
	"/NORESTART",
	"/CLOSEAPPLICATIONS",
}

func SilentInstallerArguments(installDir string) []string {
	arguments := append([]string(nil), baseSilentInstallerArguments...)
	return append(arguments, "/DIR="+installDir)
}

type Paths struct {
	InstallerPath          string
	InstallDir             string
	CacheRoot              string
	UpdatesDir             string
	ResultPath             string
	LogPath                string
	InstallerIdentity      FileIdentity
	InstallerManifest      string
	RunningApplicationPath string
	RunningApplicationPID  int
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

func ParseArguments(arguments []string) (string, string, int, error) {
	if len(arguments) != 2 && len(arguments) != 3 {
		return "", "", 0, lang.Error("expected_two_or_three_arguments", len(arguments))
	}
	runningApplicationPID := 0
	if len(arguments) == 3 {
		parsedProcessID, err := strconv.Atoi(strings.TrimSpace(arguments[2]))
		if err != nil || parsedProcessID <= 0 {
			return "", "", 0, lang.Error("invalid_running_application_pid")
		}
		runningApplicationPID = parsedProcessID
	}
	return arguments[0], arguments[1], runningApplicationPID, nil
}

func ValidatePaths(installerPath string, installDir string, environment map[string]string) (Paths, error) {
	localAppData := strings.TrimSpace(environment["LOCALAPPDATA"])
	if localAppData == "" {
		return Paths{}, lang.Error("localappdata_unavailable")
	}

	cacheRoot, err := filepath.Abs(filepath.Join(os.TempDir(), "updates"))
	if err != nil {
		return Paths{}, lang.Wrap(err, "resolve_cache_root")
	}
	if err := validateExistingDirectory(cacheRoot); err != nil {
		return Paths{}, lang.Wrap(err, "unsafe_update_cache_root")
	}

	canonicalInstallerPath, err := canonicalExistingFile(installerPath)
	if err != nil {
		return Paths{}, lang.Wrap(err, "invalid_installer")
	}
	if !strings.EqualFold(filepath.Ext(canonicalInstallerPath), ".exe") {
		return Paths{}, lang.Error("installer_must_have_exe_extension")
	}
	if !isWithinRoot(cacheRoot, canonicalInstallerPath) {
		return Paths{}, lang.Error("installer_outside_update_cache_root")
	}
	if err := validatePathComponents(cacheRoot, filepath.Dir(canonicalInstallerPath)); err != nil {
		return Paths{}, lang.Wrap(err, "unsafe_installer_staging_directory")
	}

	canonicalInstallDir, err := filepath.Abs(filepath.Clean(installDir))
	if err != nil {
		return Paths{}, lang.Wrap(err, "resolve_install_directory")
	}
	trustedInstallDir, err := filepath.Abs(filepath.Join(localAppData, "FlyNarwhal"))
	if err != nil {
		return Paths{}, lang.Wrap(err, "resolve_trusted_install_directory")
	}
	if !samePath(canonicalInstallDir, trustedInstallDir) {
		return Paths{}, lang.Error("install_directory_mismatch")
	}
	if err := validateExistingDirectory(trustedInstallDir); err != nil {
		return Paths{}, lang.Wrap(err, "unsafe_installation_directory")
	}

	updatesDirectory := filepath.Join(trustedInstallDir, "updates")
	if err := ensureSafeDirectory(updatesDirectory); err != nil {
		return Paths{}, lang.Wrap(err, "unsafe_installation_updates_directory")
	}

	installerIdentity, err := identifyFile(canonicalInstallerPath)
	if err != nil {
		return Paths{}, lang.Wrap(err, "identify_installer")
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
		return lang.Wrap(err, "unsafe_installer_staging_directory")
	}
	currentIdentity, err := identifyFile(paths.InstallerPath)
	if err != nil {
		return lang.Wrap(err, "identify_installer")
	}
	if !paths.InstallerIdentity.matches(currentIdentity) {
		return lang.Error("installer_identity_changed_after_validation")
	}
	return validateInstallerManifest(paths.InstallerManifest, currentIdentity)
}

func ExpectedApplicationExecutablePath(paths Paths) (string, error) {
	applicationPath := filepath.Join(paths.InstallDir, ApplicationExecutable)
	if err := validatePathComponents(paths.InstallDir, filepath.Dir(applicationPath)); err != nil {
		return "", lang.Wrap(err, "unsafe_application_directory")
	}
	canonicalApplicationPath, err := filepath.Abs(filepath.Clean(applicationPath))
	if err != nil {
		return "", lang.Wrap(err, "resolve_application_executable")
	}
	if !isWithinRoot(paths.InstallDir, canonicalApplicationPath) {
		return "", lang.Error("application_executable_outside_trusted_root")
	}
	return canonicalApplicationPath, nil
}

func ValidateApplicationExecutable(paths Paths) (string, error) {
	applicationPath, err := ExpectedApplicationExecutablePath(paths)
	if err != nil {
		return "", err
	}
	canonicalApplicationPath, err := canonicalExistingFile(applicationPath)
	if err != nil {
		return "", lang.Wrap(err, "invalid_application_executable")
	}
	if !isWithinRoot(paths.InstallDir, canonicalApplicationPath) {
		return "", lang.Error("application_executable_outside_trusted_root")
	}
	return canonicalApplicationPath, nil
}

func identifyFile(filePath string) (FileIdentity, error) {
	return inspectRegularFile(filePath)
}

func validateInstallerManifest(manifestPath string, installerIdentity FileIdentity) error {
	manifestFile, err := os.Open(manifestPath)
	if err != nil {
		return lang.Wrap(err, "open_protected_installer_manifest")
	}
	defer manifestFile.Close()

	manifestInfo, err := manifestFile.Stat()
	if err != nil {
		return lang.Wrap(err, "stat_protected_installer_manifest")
	}
	if !manifestInfo.Mode().IsRegular() || manifestInfo.Size() > 64*1024 {
		return lang.Error("installer_manifest_not_safe_regular_file")
	}
	var manifest installerManifest
	if err := json.NewDecoder(io.LimitReader(manifestFile, 64*1024)).Decode(&manifest); err != nil {
		return lang.Wrap(err, "decode_protected_installer_manifest")
	}
	if manifest.SchemaVersion != installerManifestSchema || !installerIdentity.matches(manifest.Installer) {
		return lang.Error("installer_manifest_mismatch")
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
		return "", lang.Error("path_not_regular_non_reparse_file")
	}
	return absolutePath, nil
}

func validateExistingDirectory(directoryPath string) error {
	fileInfo, err := os.Lstat(directoryPath)
	if err != nil {
		return err
	}
	if fileInfo.Mode()&os.ModeSymlink != 0 || !fileInfo.IsDir() {
		return lang.Error("path_not_non_reparse_directory")
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
		return lang.Error("directory_outside_trusted_root")
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

package updater

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestParseArgumentsRequiresExactlyTwoBusinessArguments(t *testing.T) {
	t.Parallel()
	for _, arguments := range [][]string{nil, {"one"}, {"one", "two", "three"}} {
		if _, _, err := ParseArguments(arguments); err == nil {
			t.Fatalf("ParseArguments(%q) accepted invalid count", arguments)
		}
	}
	installerPath, installDir, err := ParseArguments([]string{"安装 包.exe", "安装 目录"})
	if err != nil || installerPath != "安装 包.exe" || installDir != "安装 目录" {
		t.Fatalf("ParseArguments did not preserve Unicode paths: %q %q %v", installerPath, installDir, err)
	}
}

func TestValidatePathsAcceptsChineseAndSpacePathsInsideCache(t *testing.T) {
	cacheRoot := filepath.Join(os.TempDir(), "updates")
	installerPath := filepath.Join(cacheRoot, "中文 版本", "FlyNarwhal 安装包.exe")
	if err := os.MkdirAll(filepath.Dir(installerPath), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(installerPath, []byte("fixture"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(filepath.Join(cacheRoot, "中文 版本")) })

	localAppData := filepath.Join(t.TempDir(), "本地 数据")
	installDir := filepath.Join(localAppData, "FlyNarwhal")
	if err := os.MkdirAll(installDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := writeInstallerManifest(installerPath); err != nil {
		t.Fatal(err)
	}
	paths, err := ValidatePaths(installerPath, installDir, map[string]string{"LOCALAPPDATA": localAppData})
	if err != nil {
		t.Fatalf("ValidatePaths rejected valid paths: %v", err)
	}
	if !samePath(paths.InstallerPath, installerPath) || !samePath(paths.InstallDir, installDir) {
		t.Fatalf("ValidatePaths changed path identity: %#v", paths)
	}
}

func TestValidatePathsRejectsUnsafeInstallerAndInstallDirectory(t *testing.T) {
	outsideInstaller := filepath.Join(t.TempDir(), "outside.exe")
	if err := os.WriteFile(outsideInstaller, []byte("fixture"), 0o600); err != nil {
		t.Fatal(err)
	}
	localAppData := t.TempDir()
	trustedInstallDir := filepath.Join(localAppData, "FlyNarwhal")
	if _, err := ValidatePaths(outsideInstaller, trustedInstallDir, map[string]string{"LOCALAPPDATA": localAppData}); err == nil {
		t.Fatal("ValidatePaths accepted installer outside cache")
	}

	cacheInstaller := filepath.Join(os.TempDir(), "updates", "unsafe-test", "installer.txt")
	if err := os.MkdirAll(filepath.Dir(cacheInstaller), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(cacheInstaller, []byte("fixture"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(filepath.Dir(cacheInstaller)) })
	if _, err := ValidatePaths(cacheInstaller, trustedInstallDir, map[string]string{"LOCALAPPDATA": localAppData}); err == nil {
		t.Fatal("ValidatePaths accepted non-executable installer")
	}

	executableInstaller := strings.TrimSuffix(cacheInstaller, ".txt") + ".exe"
	if err := os.Rename(cacheInstaller, executableInstaller); err != nil {
		t.Fatal(err)
	}
	if _, err := ValidatePaths(executableInstaller, filepath.Join(localAppData, "Other"), map[string]string{"LOCALAPPDATA": localAppData}); err == nil {
		t.Fatal("ValidatePaths accepted arbitrary install directory")
	}
}

func TestRunnerUsesFixedArgumentsAndSuccessfulBehavior(t *testing.T) {
	processes := &fakeProcesses{}
	files := &fakeFiles{}
	paths := Paths{
		InstallerPath: `C:\缓存 目录\安装包.exe`,
		InstallDir:    `C:\用户 数据\FlyNarwhal`,
		ResultPath:    `C:\用户 数据\FlyNarwhal\updates\install-result.json`,
	}
	runner := newTestRunner(processes, files)
	if err := runner.Execute(paths); err != nil {
		t.Fatalf("Execute failed: %v", err)
	}
	expectedArguments := SilentInstallerArguments(paths.InstallDir)
	if !reflect.DeepEqual(processes.runArguments, expectedArguments) {
		t.Fatalf("unexpected installer arguments: %q", processes.runArguments)
	}
	if files.removedPath != paths.InstallerPath {
		t.Fatalf("installer was not deleted: %q", files.removedPath)
	}
	if processes.startedExecutable != filepath.Join(paths.InstallDir, ApplicationExecutable) {
		t.Fatalf("unexpected application path: %q", processes.startedExecutable)
	}
	if files.result.Status != "success" {
		t.Fatalf("unexpected result: %#v", files.result)
	}
}

func TestRunnerFailureKeepsInstallerAndDoesNotLaunchApplication(t *testing.T) {
	processes := &fakeProcesses{runExitCode: 7}
	files := &fakeFiles{}
	paths := Paths{InstallerPath: "installer.exe", InstallDir: "install", ResultPath: "result.json"}
	runner := newTestRunner(processes, files)
	if err := runner.Execute(paths); err == nil {
		t.Fatal("Execute accepted a nonzero installer exit code")
	}
	if files.removedPath != "" {
		t.Fatalf("failed installer was deleted: %q", files.removedPath)
	}
	if processes.startedExecutable != "" {
		t.Fatalf("old application was launched after failure: %q", processes.startedExecutable)
	}
	if files.result.Status != "failure" || files.result.Code != "installer_exit_nonzero" {
		t.Fatalf("unexpected failure result: %#v", files.result)
	}
}

func TestRunnerReturnsWaitTimeoutWithoutLaunchingInstaller(t *testing.T) {
	processes := &fakeProcesses{waitError: context.DeadlineExceeded}
	files := &fakeFiles{}
	runner := newTestRunner(processes, files)
	if err := runner.Execute(Paths{ResultPath: "result.json"}); err == nil {
		t.Fatal("Execute accepted process wait timeout")
	}
	if processes.runExecutable != "" {
		t.Fatal("installer launched before application exit")
	}
}

func TestCleanupLegacyInstallationDeletesOnlyVerifiedProgramFiles(t *testing.T) {
	installDir := t.TempDir()
	mustWriteFile(t, filepath.Join(installDir, ApplicationExecutable), []byte("legacy exe"))
	mustWriteFile(t, filepath.Join(installDir, "unins000.exe"), []byte("legacy uninstaller"))
	mustWriteFile(t, filepath.Join(installDir, "unins000.dat"), []byte("legacy metadata"))
	mustWriteFile(t, filepath.Join(installDir, "runtime", "bin", "java.exe"), []byte("legacy runtime"))
	mustWriteFile(t, filepath.Join(installDir, "app", ".jpackage.xml"), []byte("<xml/>"))
	mustWriteFile(t, filepath.Join(installDir, "app", "FlyNarwhal.cfg"), []byte("legacy cfg"))
	mustWriteFile(t, filepath.Join(installDir, "app", "composeApp-jvm.jar"), []byte("legacy jar"))
	mustWriteFile(t, filepath.Join(installDir, "app", "resources", "kcef-bundle-1.11.3", "java.exe"), []byte("legacy kcef"))
	mustWriteFile(t, filepath.Join(installDir, "app", "resources", "lib", "libvlc.dll"), []byte("legacy lib"))
	mustWriteFile(t, filepath.Join(installDir, "app", "resources", "kcef-cache-1.11.3", "Local State"), []byte("legacy cache"))
	mustWriteFile(t, filepath.Join(installDir, "logs", "FlyNarwhal.log"), []byte("legacy log"))
	mustWriteFile(t, filepath.Join(installDir, "updates", "install-result.json"), []byte("{}"))
	mustWriteFile(t, filepath.Join(installDir, UpdaterExecutable), []byte("current updater"))

	if err := CleanupLegacyInstallation(Paths{InstallDir: installDir}); err != nil {
		t.Fatalf("CleanupLegacyInstallation failed: %v", err)
	}

	assertPathMissing(t, filepath.Join(installDir, ApplicationExecutable))
	assertPathMissing(t, filepath.Join(installDir, "unins000.exe"))
	assertPathMissing(t, filepath.Join(installDir, "unins000.dat"))
	assertPathMissing(t, filepath.Join(installDir, "runtime", "bin", "java.exe"))
	assertPathMissing(t, filepath.Join(installDir, "app", ".jpackage.xml"))
	assertPathMissing(t, filepath.Join(installDir, "app", "composeApp-jvm.jar"))
	assertPathMissing(t, filepath.Join(installDir, "app", "resources", "kcef-bundle-1.11.3"))
	assertPathMissing(t, filepath.Join(installDir, "app", "resources", "lib"))

	assertPathMissing(t, filepath.Join(installDir, "logs", "FlyNarwhal.log"))
	assertPathExists(t, filepath.Join(installDir, "updates", "install-result.json"))
	assertPathMissing(t, filepath.Join(installDir, "app", "resources", "kcef-cache-1.11.3", "Local State"))
	assertPathExists(t, filepath.Join(installDir, UpdaterExecutable))
}

func TestRunnerStopsBeforeInstallerWhenLegacyCleanupFails(t *testing.T) {
	processes := &fakeProcesses{}
	files := &fakeFiles{}
	runner := newTestRunner(processes, files)
	runner.CleanupLegacyFiles = func(Paths) error {
		return errors.New("cleanup failed")
	}

	err := runner.Execute(Paths{
		InstallerPath: "installer.exe",
		InstallDir:    "install",
		ResultPath:    "result.json",
	})
	if err == nil {
		t.Fatal("Execute accepted legacy cleanup failure")
	}
	if processes.runExecutable != "" {
		t.Fatal("installer launched after cleanup failure")
	}
	if files.result.Code != "legacy_cleanup_failed" {
		t.Fatalf("unexpected result code: %#v", files.result)
	}
}

func TestCleanupLegacyInstallationWithRealKmpSnapshot(t *testing.T) {
	sourceDir := os.Getenv("FLYNARWHAL_REAL_KMP_INSTALL_DIR")
	if sourceDir == "" {
		t.Skip("FLYNARWHAL_REAL_KMP_INSTALL_DIR is not set")
	}

	installDir := t.TempDir()
	for _, entryName := range []string{
		ApplicationExecutable,
		"app",
		"logs",
		"runtime",
		"unins000.dat",
		"unins000.exe",
		"unins000.msg",
	} {
		sourcePath := filepath.Join(sourceDir, entryName)
		if _, err := os.Stat(sourcePath); errors.Is(err, os.ErrNotExist) {
			continue
		} else if err != nil {
			t.Fatalf("stat %s: %v", sourcePath, err)
		}
		targetPath := filepath.Join(installDir, entryName)
		if err := copyTree(sourcePath, targetPath); err != nil {
			t.Fatalf("copy %s: %v", sourcePath, err)
		}
	}
	mustWriteFile(t, filepath.Join(installDir, "updates", "install-result.json"), []byte("{}"))
	mustWriteFile(t, filepath.Join(installDir, UpdaterExecutable), []byte("current updater"))

	if err := CleanupLegacyInstallation(Paths{InstallDir: installDir}); err != nil {
		t.Fatalf("CleanupLegacyInstallation failed on real snapshot: %v", err)
	}

	assertPathMissing(t, filepath.Join(installDir, ApplicationExecutable))
	assertPathMissing(t, filepath.Join(installDir, "logs"))
	assertPathMissing(t, filepath.Join(installDir, "runtime"))
	assertPathMissing(t, filepath.Join(installDir, "app", "FlyNarwhal.cfg"))
	assertPathMissing(t, filepath.Join(installDir, "app", "resources", "kcef-bundle-1.11.3"))
	assertPathMissing(t, filepath.Join(installDir, "app", "resources", "kcef-cache-1.11.3"))
	assertPathExists(t, filepath.Join(installDir, "updates", "install-result.json"))
	assertPathExists(t, filepath.Join(installDir, UpdaterExecutable))
}

func fixedTime() time.Time {
	return time.Date(2026, 7, 19, 12, 0, 0, 0, time.UTC)
}

func writeInstallerManifest(installerPath string) error {
	identity, err := identifyFile(installerPath)
	if err != nil {
		return err
	}
	encodedManifest, err := json.Marshal(installerManifest{
		SchemaVersion: installerManifestSchema,
		Installer:     identity,
	})
	if err != nil {
		return err
	}
	return os.WriteFile(
		filepath.Join(filepath.Dir(installerPath), installerManifestFileName),
		encodedManifest,
		0o600,
	)
}
func newTestRunner(processes *fakeProcesses, files *fakeFiles) Runner {
	return Runner{
		Processes: processes,
		Files:     files,
		Now:       fixedTime,
		VerifyInstaller: func(Paths) error {
			return nil
		},
		ValidateApplication: func(paths Paths) (string, error) {
			return filepath.Join(paths.InstallDir, ApplicationExecutable), nil
		},
		CleanupLegacyFiles: func(Paths) error {
			return nil
		},
	}
}

func mustWriteFile(t *testing.T, filePath string, contents []byte) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(filePath), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filePath, contents, 0o600); err != nil {
		t.Fatal(err)
	}
}

func assertPathExists(t *testing.T, filePath string) {
	t.Helper()
	if _, err := os.Stat(filePath); err != nil {
		t.Fatalf("expected path to exist: %s (%v)", filePath, err)
	}
}

func assertPathMissing(t *testing.T, filePath string) {
	t.Helper()
	if _, err := os.Stat(filePath); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("expected path to be removed: %s (%v)", filePath, err)
	}
}

func copyTree(sourcePath string, targetPath string) error {
	fileInfo, err := os.Lstat(sourcePath)
	if err != nil {
		return err
	}
	if fileInfo.Mode()&os.ModeSymlink != 0 {
		return errors.New("copyTree does not support symlinks")
	}
	if !fileInfo.IsDir() {
		return copyFile(sourcePath, targetPath, fileInfo.Mode())
	}
	if err := os.MkdirAll(targetPath, fileInfo.Mode().Perm()); err != nil {
		return err
	}
	entries, err := os.ReadDir(sourcePath)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if err := copyTree(
			filepath.Join(sourcePath, entry.Name()),
			filepath.Join(targetPath, entry.Name()),
		); err != nil {
			return err
		}
	}
	return nil
}

func copyFile(sourcePath string, targetPath string, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(targetPath), 0o700); err != nil {
		return err
	}
	sourceFile, err := os.Open(sourcePath)
	if err != nil {
		return err
	}
	defer sourceFile.Close()

	targetFile, err := os.OpenFile(targetPath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode.Perm())
	if err != nil {
		return err
	}
	defer targetFile.Close()

	if _, err := io.Copy(targetFile, sourceFile); err != nil {
		return err
	}
	return nil
}

type fakeProcesses struct {
	waitError         error
	runExitCode       int
	runError          error
	runExecutable     string
	runArguments      []string
	startedExecutable string
	startError        error
}

func (processes *fakeProcesses) WaitForExit(_ context.Context, executablePath string) error {
	if filepath.Base(executablePath) != ApplicationExecutable {
		return errors.New("unexpected executable name")
	}
	return processes.waitError
}

func (processes *fakeProcesses) Run(_ context.Context, executable string, arguments []string) (int, error) {
	processes.runExecutable = executable
	processes.runArguments = append([]string(nil), arguments...)
	return processes.runExitCode, processes.runError
}

func (processes *fakeProcesses) Start(executable string, _ []string) error {
	processes.startedExecutable = executable
	return processes.startError
}

type fakeFiles struct {
	removedPath string
	result      InstallResult
}

func (files *fakeFiles) Remove(filePath string) error {
	files.removedPath = filePath
	return nil
}

func (files *fakeFiles) WriteResult(_ string, result InstallResult) error {
	files.result = result
	return nil
}

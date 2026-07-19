package updater

import (
	"context"
	"encoding/json"
	"errors"
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
	if !reflect.DeepEqual(processes.runArguments, SilentInstallerArguments) {
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
	}
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

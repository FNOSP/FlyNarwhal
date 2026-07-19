package updater

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type OSProcessController struct{}

func (OSProcessController) WaitForExit(contextValue context.Context, applicationPath string) error {
	pollTimer := time.NewTicker(250 * time.Millisecond)
	defer pollTimer.Stop()
	for {
		running, err := isApplicationRunning(contextValue, applicationPath)
		if err != nil {
			return err
		}
		if !running {
			return nil
		}
		select {
		case <-contextValue.Done():
			return contextValue.Err()
		case <-pollTimer.C:
		}
	}
}

func (OSProcessController) Run(contextValue context.Context, executable string, arguments []string) (int, error) {
	command := exec.CommandContext(contextValue, executable, arguments...)
	err := command.Run()
	if err == nil {
		return 0, nil
	}
	var exitError *exec.ExitError
	if errors.As(err, &exitError) {
		return exitError.ExitCode(), nil
	}
	return -1, err
}

func (OSProcessController) Start(executable string, arguments []string) error {
	command := exec.Command(executable, arguments...)
	return command.Start()
}

func isApplicationRunning(contextValue context.Context, applicationPath string) (bool, error) {
	const processQuery = "Get-CimInstance Win32_Process -Filter \"Name = 'FlyNarwhal.exe'\" | Select-Object -ExpandProperty ExecutablePath | ConvertTo-Json -Compress"
	command := exec.CommandContext(
		contextValue,
		"powershell.exe",
		"-NoProfile",
		"-NonInteractive",
		"-Command",
		processQuery,
	)
	output, err := command.Output()
	if err != nil {
		return false, err
	}
	var executablePaths []string
	if err := json.Unmarshal(output, &executablePaths); err != nil {
		var executablePath string
		if singlePathError := json.Unmarshal(output, &executablePath); singlePathError != nil {
			if strings.TrimSpace(string(output)) == "" || strings.TrimSpace(string(output)) == "null" {
				return false, nil
			}
			return false, err
		}
		executablePaths = []string{executablePath}
	}
	for _, executablePath := range executablePaths {
		if executablePath == "" {
			continue
		}
		if samePath(filepath.Clean(executablePath), filepath.Clean(applicationPath)) {
			return true, nil
		}
	}
	return false, nil
}

type OSFileController struct{}

func (OSFileController) Remove(filePath string) error {
	return os.Remove(filePath)
}

func (OSFileController) WriteResult(resultPath string, result InstallResult) error {
	if err := result.Validate(); err != nil {
		return err
	}
	if err := ensureSafeDirectory(filepath.Dir(resultPath)); err != nil {
		return err
	}
	if _, err := os.Lstat(resultPath); err == nil {
		if _, err := canonicalExistingFile(resultPath); err != nil {
			return err
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	encodedResult, err := json.Marshal(result)
	if err != nil {
		return err
	}
	temporaryFile, err := os.CreateTemp(filepath.Dir(resultPath), ".install-result-*.tmp")
	if err != nil {
		return err
	}
	temporaryPath := temporaryFile.Name()
	defer os.Remove(temporaryPath)
	if err := temporaryFile.Chmod(0o600); err != nil {
		temporaryFile.Close()
		return err
	}
	if _, err := temporaryFile.Write(append(encodedResult, '\n')); err != nil {
		temporaryFile.Close()
		return err
	}
	if err := temporaryFile.Close(); err != nil {
		return err
	}
	if _, err := canonicalExistingFile(temporaryPath); err != nil {
		return err
	}
	return os.Rename(temporaryPath, resultPath)
}

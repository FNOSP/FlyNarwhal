package updater

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"time"
)

const (
	processExitTimeout      = 60 * time.Second
	installerProcessTimeout = 20 * time.Minute
	installResultSchema     = 1
)

type ProcessController interface {
	WaitForExit(context.Context, string) error
	Run(context.Context, string, []string) (int, error)
	Start(string, []string) error
}

type FileController interface {
	Remove(string) error
	WriteResult(string, InstallResult) error
}

type InstallResult struct {
	SchemaVersion   int       `json:"schemaVersion"`
	Status          string    `json:"status"`
	Code            string    `json:"code"`
	TechnicalDetail string    `json:"technicalDetail"`
	InstallerPath   string    `json:"installerPath"`
	InstallDir      string    `json:"installDir"`
	UpdatedAt       time.Time `json:"updatedAt"`
}

func (result InstallResult) Validate() error {
	if result.SchemaVersion != installResultSchema {
		return errors.New("unsupported result schema version")
	}
	if result.Status != "success" && result.Status != "failure" {
		return errors.New("invalid installation result status")
	}
	if result.Code == "" || len(result.Code) > 128 || len(result.TechnicalDetail) > 4096 {
		return errors.New("invalid installation result values")
	}
	if result.InstallerPath == "" || result.InstallDir == "" || result.UpdatedAt.IsZero() || result.UpdatedAt.Location() != time.UTC {
		return errors.New("installation result is missing required identity fields")
	}
	return nil
}

type Runner struct {
	Processes           ProcessController
	Files               FileController
	LogWriter           io.Writer
	Now                 func() time.Time
	VerifyInstaller     func(Paths) error
	ValidateApplication func(Paths) (string, error)
}

func (runner Runner) verifyInstaller(paths Paths) error {
	if runner.VerifyInstaller != nil {
		return runner.VerifyInstaller(paths)
	}
	return VerifyInstallerIdentity(paths)
}

func (runner Runner) validateApplication(paths Paths) (string, error) {
	if runner.ValidateApplication != nil {
		return runner.ValidateApplication(paths)
	}
	return ValidateApplicationExecutable(paths)
}

func (runner Runner) Execute(paths Paths) error {
	if runner.Processes == nil || runner.Files == nil {
		return errors.New("updater dependencies are unavailable")
	}
	now := runner.Now
	if now == nil {
		now = time.Now
	}

	// Wait only for the executable installed in the trusted application directory.
	applicationPath, err := runner.validateApplication(paths)
	if err != nil {
		return runner.recordFailure(paths, now, "application_identity_invalid", err)
	}
	waitContext, cancelWait := context.WithTimeout(context.Background(), processExitTimeout)
	defer cancelWait()
	if err := runner.Processes.WaitForExit(waitContext, applicationPath); err != nil {
		return runner.recordFailure(paths, now, "application_exit_timeout", err)
	}

	// Recheck the protected staged installer after the application has exited.
	if err := runner.verifyInstaller(paths); err != nil {
		return runner.recordFailure(paths, now, "installer_identity_changed", err)
	}
	installerContext, cancelInstaller := context.WithTimeout(context.Background(), installerProcessTimeout)
	defer cancelInstaller()
	exitCode, err := runner.Processes.Run(installerContext, paths.InstallerPath, SilentInstallerArguments)
	if errors.Is(installerContext.Err(), context.DeadlineExceeded) {
		return runner.recordFailure(paths, now, "installer_timeout", installerContext.Err())
	}
	if err != nil {
		return runner.recordFailure(paths, now, "installer_process_failed", err)
	}
	if exitCode != 0 {
		return runner.recordFailure(paths, now, "installer_exit_nonzero", fmt.Errorf("exit code %d", exitCode))
	}

	applicationPath, err = runner.validateApplication(paths)
	if err != nil {
		return runner.recordFailure(paths, now, "application_identity_invalid", err)
	}
	if err := runner.Processes.Start(applicationPath, nil); err != nil {
		return runner.recordFailure(paths, now, "application_launch_failed", err)
	}

	result := InstallResult{
		SchemaVersion: installResultSchema,
		Status:        "success",
		Code:          "installed",
		InstallerPath: paths.InstallerPath,
		InstallDir:    paths.InstallDir,
		UpdatedAt:     now().UTC(),
	}
	if err := runner.Files.WriteResult(paths.ResultPath, result); err != nil {
		return fmt.Errorf("write installation result: %w", err)
	}
	if err := runner.verifyInstaller(paths); err != nil {
		runner.log("installer_cleanup_skipped", err.Error())
		return nil
	}
	if err := runner.Files.Remove(paths.InstallerPath); err != nil && !os.IsNotExist(err) {
		runner.log("installer_delete_failed", err.Error())
	}
	runner.log("installed", "installation completed")
	return nil
}

func (runner Runner) recordFailure(paths Paths, now func() time.Time, code string, cause error) error {
	result := InstallResult{
		SchemaVersion:   installResultSchema,
		Status:          "failure",
		Code:            code,
		TechnicalDetail: cause.Error(),
		InstallerPath:   paths.InstallerPath,
		InstallDir:      paths.InstallDir,
		UpdatedAt:       now().UTC(),
	}
	if writeError := runner.Files.WriteResult(paths.ResultPath, result); writeError != nil {
		runner.log("result_write_failed", writeError.Error())
	}
	runner.log(code, cause.Error())
	return fmt.Errorf("%s: %w", code, cause)
}

func (runner Runner) log(code string, detail string) {
	if runner.LogWriter == nil {
		return
	}
	payload, err := json.Marshal(map[string]string{"code": code, "detail": detail})
	if err == nil {
		_, _ = runner.LogWriter.Write(append(payload, '\n'))
	}
}

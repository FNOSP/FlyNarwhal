package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/fatih/color"
	"github.com/shirou/gopsutil/v3/process"
)

// Constants
const (
	AppName = "FnMedia.exe"
)

// Logging
func logMsg(level string, c *color.Color, format string, args ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, args...)
	levelStr := fmt.Sprintf("[%s]", strings.ToUpper(level))
	fmt.Printf("[%s] %s\n", timestamp, c.Sprint(levelStr+" "+msg))
}

func info(format string, args ...interface{}) {
	logMsg("info", color.New(color.FgHiCyan), format, args...)
}

func success(format string, args ...interface{}) {
	logMsg("success", color.New(color.FgHiGreen), format, args...)
}

func warn(format string, args ...interface{}) {
	logMsg("warn", color.New(color.FgHiYellow), format, args...)
}

func errorLog(format string, args ...interface{}) {
	logMsg("error", color.New(color.FgHiRed), format, args...)
}

func main() {
	defer func() {
		if r := recover(); r != nil {
			errorLog(Msg("error_occurred", r))
			end()
		}
	}()

	info(Msg("updater_started"))

	args := os.Args
	if len(args) < 3 {
		info(Msg("usage", args[0]))
		end()
		return
	}

	installerPath := args[1]
	installDir := args[2]

	info(Msg("wait_app_exit"))
	if err := waitAppExit(); err == nil {
		info(Msg("app_closed"))
	}

	info("Cleaning installation directory: %s", installDir)
	if err := cleanInstallDir(installDir, installerPath); err != nil {
		errorLog("Failed to clean directory: %v", err)
		// Continue anyway? The user requirement says "clean up... then execute".
		// If cleanup fails, we might still want to try installing.
	}

	info("Starting installer: %s", installerPath)
	// Execute “FnMedia_Setup_xxx.exe /SILENT /SP- /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS”
	cmd := exec.Command(installerPath, "/SILENT", "/SP-", "/SUPPRESSMSGBOXES", "/NORESTART", "/CLOSEAPPLICATIONS")

	if err := cmd.Run(); err != nil {
		errorLog("Installer failed: %v", err)
		end()
		return
	}

	success("Installation completed successfully.")

	// Launch the app
	appName := AppName
	appPath := filepath.Join(installDir, appName)

	info("Launching application: %s", appPath)

	appCmd := exec.Command(appPath)
	if err := appCmd.Start(); err != nil {
		errorLog("Failed to launch application: %v", err)
	} else {
		success("Application launched successfully.")
	}

	os.Exit(0)
}

func end() {
	info(Msg("end"))
	time.Sleep(3 * time.Second)
	os.Exit(0)
}

func waitAppExit() error {
	// Wait up to 30 seconds for the app to close
	timeout := time.After(30 * time.Second)
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			return fmt.Errorf("timeout waiting for app exit")
		case <-ticker.C:
			procs, err := process.Processes()
			if err != nil {
				return err
			}

			found := false
			for _, p := range procs {
				name, err := p.Name()
				if err == nil && strings.EqualFold(name, AppName) {
					found = true
					break
				}
			}

			if !found {
				return nil
			}
		}
	}
}

func cleanInstallDir(dir string, installerPath string) error {
	// We need to keep:
	// 1. installerPath
	// 2. this executable (fntv-updater.exe)

	thisExe, err := os.Executable()
	if err != nil {
		return err
	}

	absInstallerPath, err := filepath.Abs(installerPath)
	if err != nil {
		absInstallerPath = installerPath // fallback
	}

	absThisExe, err := filepath.Abs(thisExe)
	if err != nil {
		absThisExe = thisExe
	}

	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}

	for _, entry := range entries {
		path := filepath.Join(dir, entry.Name())
		absPath, err := filepath.Abs(path)
		if err != nil {
			absPath = path
		}

		// Check if it's the installer
		if strings.EqualFold(absPath, absInstallerPath) {
			continue
		}

		// Check if it's the updater
		if strings.EqualFold(absPath, absThisExe) {
			continue
		}

		// Delete
		info("Deleting: %s", path)
		if err := os.RemoveAll(path); err != nil {
			warn("Failed to delete %s: %v", path, err)
		}
	}
	return nil
}

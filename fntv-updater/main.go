package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
	"unsafe"

	"github.com/fatih/color"
	"github.com/shirou/gopsutil/v3/process"
	"golang.org/x/sys/windows"
)

// Constants
const (
	AppName = "FnMedia.exe"

	// MessageBox constants
	MB_OK              = 0x00000000
	MB_ICONINFORMATION = 0x00000040
	MB_ICONWARNING     = 0x00000030
	MB_ICONERROR       = 0x00000010
	MB_ICONQUESTION    = 0x00000020
	MB_SYSTEMMODAL     = 0x00001000
)

var logFile *os.File

func initLog() {
	logDir := "logs"
	if _, err := os.Stat(logDir); os.IsNotExist(err) {
		os.Mkdir(logDir, 0755)
	}

	cleanOldLogs(logDir)

	date := time.Now().Format("2006-01-02")
	logFilePath := filepath.Join(logDir, fmt.Sprintf("updater-%s.log", date))

	f, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		fmt.Println("Failed to open log file:", err)
		return
	}
	logFile = f
}

func cleanOldLogs(logDir string) {
	files, err := os.ReadDir(logDir)
	if err != nil {
		return
	}

	today := time.Now()
	// Keep today, yesterday, day before yesterday.
	// So delete if difference >= 3 days
	retentionDays := 3.0

	for _, file := range files {
		if file.IsDir() {
			continue
		}
		name := file.Name()
		if strings.HasPrefix(name, "updater-") && strings.HasSuffix(name, ".log") {
			datePart := strings.TrimSuffix(strings.TrimPrefix(name, "updater-"), ".log")
			fileDate, err := time.Parse("2006-01-02", datePart)
			if err != nil {
				continue
			}

			// Calculate days difference
			// We use Truncate to compare dates only, ignoring time
			d1 := time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, today.Location())
			d2 := time.Date(fileDate.Year(), fileDate.Month(), fileDate.Day(), 0, 0, 0, 0, fileDate.Location())

			days := d1.Sub(d2).Hours() / 24

			if days >= retentionDays {
				err := os.Remove(filepath.Join(logDir, name))
				if err != nil {
					fmt.Println("Failed to delete old log:", name, err)
				} else {
					fmt.Println("Deleted old log:", name)
				}
			}
		}
	}
}

// Logging
func logMsg(level string, c *color.Color, format string, args ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, args...)
	levelStr := fmt.Sprintf("[%s]", strings.ToUpper(level))

	// Print to console
	fmt.Printf("[%s] %s\n", timestamp, c.Sprint(levelStr+" "+msg))

	// Write to file
	if logFile != nil {
		fullMsg := fmt.Sprintf("[%s] %s %s\n", timestamp, levelStr, msg)
		logFile.WriteString(fullMsg)
	}
}

func info(format string, args ...interface{}) {
	logMsg("info", color.New(color.FgHiCyan), format, args...)
}

func success(format string, args ...interface{}) {
	logMsg("success", color.New(color.FgHiGreen), format, args...)
}

func warn(format string, args ...interface{}) {
	logMsg("warn", color.New(color.FgHiYellow), format, args...)
	showMessageBox(fmt.Sprintf(format, args...), "FnMedia Updater - Warning", MB_OK|MB_ICONWARNING|MB_SYSTEMMODAL)
}

func errorLog(format string, args ...interface{}) {
	logMsg("error", color.New(color.FgHiRed), format, args...)
	showMessageBox(fmt.Sprintf(format, args...), "FnMedia Updater - Error", MB_OK|MB_ICONERROR|MB_SYSTEMMODAL)
}

// showMessageBox displays a Windows message box
func showMessageBox(message, title string, flags uint) {
	if !isWindows() {
		return
	}

	// Convert strings to UTF16 pointers
	messagePtr, _ := windows.UTF16PtrFromString(message)
	titlePtr, _ := windows.UTF16PtrFromString(title)

	// Show message box
	user32 := windows.NewLazySystemDLL("user32.dll")
	MessageBox := user32.NewProc("MessageBoxW")
	MessageBox.Call(
		0,
		uintptr(unsafe.Pointer(messagePtr)),
		uintptr(unsafe.Pointer(titlePtr)),
		uintptr(flags),
	)
}

// isWindows checks if we are running on Windows
func isWindows() bool {
	return strings.Contains(strings.ToLower(runtime.GOOS), "windows")
}

func main() {
	initLog()
	if logFile != nil {
		defer logFile.Close()
	}

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
	// Execute "FnMedia_Setup_xxx.exe /SILENT /SP- /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS"
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

		// Check if it's the logs directory
		if strings.EqualFold(entry.Name(), "logs") {
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

package logger

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"fntv_updater/internal/consts"
	"fntv_updater/internal/ui"

	"github.com/fatih/color"
)

var LogFile *os.File

func InitLog() {
	logDir := "logs"
	if _, err := os.Stat(logDir); os.IsNotExist(err) {
		os.Mkdir(logDir, 0755)
	}

	cleanOldLogs(logDir)

	date := time.Now().Format("2006-01-02")
	logFilePath := filepath.Join(logDir, fmt.Sprintf("updater-%s.log", date))

	f, err := os.OpenFile(logFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		Info("Logger", "Failed to open log file: %v", err)
		return
	}
	LogFile = f
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
					Info("Logger", "Failed to delete old log: %s %v", name, err)
				} else {
					Info("Logger", "Deleted old log: %s", name)
				}
			}
		}
	}
}

// Logging
func logMsg(tag string, level string, c *color.Color, format string, args ...interface{}) {
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	msg := fmt.Sprintf(format, args...)
	levelStr := fmt.Sprintf("[%s]", strings.ToUpper(level))
	tagStr := ""
	if tag != "" {
		tagStr = fmt.Sprintf("[%s]", tag)
	}

	// Print to console
	fmt.Printf("[%s] %s %s\n", timestamp, tagStr, c.Sprint(levelStr+" "+msg))

	// Write to file
	if LogFile != nil {
		fullMsg := fmt.Sprintf("[%s] %s %s %s\n", timestamp, tagStr, levelStr, msg)
		LogFile.WriteString(fullMsg)
	}
}

func Info(tag string, format string, args ...interface{}) {
	logMsg(tag, "info", color.New(color.FgHiCyan), format, args...)
}

func Success(tag string, format string, args ...interface{}) {
	logMsg(tag, "success", color.New(color.FgHiGreen), format, args...)
}

func Warn(tag string, format string, args ...interface{}) {
	logMsg(tag, "warn", color.New(color.FgHiYellow), format, args...)
	ui.ShowMessageBox(fmt.Sprintf(format, args...), "FlyNarwhal Updater - Warning", consts.MB_OK|consts.MB_ICONWARNING|consts.MB_SYSTEMMODAL)
}

func ErrorLog(tag string, format string, args ...interface{}) {
	logMsg(tag, "error", color.New(color.FgHiRed), format, args...)
	ui.ShowMessageBox(fmt.Sprintf(format, args...), "FlyNarwhal Updater - Error", consts.MB_OK|consts.MB_ICONERROR|consts.MB_SYSTEMMODAL)
}

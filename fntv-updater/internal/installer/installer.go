package installer

import (
	"os"
	"path/filepath"
	"strings"

	"fntv_updater/internal/consts"
	"fntv_updater/internal/logger"

	"golang.org/x/sys/windows/registry"
)

func CheckRegistryInstall() bool {
	keyPath := `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\` + consts.AppId + `_is1`

	// Check HKLM
	k, err := registry.OpenKey(registry.LOCAL_MACHINE, keyPath, registry.QUERY_VALUE)
	if err == nil {
		k.Close()
		return true
	}

	// Check HKCU
	k, err = registry.OpenKey(registry.CURRENT_USER, keyPath, registry.QUERY_VALUE)
	if err == nil {
		k.Close()
		return true
	}

	return false
}

func CleanInstallDir(dir string, installerPath string) error {
	// We need to keep:
	// 1. installerPath
	// 2. this executable (fntv-updater.exe)
	// 3. logs directory (as per original code logic, "logs" is skipped)

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
		logger.Info("Installer", "Deleting: %s", path)
		if err := os.RemoveAll(path); err != nil {
			logger.Warn("Installer", "Failed to delete %s: %v", path, err)
		}
	}
	return nil
}

package updater

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"time"

	"updater/internal/lang"
)

const legacyCleanupDeleteRetryDelay = 100 * time.Millisecond
const legacyCleanupDeleteRetryCount = 20

// CleanupLegacyInstallation removes only the verified KMP program files while
// preserving updater state needed by the Flutter installer.
func CleanupLegacyInstallation(paths Paths) error {
	if paths.InstallDir == "" {
		return lang.Error("install_directory_unavailable")
	}
	if err := validateExistingDirectory(paths.InstallDir); err != nil {
		return err
	}

	legacyRootEntries := []string{
		ApplicationExecutable,
		"logs",
		"runtime",
		"unins000.dat",
		"unins000.exe",
		"unins000.msg",
		"fntv-updater.exe",
	}
	for _, entryName := range legacyRootEntries {
		entryPath := filepath.Join(paths.InstallDir, entryName)
		if err := removeLegacyPath(paths.InstallDir, entryPath); err != nil {
			return err
		}
	}

	return cleanupLegacyAppDirectory(filepath.Join(paths.InstallDir, "app"))
}

func cleanupLegacyAppDirectory(appDirectory string) error {
	entries, err := os.ReadDir(appDirectory)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}

	for _, entry := range entries {
		entryPath := filepath.Join(appDirectory, entry.Name())
		if strings.EqualFold(entry.Name(), "resources") {
			if err := cleanupLegacyResourcesDirectory(entryPath); err != nil {
				return err
			}
			continue
		}
		if err := removeLegacyPath(appDirectory, entryPath); err != nil {
			return err
		}
	}

	return removeDirectoryIfEmpty(appDirectory)
}

func cleanupLegacyResourcesDirectory(resourcesDirectory string) error {
	entries, err := os.ReadDir(resourcesDirectory)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}

	for _, entry := range entries {
		entryPath := filepath.Join(resourcesDirectory, entry.Name())
		if err := removeLegacyPath(resourcesDirectory, entryPath); err != nil {
			return err
		}
	}

	return removeDirectoryIfEmpty(resourcesDirectory)
}

func removeLegacyPath(rootPath string, targetPath string) error {
	if !samePath(rootPath, targetPath) && !isWithinRoot(rootPath, targetPath) {
		return lang.Error("legacy_cleanup_target_outside_trusted_root")
	}
	fileInfo, err := os.Lstat(targetPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if fileInfo.Mode()&os.ModeSymlink != 0 {
		return lang.Error("legacy_cleanup_target_reparse_point")
	}
	return removeLegacyPathWithRetry(targetPath, fileInfo.IsDir())
}

func removeDirectoryIfEmpty(directoryPath string) error {
	entries, err := os.ReadDir(directoryPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if len(entries) != 0 {
		return nil
	}
	return os.Remove(directoryPath)
}

func removeLegacyPathWithRetry(targetPath string, directory bool) error {
	if directory {
		return removeLegacyDirectory(targetPath)
	}

	var lastError error
	for attempt := 0; attempt < legacyCleanupDeleteRetryCount; attempt++ {
		lastError = os.Remove(targetPath)
		if lastError != nil && !errors.Is(lastError, os.ErrNotExist) {
			time.Sleep(legacyCleanupDeleteRetryDelay)
			continue
		}
		if _, err := os.Lstat(targetPath); errors.Is(err, os.ErrNotExist) {
			return nil
		} else if err != nil {
			lastError = err
		} else {
			lastError = lang.Error("legacy_cleanup_target_still_exists", targetPath)
		}
		time.Sleep(legacyCleanupDeleteRetryDelay)
	}
	if lastError != nil {
		return lastError
	}
	return lang.Error("legacy_cleanup_target_still_exists", targetPath)
}

func removeLegacyDirectory(directoryPath string) error {
	entries, err := os.ReadDir(directoryPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	for _, entry := range entries {
		childPath := filepath.Join(directoryPath, entry.Name())
		childInfo, err := os.Lstat(childPath)
		if err != nil {
			if errors.Is(err, os.ErrNotExist) {
				continue
			}
			return err
		}
		if childInfo.Mode()&os.ModeSymlink != 0 {
			return lang.Error("legacy_cleanup_target_reparse_point")
		}
		if childInfo.IsDir() {
			if err := removeLegacyDirectory(childPath); err != nil {
				return err
			}
			if err := removeDirectoryIfEmpty(childPath); err != nil {
				return err
			}
			continue
		}
		if err := removeLegacyPathWithRetry(childPath, false); err != nil {
			return err
		}
	}
	if err := removeDirectoryIfEmpty(directoryPath); err != nil {
		return err
	}
	return nil
}

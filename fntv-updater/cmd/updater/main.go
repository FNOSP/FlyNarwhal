package main

import (
	"fmt"
	"os"
	"path/filepath"

	"fntv-updater/internal/updater"
)

func main() {
	installerPath, installDir, err := updater.ParseArguments(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	paths, err := updater.ValidatePaths(installerPath, installDir, environmentMap())
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if err := os.MkdirAll(filepath.Dir(paths.LogPath), 0o700); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	logFile, err := os.OpenFile(paths.LogPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer logFile.Close()

	runner := updater.Runner{
		Processes: updater.OSProcessController{},
		Files:     updater.OSFileController{},
		LogWriter: logFile,
	}
	if err := runner.Execute(paths); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func environmentMap() map[string]string {
	values := make(map[string]string)
	for _, entry := range os.Environ() {
		for index := 0; index < len(entry); index++ {
			if entry[index] == '=' {
				values[entry[:index]] = entry[index+1:]
				break
			}
		}
	}
	return values
}

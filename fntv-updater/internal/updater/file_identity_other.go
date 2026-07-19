//go:build !windows

package updater

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"io"
	"os"
)

func inspectRegularFile(filePath string) (FileIdentity, error) {
	fileInfo, err := os.Lstat(filePath)
	if err != nil {
		return FileIdentity{}, err
	}
	if fileInfo.Mode()&os.ModeSymlink != 0 || !fileInfo.Mode().IsRegular() {
		return FileIdentity{}, errors.New("path is not a regular non-reparse file")
	}
	file, err := os.Open(filePath)
	if err != nil {
		return FileIdentity{}, err
	}
	defer file.Close()

	fileHash := sha256.New()
	if _, err := io.Copy(fileHash, file); err != nil {
		return FileIdentity{}, err
	}
	return FileIdentity{
		Path:   filePath,
		Size:   fileInfo.Size(),
		SHA256: hex.EncodeToString(fileHash.Sum(nil)),
	}, nil
}

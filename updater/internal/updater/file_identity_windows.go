//go:build windows

package updater

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"os"
	"syscall"

	"updater/internal/lang"
)

const fileAttributeReparsePoint = 0x00000400

func inspectRegularFile(filePath string) (FileIdentity, error) {
	attributes, err := syscall.GetFileAttributes(syscall.StringToUTF16Ptr(filePath))
	if err != nil {
		return FileIdentity{}, err
	}
	if attributes&fileAttributeReparsePoint != 0 {
		return FileIdentity{}, lang.Error("path_not_regular_non_reparse_file")
	}
	fileInfo, err := os.Lstat(filePath)
	if err != nil {
		return FileIdentity{}, err
	}
	if !fileInfo.Mode().IsRegular() {
		return FileIdentity{}, lang.Error("path_not_regular_non_reparse_file")
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

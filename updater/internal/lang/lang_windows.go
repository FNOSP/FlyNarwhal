//go:build windows

package lang

import "syscall"

func systemDefaultUILanguage() uint16 {
	kernel32, err := syscall.LoadDLL("kernel32.dll")
	if err != nil {
		return 0
	}
	defer kernel32.Release()

	proc, err := kernel32.FindProc("GetSystemDefaultUILanguage")
	if err != nil {
		return 0
	}

	ret, _, _ := proc.Call()
	return uint16(ret)
}

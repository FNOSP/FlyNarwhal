//go:build !windows

package lang

func systemDefaultUILanguage() uint16 {
	return 0
}

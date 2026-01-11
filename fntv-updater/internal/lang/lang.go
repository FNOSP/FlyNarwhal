package lang

import (
	"fmt"
	"os"
	"runtime"
	"strings"
	"syscall"
)

type Language int

const (
	En Language = iota
	Zh
)

var CurrentLanguage Language

func init() {
	CurrentLanguage = getLanguage()
}

func getLanguage() Language {
	if runtime.GOOS == "windows" {
		langID := getWindowsSystemDefaultUILanguage()
		switch langID {
		case 0x0804: // zh-CN
			return Zh
		case 0x0409: // en-US
			return En
		}
	} else {
		lang := os.Getenv("LANG")
		if strings.HasPrefix(lang, "zh") {
			return Zh
		}
	}
	return En
}

func getWindowsSystemDefaultUILanguage() uint16 {
	// Load kernel32.dll
	kernel32, err := syscall.LoadDLL("kernel32.dll")
	if err != nil {
		return 0
	}
	defer kernel32.Release()

	// Find GetSystemDefaultUILanguage
	proc, err := kernel32.FindProc("GetSystemDefaultUILanguage")
	if err != nil {
		return 0
	}

	// Call it
	ret, _, _ := proc.Call()
	return uint16(ret)
}

// Messages
var messages = map[string][2]string{
	"error_occurred":  {"An error occurred with %s", "发生了一个错误由于 %s"},
	"updater_started": {"FlyNarwhal app updater started", "飞鲸影视更新器已启动"},
	"usage":           {"Usage: %s <installer_path> <install_dir>", "用法: %s <安装包路径> <安装目录>"},
	"wait_app_exit":   {"Wait for FlyNarwhal app to exit", "等待飞鲸影视退出"},
	"app_closed":      {"FlyNarwhal app is closed", "飞鲸影视已关闭"},
	"end":             {"Exiting...", "退出中..."},
}

func Msg(key string, args ...interface{}) string {
	val, ok := messages[key]
	if !ok {
		return key
	}
	format := val[CurrentLanguage]
	return fmt.Sprintf(format, args...)
}
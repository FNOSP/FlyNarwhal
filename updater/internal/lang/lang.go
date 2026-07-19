package lang

import (
	"fmt"
	"os"
	"strings"
)

type Language int

const (
	En Language = iota
	Zh
)

var CurrentLanguage = detectLanguage()

var messages = map[string][2]string{
	"usage":                                       {"Usage: %s <installer_path> <install_dir>", "用法：%s <安装包路径> <安装目录>"},
	"expected_exactly_two_arguments":              {"expected exactly two arguments, got %d", "需要且只能传入两个参数，实际为 %d 个"},
	"localappdata_unavailable":                    {"LOCALAPPDATA is unavailable", "LOCALAPPDATA 不可用"},
	"resolve_cache_root":                          {"resolve cache root", "解析更新缓存目录失败"},
	"unsafe_update_cache_root":                    {"unsafe update cache root", "更新缓存目录不安全"},
	"invalid_installer":                           {"invalid installer", "安装包无效"},
	"installer_must_have_exe_extension":           {"installer must have an .exe extension", "安装包必须是 .exe 文件"},
	"installer_outside_update_cache_root":         {"installer is outside the update cache root", "安装包不在受信任的更新缓存目录内"},
	"unsafe_installer_staging_directory":          {"unsafe installer staging directory", "安装包暂存目录不安全"},
	"resolve_install_directory":                   {"resolve install directory", "解析安装目录失败"},
	"resolve_trusted_install_directory":           {"resolve trusted install directory", "解析受信任安装目录失败"},
	"install_directory_mismatch":                  {"install directory does not match the trusted FlyNarwhal directory", "安装目录与受信任的 FlyNarwhal 目录不一致"},
	"unsafe_installation_directory":               {"unsafe installation directory", "安装目录不安全"},
	"unsafe_installation_updates_directory":       {"unsafe installation updates directory", "安装目录中的 updates 目录不安全"},
	"identify_installer":                          {"identify installer", "识别安装包失败"},
	"installer_identity_changed_after_validation": {"installer identity changed after validation", "安装包在校验后身份发生变化"},
	"unsafe_application_directory":                {"unsafe application directory", "应用程序目录不安全"},
	"invalid_application_executable":              {"invalid application executable", "应用程序可执行文件无效"},
	"application_executable_outside_trusted_root": {"application executable is outside the trusted installation directory", "应用程序可执行文件不在受信任的安装目录内"},
	"open_protected_installer_manifest":           {"open protected installer manifest", "打开受保护的安装包清单失败"},
	"stat_protected_installer_manifest":           {"stat protected installer manifest", "读取受保护的安装包清单信息失败"},
	"installer_manifest_not_safe_regular_file":    {"installer manifest is not a safe regular file", "安装包清单不是安全的常规文件"},
	"decode_protected_installer_manifest":         {"decode protected installer manifest", "解析受保护的安装包清单失败"},
	"installer_manifest_mismatch":                 {"installer manifest does not match the staged installer", "安装包清单与暂存安装包不匹配"},
	"path_not_regular_non_reparse_file":           {"path is not a regular non-reparse file", "路径不是常规且非重解析点文件"},
	"path_not_non_reparse_directory":              {"path is not a non-reparse directory", "路径不是非重解析点目录"},
	"directory_outside_trusted_root":              {"directory is outside trusted root", "目录超出受信任根目录"},
	"install_directory_unavailable":               {"install directory is unavailable", "安装目录不可用"},
	"legacy_cleanup_target_outside_trusted_root":  {"legacy cleanup target is outside trusted root", "遗留清理目标超出受信任根目录"},
	"legacy_cleanup_target_reparse_point":         {"legacy cleanup target is a reparse point", "遗留清理目标是重解析点"},
	"legacy_cleanup_target_still_exists":          {"legacy cleanup target still exists after deletion: %s", "删除后遗留清理目标仍然存在：%s"},
	"unsupported_result_schema_version":           {"unsupported result schema version", "安装结果 schema 版本不受支持"},
	"invalid_installation_result_status":          {"invalid installation result status", "安装结果状态无效"},
	"invalid_installation_result_values":          {"invalid installation result values", "安装结果字段值无效"},
	"installation_result_missing_required_fields": {"installation result is missing required identity fields", "安装结果缺少必要的身份字段"},
	"updater_dependencies_unavailable":            {"updater dependencies are unavailable", "updater 依赖不可用"},
	"installer_exit_code":                         {"exit code %d", "退出码 %d"},
	"write_installation_result":                   {"write installation result", "写入安装结果失败"},
	"installation_completed":                      {"installation completed", "安装完成"},
	"application_identity_invalid":                {"application validation failed", "应用程序校验失败"},
	"application_exit_timeout":                    {"timed out waiting for FlyNarwhal to exit", "等待飞鲸影视退出超时"},
	"legacy_cleanup_failed":                       {"failed to clean legacy installation files", "清理遗留安装文件失败"},
	"installer_identity_changed":                  {"installer identity changed before execution", "执行前安装包身份已变化"},
	"installer_timeout":                           {"installer timed out", "安装程序执行超时"},
	"installer_process_failed":                    {"failed to start installer process", "启动安装程序失败"},
	"installer_exit_nonzero":                      {"installer exited with a non-zero status", "安装程序以非零状态退出"},
	"application_launch_failed":                   {"failed to launch FlyNarwhal after installation", "安装后启动飞鲸影视失败"},
}

func Msg(key string, args ...interface{}) string {
	value, ok := messages[key]
	if !ok {
		return key
	}
	format := value[CurrentLanguage]
	return fmt.Sprintf(format, args...)
}

func Error(key string, args ...interface{}) error {
	return fmt.Errorf("%s", Msg(key, args...))
}

func Wrap(err error, key string, args ...interface{}) error {
	if err == nil {
		return Error(key, args...)
	}
	return fmt.Errorf("%s: %w", Msg(key, args...), err)
}

func detectLanguage() Language {
	if language, ok := detectLanguageFromWindowsID(systemDefaultUILanguage()); ok {
		return language
	}
	if language, ok := detectLanguageFromEnvironment(os.Getenv("LANG")); ok {
		return language
	}
	return En
}

func detectLanguageFromWindowsID(languageID uint16) (Language, bool) {
	switch languageID {
	case 0x0804:
		return Zh, true
	case 0x0409:
		return En, true
	default:
		return En, false
	}
}

func detectLanguageFromEnvironment(languageEnv string) (Language, bool) {
	normalized := strings.ToLower(strings.TrimSpace(languageEnv))
	if normalized == "" {
		return En, false
	}
	if strings.HasPrefix(normalized, "zh") {
		return Zh, true
	}
	if strings.HasPrefix(normalized, "en") {
		return En, true
	}
	return En, false
}

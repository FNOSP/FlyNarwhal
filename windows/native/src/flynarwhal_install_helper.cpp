#include "flynarwhal_install_helper.h"

#include "flynarwhal_recovery_host.h"
#include "flynarwhal_updater_endpoint.h"

#include <bcrypt.h>
#include <shellapi.h>
#include <shlobj.h>
#include <winver.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cwctype>
#include <ctime>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <regex>
#include <sstream>
#include <system_error>

namespace flynarwhal::install_helper {
namespace {

constexpr wchar_t kStagePrefix[] = L"desktop_updater_stage_";
constexpr wchar_t kInstallerName[] = L"installer.exe";
constexpr wchar_t kAuthorityName[] = L"release-authority.json";
constexpr wchar_t kProvenanceName[] = L".desktop_updater_stage_provenance.json";
constexpr wchar_t kPendingName[] = L"pending-install.json";
constexpr wchar_t kInstalledExecutableName[] = L"FlyNarwhal.exe";
constexpr wchar_t kWindowsLogCompanyName[] = L"com.jankinwu";
constexpr wchar_t kWindowsLogProductName[] = L"FlyNarwhal";
constexpr wchar_t kUpdateLogFilePrefix[] = L"update_ ";
constexpr wchar_t kUpdateLogFileExtension[] = L".log";
constexpr DWORD kInstallerTimeoutMilliseconds = 20U * 60U * 1000U;

std::filesystem::path g_active_update_log_path;

struct ScopedHandle {
  HANDLE value = INVALID_HANDLE_VALUE;

  ScopedHandle() = default;
  explicit ScopedHandle(HANDLE handle) : value(handle) {}
  ScopedHandle(const ScopedHandle&) = delete;
  ScopedHandle& operator=(const ScopedHandle&) = delete;
  ~ScopedHandle() {
    if (value != nullptr && value != INVALID_HANDLE_VALUE) {
      CloseHandle(value);
    }
  }

  bool valid() const {
    return value != nullptr && value != INVALID_HANDLE_VALUE;
  }
};

std::wstring ToLower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t character) {
                   return static_cast<wchar_t>(std::towlower(character));
                 });
  return value;
}

bool PathsEqual(const std::filesystem::path& left,
                const std::filesystem::path& right) {
  std::error_code error;
  const auto canonical_left = std::filesystem::weakly_canonical(left, error);
  if (error) {
    return false;
  }
  const auto canonical_right = std::filesystem::weakly_canonical(right, error);
  return !error && ToLower(canonical_left.wstring()) ==
                       ToLower(canonical_right.wstring());
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return {};
  }
  const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                       value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) {
    return {};
  }
  std::string converted(static_cast<std::size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), converted.data(), size,
                      nullptr, nullptr);
  return converted;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0);
  if (size <= 0) {
    return {};
  }
  std::wstring converted(static_cast<std::size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), converted.data(), size);
  return converted;
}

std::tm GetLocalTime(std::time_t timestamp) {
  std::tm local_time{};
  localtime_s(&local_time, &timestamp);
  return local_time;
}

std::wstring FormatFileTimestamp(std::time_t timestamp) {
  const auto local_time = GetLocalTime(timestamp);
  std::wostringstream output;
  output << std::put_time(&local_time, L"%Y%m%d_%H%M%S");
  return output.str();
}

std::wstring FormatLogTimestamp(std::time_t timestamp) {
  const auto local_time = GetLocalTime(timestamp);
  std::wostringstream output;
  output << std::put_time(&local_time, L"%Y-%m-%d %H:%M:%S");
  return output.str();
}

std::filesystem::path GetRoamingAppDataPath() {
  PWSTR raw_path = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, KF_FLAG_DEFAULT,
                                  nullptr, &raw_path))) {
    return {};
  }
  const std::filesystem::path result(raw_path);
  CoTaskMemFree(raw_path);
  return result;
}

std::filesystem::path GetUpdateLogDirectory() {
  return GetRoamingAppDataPath() / kWindowsLogCompanyName /
         kWindowsLogProductName / L"logs";
}

bool TryParseUpdateLogTimestamp(const std::wstring& file_name,
                                std::time_t* parsed_timestamp) {
  static const std::wregex expression(
      LR"(^update_ ([0-9]{8}_[0-9]{6})\.log$)");
  std::wsmatch match;
  if (!std::regex_match(file_name, match, expression)) {
    return false;
  }
  std::tm parsed_time{};
  std::wistringstream input(match[1].str());
  input >> std::get_time(&parsed_time, L"%Y%m%d_%H%M%S");
  if (input.fail()) {
    return false;
  }
  parsed_time.tm_isdst = -1;
  const std::time_t timestamp = std::mktime(&parsed_time);
  if (timestamp == static_cast<std::time_t>(-1)) {
    return false;
  }
  *parsed_timestamp = timestamp;
  return true;
}

std::time_t ComputeUpdateLogCutoff(std::time_t now) {
  auto cutoff = GetLocalTime(now);
  cutoff.tm_mon -= 3;
  cutoff.tm_isdst = -1;
  return std::mktime(&cutoff);
}

void AppendUpdateLogLine(const std::wstring& level, const std::wstring& message) {
  if (g_active_update_log_path.empty()) {
    return;
  }
  std::ofstream stream(g_active_update_log_path, std::ios::binary | std::ios::app);
  if (!stream) {
    return;
  }
  stream << WideToUtf8(FormatLogTimestamp(std::time(nullptr))) << " ["
         << WideToUtf8(level) << "] " << WideToUtf8(message) << "\r\n";
  stream.flush();
}

void AttachUpdateLogPath(const std::filesystem::path& log_path) {
  if (log_path.empty()) {
    return;
  }
  g_active_update_log_path = log_path;
}

void CleanupExpiredUpdateLogs() {
  const auto log_directory = GetUpdateLogDirectory();
  std::error_code error;
  if (!std::filesystem::exists(log_directory, error) || error) {
    return;
  }
  const std::time_t cutoff = ComputeUpdateLogCutoff(std::time(nullptr));
  std::size_t deleted_count = 0;
  for (const auto& entry : std::filesystem::directory_iterator(log_directory, error)) {
    if (error) {
      break;
    }
    if (!entry.is_regular_file()) {
      continue;
    }
    std::time_t parsed_timestamp = 0;
    const auto file_name = entry.path().filename().wstring();
    if (!TryParseUpdateLogTimestamp(file_name, &parsed_timestamp) ||
        parsed_timestamp >= cutoff) {
      continue;
    }
    std::error_code remove_error;
    std::filesystem::remove(entry.path(), remove_error);
    if (!remove_error) {
      ++deleted_count;
    }
  }
  if (deleted_count > 0) {
    AppendUpdateLogLine(
        L"INFO",
        std::wstring(L"Cleaned ") + std::to_wstring(deleted_count) +
            L" expired update log file(s).");
  }
}

std::string EscapeJson(const std::wstring& value) {
  const std::string utf8 = WideToUtf8(value);
  std::string escaped;
  escaped.reserve(utf8.size());
  for (const char character : utf8) {
    switch (character) {
      case '\\':
        escaped += "\\\\";
        break;
      case '"':
        escaped += "\\\"";
        break;
      case '\n':
        escaped += "\\n";
        break;
      case '\r':
        escaped += "\\r";
        break;
      case '\t':
        escaped += "\\t";
        break;
      default:
        escaped += character;
        break;
    }
  }
  return escaped;
}

std::string BuildJsonString(const std::wstring& value) {
  return "\"" + EscapeJson(value) + "\"";
}

std::string BuildCanonicalProvenance(
    const std::filesystem::path& stage_path,
    std::uint64_t installer_length,
    const std::wstring& installer_sha,
    std::uint64_t authority_length,
    const std::wstring& authority_sha) {
  std::ostringstream output;
  output << "{\"schemaVersion\":1,\"stageName\":"
         << BuildJsonString(stage_path.filename().wstring())
         << ",\"entries\":[{\"kind\":\"directory\",\"length\":0,"
            "\"relativePath\":\".\"},{\"kind\":\"file\",\"length\":"
         << installer_length
         << ",\"relativePath\":\"installer.exe\",\"sha256\":"
         << BuildJsonString(installer_sha)
         << "},{\"kind\":\"file\",\"length\":" << authority_length
         << ",\"relativePath\":\"release-authority.json\",\"sha256\":"
         << BuildJsonString(authority_sha) << "}]}";
  return output.str();
}

std::wstring UnescapeJson(const std::string& value) {
  std::string unescaped;
  unescaped.reserve(value.size());
  bool escaping = false;
  for (const char character : value) {
    if (!escaping && character == '\\') {
      escaping = true;
      continue;
    }
    if (escaping) {
      switch (character) {
        case 'n':
          unescaped += '\n';
          break;
        case 'r':
          unescaped += '\r';
          break;
        case 't':
          unescaped += '\t';
          break;
        default:
          unescaped += character;
          break;
      }
      escaping = false;
      continue;
    }
    unescaped += character;
  }
  return Utf8ToWide(unescaped);
}

std::optional<std::wstring> ReadUtf8File(const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) {
    return std::nullopt;
  }
  std::ostringstream contents;
  contents << stream.rdbuf();
  if (!stream.good() && !stream.eof()) {
    return std::nullopt;
  }
  return Utf8ToWide(contents.str());
}

std::optional<std::wstring> ExtractJsonString(const std::wstring& json,
                                               const std::wstring& key) {
  const std::wregex expression(L"\\\"" + key +
                               L"\\\"\\s*:\\s*\\\"((?:\\\\.|[^\\\"])*)\\\"");
  std::wsmatch match;
  if (!std::regex_search(json, match, expression)) {
    return std::nullopt;
  }
  return UnescapeJson(WideToUtf8(match[1].str()));
}

std::optional<std::uint64_t> ExtractJsonUnsigned(const std::wstring& json,
                                                 const std::wstring& key) {
  const std::wregex expression(L"\\\"" + key + L"\\\"\\s*:\\s*([0-9]+)");
  std::wsmatch match;
  if (!std::regex_search(json, match, expression)) {
    return std::nullopt;
  }
  try {
    return std::stoull(match[1].str());
  } catch (...) {
    return std::nullopt;
  }
}

bool ExtractJsonBoolean(const std::wstring& json, const std::wstring& key,
                        bool* value) {
  const std::wregex expression(L"\\\"" + key +
                               L"\\\"\\s*:\\s*(true|false)");
  std::wsmatch match;
  if (!std::regex_search(json, match, expression)) {
    return false;
  }
  *value = match[1].str() == L"true";
  return true;
}

bool IsSafeRegularFile(const std::filesystem::path& path) {
  if (HasReparsePointInExistingPath(path)) {
    return false;
  }
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0 &&
         (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0;
}

std::filesystem::path GetOwnedStageRoot() {
  return GetLocalAppDataPath() / L"FlyNarwhal" / L"updates" /
         L"install-staging";
}

std::filesystem::path GetWorkerRoot() {
  return GetLocalAppDataPath() / L"FlyNarwhal" / L"updates" /
         L"worker-runtime";
}

std::filesystem::path GetRestagedInstallerRoot() {
  return GetLocalAppDataPath() / L"FlyNarwhal" / L"updates" / L"restaged";
}

bool LoadValidatedEndpoint(EndpointDescriptor* descriptor,
                           EndpointPolicy* policy,
                           std::wstring* error_message) {
  if (!ReadRegisteredEndpoint(descriptor, error_message) ||
      !ReadEndpointPolicy(descriptor->policy_path, policy, error_message) ||
      !ValidateEndpointDescriptor(*descriptor, *policy, error_message)) {
    return false;
  }
  return true;
}

bool RestageInstaller(const Journal& journal,
                      const StageVerification& verification,
                      std::filesystem::path* restaged_path,
                      std::wstring* restaged_sha256,
                      std::wstring* error_message) {
  const auto restaged_root = GetRestagedInstallerRoot();
  std::error_code directory_error;
  std::filesystem::create_directories(restaged_root, directory_error);
  if (directory_error || HasReparsePointInExistingPath(restaged_root)) {
    *error_message = L"Restaged installer root is unsafe.";
    return false;
  }
  const auto transaction_root = restaged_root / journal.bindings.transaction_id;
  std::filesystem::create_directories(transaction_root, directory_error);
  if (directory_error || HasReparsePointInExistingPath(transaction_root)) {
    *error_message = L"Restaged installer path is unsafe.";
    return false;
  }
  const auto target_path = transaction_root / kInstallerName;
  std::filesystem::copy_file(verification.installer_path, target_path,
                             std::filesystem::copy_options::overwrite_existing,
                             directory_error);
  const auto target_sha = ComputeFileSha256(target_path);
  if (directory_error || !IsSafeRegularFile(target_path) ||
      target_sha != journal.bindings.expected_artifact_sha256) {
    *error_message = L"Restaged installer could not be verified.";
    return false;
  }
  *restaged_path = target_path;
  *restaged_sha256 = target_sha;
  return true;
}

bool ValidateRestagedInstaller(const Journal& journal,
                               std::wstring* error_message) {
  if (journal.restaged_installer_path.empty() ||
      journal.restaged_installer_sha256.empty() ||
      !IsSafeRegularFile(journal.restaged_installer_path) ||
      ComputeFileSha256(journal.restaged_installer_path) !=
          journal.restaged_installer_sha256) {
    *error_message = L"Restaged installer is missing or invalid.";
    return false;
  }
  return true;
}

bool ValidateStageLocation(const RequestBindings& bindings,
                           std::wstring* error_message) {
  const std::filesystem::path stage = bindings.stage_path;
  const std::filesystem::path root = GetOwnedStageRoot();
  const std::wstring expected_name =
      std::wstring(kStagePrefix) + bindings.transaction_id;
  if (stage.filename().wstring() != expected_name ||
      !PathsEqual(stage.parent_path(), root) ||
      HasReparsePointInExistingPath(stage) ||
      HasReparsePointInExistingPath(root)) {
    *error_message = L"Stage is not an owned direct child.";
    return false;
  }
  return true;
}

bool ValidatePendingReceipt(const RequestBindings& bindings,
                            const std::wstring& pending,
                            std::wstring* error_message) {
  const auto transaction_id = ExtractJsonString(pending, L"transactionId");
  const auto stage_path = ExtractJsonString(pending, L"stagePath");
  const auto provenance =
      ExtractJsonString(pending, L"stageProvenanceSha256");
  const auto artifact = ExtractJsonString(pending, L"expectedArtifactSha256");
  const auto artifact_length =
      ExtractJsonUnsigned(pending, L"expectedArtifactLength");
  if (!transaction_id || !stage_path || !provenance || !artifact ||
      !artifact_length ||
      *transaction_id != bindings.transaction_id ||
      !PathsEqual(*stage_path, bindings.stage_path) ||
      *provenance != bindings.stage_provenance_sha256 ||
      *artifact != bindings.expected_artifact_sha256 ||
      *artifact_length != bindings.expected_artifact_length) {
    *error_message = L"Pending receipt bindings do not match the request.";
    return false;
  }
  return true;
}

bool ValidateAuthority(const RequestBindings& bindings,
                       const std::filesystem::path& authority_path,
                       std::uint64_t installer_length,
                       std::wstring* candidate_version,
                       std::wstring* candidate_architecture,
                       std::wstring* error_message) {
  const auto authority = ReadUtf8File(authority_path);
  if (!authority) {
    *error_message = L"Authority receipt is unreadable.";
    return false;
  }
  const auto schema_version = ExtractJsonUnsigned(*authority, L"schemaVersion");
  const auto transaction_id =
      ExtractJsonString(*authority, L"transactionId");
  const auto package_id = ExtractJsonString(*authority, L"packageId");
  const auto platform = ExtractJsonString(*authority, L"platform");
  const auto package_type = ExtractJsonString(*authority, L"packageType");
  const auto artifact_name =
      ExtractJsonString(*authority, L"artifactFileName");
  const auto artifact_length =
      ExtractJsonUnsigned(*authority, L"artifactLength");
  const auto artifact_sha =
      ExtractJsonString(*authority, L"artifactSha256");
  const auto source = ExtractJsonString(*authority, L"source");
  const auto version = ExtractJsonString(*authority, L"version");
  const auto architecture = ExtractJsonString(*authority, L"architecture");
  if (!schema_version || *schema_version != 1 || !transaction_id ||
      *transaction_id != bindings.transaction_id || !package_id ||
      *package_id != L"fly_narwhal" || !platform || *platform != L"windows" ||
      !package_type || *package_type != L"exe" || !artifact_name ||
      *artifact_name != kInstallerName || !artifact_length ||
      *artifact_length != installer_length ||
      *artifact_length != bindings.expected_artifact_length || !artifact_sha ||
      *artifact_sha != bindings.expected_artifact_sha256 || !source ||
      *source != L"github-release-digest" || !version || version->empty() ||
      !architecture || (*architecture != L"x64" && *architecture != L"arm64")) {
    *error_message = L"Authority receipt is invalid.";
    return false;
  }
  *candidate_version = *version;
  *candidate_architecture = *architecture;
  return true;
}

bool ValidateProvenance(const RequestBindings& bindings,
                        const std::filesystem::path& provenance_path,
                        const std::filesystem::path& installer_path,
                        const std::filesystem::path& authority_path,
                        std::wstring* error_message) {
  const std::wstring provenance_sha = ComputeFileSha256(provenance_path);
  if (provenance_sha != bindings.stage_provenance_sha256) {
    *error_message = L"Provenance marker digest does not match.";
    return false;
  }
  const auto provenance = ReadUtf8File(provenance_path);
  if (!provenance) {
    *error_message = L"Provenance marker is unreadable.";
    return false;
  }
  const auto stage_name = ExtractJsonString(*provenance, L"stageName");
  if (!stage_name || *stage_name != bindings.stage_path.filename().wstring()) {
    *error_message = L"Provenance stage name does not match.";
    return false;
  }

  const std::wstring installer_sha = ComputeFileSha256(installer_path);
  const std::wstring authority_sha = ComputeFileSha256(authority_path);
  std::error_code file_error;
  const auto installer_length =
      std::filesystem::file_size(installer_path, file_error);
  if (file_error) {
    *error_message = L"Installer inventory length is unavailable.";
    return false;
  }
  const auto authority_length =
      std::filesystem::file_size(authority_path, file_error);
  if (file_error || installer_sha != bindings.expected_artifact_sha256) {
    *error_message = L"Stage inventory file identity is invalid.";
    return false;
  }
  const std::string expected_provenance = BuildCanonicalProvenance(
      bindings.stage_path, installer_length, installer_sha, authority_length,
      authority_sha);
  if (WideToUtf8(*provenance) != expected_provenance) {
    *error_message = L"Canonical provenance inventory does not match.";
    return false;
  }

  // Reject untracked stage entries and any reparse point.
  for (const auto& entry : std::filesystem::directory_iterator(bindings.stage_path)) {
    if (HasReparsePointInExistingPath(entry.path())) {
      *error_message = L"Stage contains a reparse point.";
      return false;
    }
    const std::wstring name = entry.path().filename().wstring();
    if (name != kInstallerName && name != kAuthorityName &&
        name != kProvenanceName && name != kPendingName) {
      *error_message = L"Stage contains an unexpected entry.";
      return false;
    }
  }
  return true;
}

std::string SerializeJournal(const Journal& journal) {
  std::ostringstream output;
  output << "{\"schemaVersion\":2"
         << ",\"transactionId\":\""
         << EscapeJson(journal.bindings.transaction_id)
         << "\",\"stagePath\":\""
         << EscapeJson(journal.bindings.stage_path.wstring())
         << "\",\"stageProvenanceSha256\":\""
         << EscapeJson(journal.bindings.stage_provenance_sha256)
         << "\",\"expectedArtifactSha256\":\""
         << EscapeJson(journal.bindings.expected_artifact_sha256)
         << "\",\"expectedArtifactLength\":"
         << journal.bindings.expected_artifact_length
         << ",\"callerProcessId\":"
         << journal.bindings.caller_process_id
         << ",\"callerExecutable\":\""
         << EscapeJson(journal.bindings.caller_executable.wstring())
         << "\",\"state\":\"" << EscapeJson(StateToString(journal.state))
         << "\",\"helperExecutable\":\""
         << EscapeJson(journal.helper_executable.wstring())
         << "\",\"protectedHelperPath\":\""
         << EscapeJson(journal.protected_helper_path.wstring())
         << "\",\"recoveryHostPath\":\""
         << EscapeJson(journal.recovery_host_path.wstring())
         << "\",\"restagedInstallerPath\":\""
         << EscapeJson(journal.restaged_installer_path.wstring())
         << "\",\"updateLogPath\":\""
         << EscapeJson(journal.update_log_path.wstring())
         << "\",\"helperSha256\":\"" << EscapeJson(journal.helper_sha256)
         << "\",\"restagedInstallerSha256\":\""
         << EscapeJson(journal.restaged_installer_sha256)
         << "\",\"endpointVersion\":\""
         << EscapeJson(journal.endpoint_version)
         << "\",\"recoveryTaskName\":\""
         << EscapeJson(journal.recovery_task_name)
         << "\",\"installerStarted\":"
         << (journal.installer_started ? "true" : "false")
         << ",\"relaunchAttempted\":"
         << (journal.relaunch_attempted ? "true" : "false")
         << ",\"recoveryArmed\":"
         << (journal.recovery_armed ? "true" : "false")
         << ",\"installerExitCode\":" << journal.installer_exit_code
         << ",\"terminalMessage\":\""
         << EscapeJson(journal.terminal_message) << "\"}";
  return output.str();
}

std::optional<Journal> ParseJournal(const std::wstring& json) {
  Journal journal;
  const auto schema = ExtractJsonUnsigned(json, L"schemaVersion");
  const auto transaction = ExtractJsonString(json, L"transactionId");
  const auto stage = ExtractJsonString(json, L"stagePath");
  const auto provenance =
      ExtractJsonString(json, L"stageProvenanceSha256");
  const auto artifact = ExtractJsonString(json, L"expectedArtifactSha256");
  const auto artifact_length =
      ExtractJsonUnsigned(json, L"expectedArtifactLength");
  const auto process_id = ExtractJsonUnsigned(json, L"callerProcessId");
  const auto caller = ExtractJsonString(json, L"callerExecutable");
  const auto state_value = ExtractJsonString(json, L"state");
  const auto helper_path = ExtractJsonString(json, L"helperExecutable");
  const auto protected_helper_path =
      ExtractJsonString(json, L"protectedHelperPath");
  const auto recovery_host_path =
      ExtractJsonString(json, L"recoveryHostPath");
  const auto restaged_installer_path =
      ExtractJsonString(json, L"restagedInstallerPath");
  const auto update_log_path = ExtractJsonString(json, L"updateLogPath");
  const auto helper_sha = ExtractJsonString(json, L"helperSha256");
  const auto restaged_installer_sha =
      ExtractJsonString(json, L"restagedInstallerSha256");
  const auto endpoint_version = ExtractJsonString(json, L"endpointVersion");
  const auto recovery_task_name = ExtractJsonString(json, L"recoveryTaskName");
  const auto exit_code = ExtractJsonUnsigned(json, L"installerExitCode");
  const auto terminal_message = ExtractJsonString(json, L"terminalMessage");
  bool installer_started = false;
  bool relaunch_attempted = false;
  bool recovery_armed = false;
  const auto state = state_value ? StateFromString(*state_value) : std::nullopt;
  if (!schema || (*schema != 1 && *schema != 2) || !transaction || !stage ||
      !provenance ||
      !artifact || !artifact_length || *artifact_length == 0 || !process_id ||
      *process_id > MAXDWORD || !caller || !state ||
      !helper_path || !helper_sha || !exit_code || *exit_code > MAXDWORD ||
      !terminal_message ||
      !ExtractJsonBoolean(json, L"installerStarted", &installer_started) ||
      !ExtractJsonBoolean(json, L"relaunchAttempted", &relaunch_attempted) ||
      (*schema == 2 &&
       !ExtractJsonBoolean(json, L"recoveryArmed", &recovery_armed))) {
    return std::nullopt;
  }
  journal.bindings.transaction_id = *transaction;
  journal.bindings.stage_path = *stage;
  journal.bindings.stage_provenance_sha256 = *provenance;
  journal.bindings.expected_artifact_sha256 = *artifact;
  journal.bindings.expected_artifact_length = *artifact_length;
  journal.bindings.caller_process_id = static_cast<DWORD>(*process_id);
  journal.bindings.caller_executable = *caller;
  journal.state = *state;
  journal.helper_executable = *helper_path;
  if (protected_helper_path) {
    journal.protected_helper_path = *protected_helper_path;
  }
  if (recovery_host_path) {
    journal.recovery_host_path = *recovery_host_path;
  }
  if (restaged_installer_path) {
    journal.restaged_installer_path = *restaged_installer_path;
  }
  if (update_log_path) {
    journal.update_log_path = *update_log_path;
  }
  journal.helper_sha256 = *helper_sha;
  if (restaged_installer_sha) {
    journal.restaged_installer_sha256 = *restaged_installer_sha;
  }
  if (endpoint_version) {
    journal.endpoint_version = *endpoint_version;
  }
  if (recovery_task_name) {
    journal.recovery_task_name = *recovery_task_name;
  }
  journal.installer_started = installer_started;
  journal.relaunch_attempted = relaunch_attempted;
  journal.recovery_armed = recovery_armed;
  journal.installer_exit_code = static_cast<DWORD>(*exit_code);
  journal.terminal_message = *terminal_message;
  journal.schema_version = 2;
  return journal;
}

bool BindingsEqual(const RequestBindings& left, const RequestBindings& right) {
  return left.transaction_id == right.transaction_id &&
         PathsEqual(left.stage_path, right.stage_path) &&
         left.stage_provenance_sha256 == right.stage_provenance_sha256 &&
         left.expected_artifact_sha256 == right.expected_artifact_sha256 &&
         left.expected_artifact_length == right.expected_artifact_length &&
         left.caller_process_id == right.caller_process_id &&
         PathsEqual(left.caller_executable, right.caller_executable);
}

bool ValidateJournalExecutableBindingImpl(
    const Journal& journal,
    const std::filesystem::path& current_executable_path,
    const std::wstring& current_executable_sha);

bool ValidateJournalEndpoint(const Journal& journal,
                             const RequestBindings& bindings,
                             std::wstring* error_message) {
  const auto helper_path = GetCurrentExecutablePath();
  const auto helper_sha = ComputeFileSha256(helper_path);
  if (!BindingsEqual(journal.bindings, bindings) ||
      !ValidateJournalExecutableBindingImpl(journal, helper_path, helper_sha)) {
    *error_message = L"Transaction endpoint binding does not match.";
    return false;
  }
  return true;
}

bool ValidateJournalExecutableBindingImpl(
    const Journal& journal,
    const std::filesystem::path& current_executable_path,
    const std::wstring& current_executable_sha) {
  // Allow the registered protected helper or the legacy worker fallback copy
  // during the migration window, but always require the trusted helper digest.
  const auto worker_path = GetWorkerRoot() / journal.bindings.transaction_id /
                           journal.helper_executable.filename();
  const auto endpoint_path = journal.protected_helper_path.empty()
                                 ? journal.helper_executable
                                 : journal.protected_helper_path;
  return ((PathsEqual(endpoint_path, current_executable_path) ||
           PathsEqual(worker_path, current_executable_path)) &&
          journal.helper_sha256 == current_executable_sha);
}

bool StartDetachedRecoveryWaiter(
    const std::filesystem::path& recovery_runtime_path,
    const std::wstring& transaction_id,
    std::wstring* error_message) {
  std::wstring command_line =
      QuoteWindowsArgument(recovery_runtime_path.wstring());
  command_line += L" resume --transaction-id ";
  command_line += QuoteWindowsArgument(transaction_id);
  LogInfo(std::wstring(L"Starting detached recovery waiter from: ") +
          recovery_runtime_path.wstring());
  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_information{};
  if (!CreateProcessW(recovery_runtime_path.c_str(), command_line.data(),
                      nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr,
                      nullptr, &startup_info, &process_information)) {
    const DWORD last_error = GetLastError();
    LogError(std::wstring(L"Unable to start the recovery waiter; last error ") +
             std::to_wstring(last_error) + L".");
    *error_message = L"Unable to start the recovery waiter.";
    return false;
  }
  LogInfo(std::wstring(L"Recovery waiter started with process id ") +
          std::to_wstring(process_information.dwProcessId) + L".");
  CloseHandle(process_information.hThread);
  CloseHandle(process_information.hProcess);
  return true;
}

int PersistFailure(Journal journal, const std::wstring& message,
                   TransactionState state = TransactionState::failed);

// Shared fallback used when the scheduled recovery host cannot take over:
// run the already-provisioned recovery runtime copy directly as a detached
// waiter instead of stranding the transaction in a terminal manual-action
// state. No additional executable copy is created; the waiter is the same
// recovery host binary the scheduled task would have launched.
int RecoverWithDirectWaiterFallback(
    Journal* journal,
    const std::filesystem::path& recovery_runtime_path,
    std::wstring* error_message) {
  journal->recovery_armed = false;
  journal->recovery_task_name.clear();
  journal->state = TransactionState::commit_accepted;
  if (!WriteJournalDurably(*journal, error_message)) {
    return PersistFailure(*journal, *error_message);
  }
  if (!StartDetachedRecoveryWaiter(recovery_runtime_path,
                                   journal->bindings.transaction_id,
                                   error_message)) {
    return PersistFailure(*journal, *error_message,
                          TransactionState::manual_action_required);
  }
  LogInfo(L"Commit accepted and direct recovery waiter launch requested.");
  std::wcout << L"commitAccepted\n";
  return 0;
}

bool StartInstallerAndWait(const ProcessLaunchPolicy& policy,
                           DWORD* exit_code,
                           std::wstring* error_message) {
  std::wstring command_line = QuoteWindowsArgument(policy.installer_path.wstring());
  for (const auto& argument : BuildFixedInstallerArguments(policy)) {
    command_line += L' ';
    command_line += QuoteWindowsArgument(argument);
  }
  LogInfo(std::wstring(L"Launching verified installer with log path: ") +
          policy.log_path.wstring());
  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_information{};
  if (!CreateProcessW(policy.installer_path.c_str(), command_line.data(), nullptr,
                      nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr,
                      &startup_info, &process_information)) {
    *error_message = L"Unable to start the verified installer.";
    return false;
  }
  ScopedHandle process(process_information.hProcess);
  CloseHandle(process_information.hThread);
  const DWORD wait_result =
      WaitForSingleObject(process.value, kInstallerTimeoutMilliseconds);
  if (wait_result == WAIT_TIMEOUT) {
    TerminateProcess(process.value, ERROR_TIMEOUT);
    WaitForSingleObject(process.value, 5000);
    LogError(L"Installer timed out after 20 minutes.");
    *error_message = L"Installer exceeded the fixed 20 minute timeout.";
    return false;
  }
  if (wait_result != WAIT_OBJECT_0 ||
      !GetExitCodeProcess(process.value, exit_code)) {
    LogError(L"Installer completion could not be observed.");
    *error_message = L"Installer completion could not be observed.";
    return false;
  }
  LogInfo(std::wstring(L"Installer process exited with code: ") +
          std::to_wstring(*exit_code));
  return true;
}

bool RelaunchInstalledApplication(Journal* journal,
                                  std::wstring* error_message) {
  if (journal->relaunch_attempted) {
    *error_message = L"Automatic relaunch was already attempted.";
    return false;
  }
  journal->relaunch_attempted = true;
  journal->state = TransactionState::completed;
  journal->terminal_message =
      L"Installation completed; automatic relaunch is being attempted.";
  if (!WriteJournalDurably(*journal, error_message)) {
    return false;
  }
  const auto install_root =
      GetInstallRootForExecutable(journal->bindings.caller_executable);
  const auto executable = install_root / kInstalledExecutableName;
  if (!IsSafeRegularFile(executable)) {
    *error_message = L"Installed executable is missing or unsafe.";
    return false;
  }
  SHELLEXECUTEINFOW execute_info{};
  execute_info.cbSize = sizeof(execute_info);
  execute_info.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_FLAG_NO_UI;
  execute_info.lpFile = executable.c_str();
  execute_info.nShow = SW_SHOWNORMAL;
  if (!ShellExecuteExW(&execute_info)) {
    *error_message = L"Installed application could not be relaunched.";
    return false;
  }
  if (execute_info.hProcess != nullptr) {
    CloseHandle(execute_info.hProcess);
  }
  return true;
}

std::optional<std::array<unsigned long, 4>> ParseVersion(
    const std::wstring& version) {
  std::array<unsigned long, 4> parts{};
  std::wistringstream input(version);
  std::wstring part;
  std::size_t index = 0;
  while (std::getline(input, part, L'.')) {
    if (index >= parts.size() || part.empty()) {
      return std::nullopt;
    }
    try {
      parts[index++] = std::stoul(part);
    } catch (...) {
      return std::nullopt;
    }
  }
  return index >= 2 ? std::optional(parts) : std::nullopt;
}

bool ValidateInstalledExecutableImpl(const std::filesystem::path& executable,
                                     const StageVerification& verification,
                                     std::wstring* error_message) {
  ScopedHandle file(CreateFileW(executable.c_str(), GENERIC_READ,
                               FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                               FILE_ATTRIBUTE_NORMAL, nullptr));
  IMAGE_DOS_HEADER dos_header{};
  DWORD bytes_read = 0;
  if (!file.valid() ||
      !ReadFile(file.value, &dos_header, sizeof(dos_header), &bytes_read,
                nullptr) ||
      bytes_read != sizeof(dos_header) || dos_header.e_magic != IMAGE_DOS_SIGNATURE ||
      SetFilePointer(file.value, dos_header.e_lfanew, nullptr, FILE_BEGIN) ==
          INVALID_SET_FILE_POINTER) {
    *error_message = L"Installed executable has an invalid PE header.";
    return false;
  }
  DWORD signature = 0;
  IMAGE_FILE_HEADER file_header{};
  if (!ReadFile(file.value, &signature, sizeof(signature), &bytes_read,
                nullptr) || signature != IMAGE_NT_SIGNATURE ||
      !ReadFile(file.value, &file_header, sizeof(file_header), &bytes_read,
                nullptr)) {
    *error_message = L"Installed executable has an invalid PE header.";
    return false;
  }
  const WORD expected_machine = verification.candidate_architecture == L"arm64"
                                    ? IMAGE_FILE_MACHINE_ARM64
                                    : IMAGE_FILE_MACHINE_AMD64;
  if (file_header.Machine != expected_machine) {
    *error_message = L"Installed executable architecture is incorrect.";
    return false;
  }

  DWORD ignored = 0;
  const DWORD version_size =
      GetFileVersionInfoSizeW(executable.c_str(), &ignored);
  std::vector<BYTE> version_buffer(version_size);
  VS_FIXEDFILEINFO* version_info = nullptr;
  UINT version_info_size = 0;
  if (version_size == 0 ||
      !GetFileVersionInfoW(executable.c_str(), 0, version_size,
                           version_buffer.data()) ||
      !VerQueryValueW(version_buffer.data(), L"\\",
                       reinterpret_cast<void**>(&version_info),
                       &version_info_size) ||
      version_info == nullptr || version_info_size < sizeof(VS_FIXEDFILEINFO)) {
    *error_message = L"Installed executable file version is unavailable.";
    return false;
  }
  const std::array<unsigned long, 4> installed_version = {
      HIWORD(version_info->dwFileVersionMS),
      LOWORD(version_info->dwFileVersionMS),
      HIWORD(version_info->dwFileVersionLS),
      LOWORD(version_info->dwFileVersionLS),
  };
  const auto candidate_version = ParseVersion(verification.candidate_version);
  if (!candidate_version || installed_version < *candidate_version) {
    *error_message = L"Installed executable version is below the candidate.";
    return false;
  }
  return true;
}

int PersistFailure(Journal journal, const std::wstring& message,
                   TransactionState state) {
  journal.state = state;
  journal.terminal_message = message;
  if (!journal.update_log_path.empty()) {
    StartUpdateLogSession(journal.update_log_path);
  }
  LogError(message);
  std::wstring ignored;
  WriteJournalDurably(journal, &ignored);
  std::wcerr << message << L'\n';
  return 1;
}

}  // namespace

void LogInfo(const std::wstring& message) {
  AppendUpdateLogLine(L"INFO", message);
}

void LogWarning(const std::wstring& message) {
  AppendUpdateLogLine(L"WARN", message);
}

void LogError(const std::wstring& message) {
  AppendUpdateLogLine(L"ERROR", message);
}

std::filesystem::path CreateUpdateLogPath() {
  return GetUpdateLogDirectory() /
         (std::wstring(kUpdateLogFilePrefix) +
          FormatFileTimestamp(std::time(nullptr)) + kUpdateLogFileExtension);
}

void StartUpdateLogSession(const std::filesystem::path& log_path) {
  if (log_path.empty()) {
    return;
  }
  std::error_code error;
  std::filesystem::create_directories(log_path.parent_path(), error);
  if (error) {
    return;
  }
  AttachUpdateLogPath(log_path);
  CleanupExpiredUpdateLogs();
  AppendUpdateLogLine(
      L"INFO",
      std::wstring(L"Attached update log file: ") + log_path.wstring());
}

void EnsureJournalHasUpdateLogPath(Journal* journal) {
  if (journal == nullptr || !journal->update_log_path.empty()) {
    return;
  }
  journal->update_log_path = CreateUpdateLogPath();
}

// Rebind a journal to the trusted registry endpoint. The protected helper may
// have been updated after the transaction was prepared, leaving the journal's
// cached endpoint provenance stale. Only endpoint provenance is refreshed; the
// transaction bindings and stage provenance are never mutated here.
void RefreshJournalEndpointBinding(Journal* journal,
                                   const EndpointDescriptor& descriptor) {
  journal->helper_executable = descriptor.protected_helper_path;
  journal->protected_helper_path = descriptor.protected_helper_path;
  journal->recovery_host_path = descriptor.recovery_host_path;
  journal->endpoint_version = descriptor.endpoint_version;
  journal->helper_sha256 = descriptor.protected_helper_sha256;
}

bool ValidateJournalExecutableBinding(
    const Journal& journal,
    const std::filesystem::path& current_executable_path,
    const std::wstring& current_executable_sha) {
  return ValidateJournalExecutableBindingImpl(
      journal, current_executable_path, current_executable_sha);
}

bool ValidateInstalledExecutable(const std::filesystem::path& executable,
                                 const StageVerification& verification,
                                 std::wstring* error_message) {
  return ValidateInstalledExecutableImpl(executable, verification,
                                         error_message);
}

std::wstring StateToString(TransactionState state) {
  switch (state) {
    case TransactionState::prepared:
      return L"prepared";
    case TransactionState::restaged:
      return L"restaged";
    case TransactionState::recovery_armed:
      return L"recoveryArmed";
    case TransactionState::commit_accepted:
      return L"commitAccepted";
    case TransactionState::waiting_for_exit:
      return L"waitingForExit";
    case TransactionState::manager_started:
      return L"managerStarted";
    case TransactionState::verification_pending:
      return L"verificationPending";
    case TransactionState::completed:
      return L"completed";
    case TransactionState::failed:
      return L"failed";
    case TransactionState::cancelled:
      return L"cancelled";
    case TransactionState::manual_action_required:
      return L"manualActionRequired";
  }
  return L"manualActionRequired";
}

std::optional<TransactionState> StateFromString(const std::wstring& value) {
  const std::array<std::pair<const wchar_t*, TransactionState>, 11> states = {{
      {L"prepared", TransactionState::prepared},
      {L"restaged", TransactionState::restaged},
      {L"recoveryArmed", TransactionState::recovery_armed},
      {L"commitAccepted", TransactionState::commit_accepted},
      {L"waitingForExit", TransactionState::waiting_for_exit},
      {L"managerStarted", TransactionState::manager_started},
      {L"verificationPending", TransactionState::verification_pending},
      {L"completed", TransactionState::completed},
      {L"failed", TransactionState::failed},
      {L"cancelled", TransactionState::cancelled},
      {L"manualActionRequired", TransactionState::manual_action_required},
  }};
  for (const auto& [name, state] : states) {
    if (value == name) {
      return state;
    }
  }
  return std::nullopt;
}

bool IsTerminalState(TransactionState state) {
  return state == TransactionState::completed ||
         state == TransactionState::failed ||
         state == TransactionState::cancelled ||
         state == TransactionState::manual_action_required;
}

bool IsCanonicalUuidV4(const std::wstring& value) {
  static const std::wregex expression(
      LR"(^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$)");
  return std::regex_match(value, expression);
}

bool IsLowercaseSha256(const std::wstring& value) {
  static const std::wregex expression(LR"(^[0-9a-f]{64}$)");
  return std::regex_match(value, expression);
}

std::filesystem::path GetLocalAppDataPath() {
  // Tests redirect the updater data root to a hermetic temp directory so the
  // real production journal and app data are never touched.
  wchar_t override_root[32768]{};
  const DWORD override_length =
      GetEnvironmentVariableW(L"FLYNARWHAL_UPDATER_DATA_ROOT", override_root,
                              static_cast<DWORD>(std::size(override_root)));
  if (override_length > 0 && override_length < std::size(override_root)) {
    return std::filesystem::path(std::wstring(override_root, override_length));
  }
  PWSTR raw_path = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_DEFAULT,
                                  nullptr, &raw_path))) {
    return {};
  }
  const std::filesystem::path result(raw_path);
  CoTaskMemFree(raw_path);
  return result;
}

std::filesystem::path GetJournalPath() {
  return GetLocalAppDataPath() / L"FlyNarwhal" / L"update-transactions" /
         L"active-transaction.json";
}

std::filesystem::path GetInstallRootForExecutable(
    const std::filesystem::path& executable_path) {
  if (executable_path.empty()) {
    return {};
  }
  return executable_path.parent_path();
}

bool ValidateCallerInstallRoot(
    const std::filesystem::path& helper_executable_path,
    const std::filesystem::path& caller_executable_path) {
  const auto helper_install_root =
      GetInstallRootForExecutable(helper_executable_path);
  const auto caller_install_root =
      GetInstallRootForExecutable(caller_executable_path);
  return !helper_install_root.empty() && !caller_install_root.empty() &&
         !HasReparsePointInExistingPath(helper_install_root) &&
         !HasReparsePointInExistingPath(caller_install_root) &&
         PathsEqual(caller_install_root, helper_install_root);
}

std::filesystem::path GetCurrentExecutablePath() {
  std::wstring buffer(32768, L'\0');
  const DWORD length = GetModuleFileNameW(nullptr, buffer.data(),
                                          static_cast<DWORD>(buffer.size()));
  if (length == 0 || length >= buffer.size()) {
    return {};
  }
  buffer.resize(length);
  return buffer;
}

std::wstring ComputeFileSha256(const std::filesystem::path& path) {
  ScopedHandle file(CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ,
                               nullptr, OPEN_EXISTING,
                               FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
                               nullptr));
  if (!file.valid()) {
    return {};
  }
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  BCRYPT_HASH_HANDLE hash = nullptr;
  DWORD object_length = 0;
  DWORD result_length = 0;
  std::wstring result;
  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr,
                                  0) != 0 ||
      BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH,
                        reinterpret_cast<PUCHAR>(&object_length),
                        sizeof(object_length), &result_length, 0) != 0) {
    if (algorithm != nullptr) {
      BCryptCloseAlgorithmProvider(algorithm, 0);
    }
    return {};
  }
  std::vector<UCHAR> hash_object(object_length);
  std::array<UCHAR, 32> digest{};
  if (BCryptCreateHash(algorithm, &hash, hash_object.data(), object_length,
                       nullptr, 0, 0) != 0) {
    BCryptCloseAlgorithmProvider(algorithm, 0);
    return {};
  }
  std::array<UCHAR, 64 * 1024> buffer{};
  DWORD bytes_read = 0;
  bool succeeded = true;
  while (true) {
    if (!ReadFile(file.value, buffer.data(),
                  static_cast<DWORD>(buffer.size()), &bytes_read, nullptr)) {
      succeeded = false;
      break;
    }
    if (bytes_read == 0) {
      break;
    }
    if (BCryptHashData(hash, buffer.data(), bytes_read, 0) != 0) {
      succeeded = false;
      break;
    }
  }
  if (!succeeded || BCryptFinishHash(hash, digest.data(),
                                     static_cast<ULONG>(digest.size()), 0) != 0) {
    BCryptDestroyHash(hash);
    BCryptCloseAlgorithmProvider(algorithm, 0);
    return {};
  }
  BCryptDestroyHash(hash);
  BCryptCloseAlgorithmProvider(algorithm, 0);
  std::wostringstream output;
  output << std::hex << std::setfill(L'0');
  for (const UCHAR byte : digest) {
    output << std::setw(2) << static_cast<unsigned int>(byte);
  }
  return output.str();
}

bool HasReparsePointInExistingPath(const std::filesystem::path& path) {
  std::filesystem::path current = path.root_path();
  for (const auto& component : path.relative_path()) {
    current /= component;
    const DWORD attributes = GetFileAttributesW(current.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) {
      continue;
    }
    if ((attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
      return true;
    }
  }
  return false;
}

bool ValidateCallerIdentity(const RequestBindings& bindings) {
  if (bindings.caller_process_id == 0 ||
      bindings.caller_executable.filename() != kInstalledExecutableName ||
      !IsSafeRegularFile(bindings.caller_executable)) {
    return false;
  }
  ScopedHandle process(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION |
                                       SYNCHRONIZE,
                                   FALSE, bindings.caller_process_id));
  if (!process.valid()) {
    return false;
  }
  std::wstring process_path(32768, L'\0');
  DWORD process_path_length = static_cast<DWORD>(process_path.size());
  if (!QueryFullProcessImageNameW(process.value, 0, process_path.data(),
                                  &process_path_length)) {
    return false;
  }
  process_path.resize(process_path_length);
  return PathsEqual(process_path, bindings.caller_executable);
}

bool ValidateStage(const RequestBindings& bindings,
                   StageVerification* verification,
                   std::wstring* error_message) {
  if (!IsCanonicalUuidV4(bindings.transaction_id) ||
      !IsLowercaseSha256(bindings.stage_provenance_sha256) ||
      !IsLowercaseSha256(bindings.expected_artifact_sha256) ||
      bindings.expected_artifact_length == 0 ||
      !ValidateStageLocation(bindings, error_message)) {
    if (error_message->empty()) {
      *error_message = L"Request identifiers are invalid.";
    }
    return false;
  }
  const auto installer = bindings.stage_path / kInstallerName;
  const auto authority = bindings.stage_path / kAuthorityName;
  const auto provenance = bindings.stage_path / kProvenanceName;
  const auto pending = bindings.stage_path / kPendingName;
  if (!IsSafeRegularFile(installer) || !IsSafeRegularFile(authority) ||
      !IsSafeRegularFile(provenance) || !IsSafeRegularFile(pending)) {
    *error_message = L"Stage required files are missing or unsafe.";
    return false;
  }
  std::error_code file_error;
  const std::uint64_t installer_length =
      std::filesystem::file_size(installer, file_error);
  const auto actual_installer_sha256 = ComputeFileSha256(installer);
  if (file_error || installer_length == 0 ||
      installer_length != bindings.expected_artifact_length ||
      actual_installer_sha256 != bindings.expected_artifact_sha256 ||
      !ValidateAuthority(bindings, authority, installer_length,
                         &verification->candidate_version,
                         &verification->candidate_architecture,
                         error_message) ||
      !ValidateProvenance(bindings, provenance, installer, authority,
                          error_message)) {
    return false;
  }
  const auto pending_contents = ReadUtf8File(pending);
  if (!pending_contents ||
      !ValidatePendingReceipt(bindings, *pending_contents, error_message)) {
    if (error_message->empty()) {
      *error_message = L"Pending receipt is unreadable.";
    }
    return false;
  }
  verification->installer_path = installer;
  verification->authority_path = authority;
  verification->provenance_path = provenance;
  verification->artifact_length = installer_length;
  return true;
}

std::vector<std::wstring> BuildFixedInstallerArguments(
    const ProcessLaunchPolicy& policy) {
  return {L"/VERYSILENT",       L"/SP-", L"/SUPPRESSMSGBOXES",
          L"/NORESTART",        L"/CLOSEAPPLICATIONS",
          L"/DIR=" + policy.install_root.wstring(),
          L"/LOG=" + policy.log_path.wstring()};
}

std::wstring QuoteWindowsArgument(const std::wstring& argument) {
  std::wstring quoted = L"\"";
  std::size_t backslashes = 0;
  for (const wchar_t character : argument) {
    if (character == L'\\') {
      ++backslashes;
      continue;
    }
    if (character == L'"') {
      quoted.append(backslashes * 2 + 1, L'\\');
      quoted += L'"';
      backslashes = 0;
      continue;
    }
    quoted.append(backslashes, L'\\');
    backslashes = 0;
    quoted += character;
  }
  quoted.append(backslashes * 2, L'\\');
  quoted += L'"';
  return quoted;
}

bool WriteJournalDurably(const Journal& journal, std::wstring* error_message) {
  const auto journal_path = GetJournalPath();
  const auto temporary_path = journal_path.wstring() + L".tmp";
  std::error_code directory_error;
  std::filesystem::create_directories(journal_path.parent_path(),
                                      directory_error);
  if (directory_error || HasReparsePointInExistingPath(journal_path.parent_path())) {
    *error_message = L"Journal directory is unsafe.";
    return false;
  }
  const std::string contents = SerializeJournal(journal);
  ScopedHandle file(CreateFileW(temporary_path.c_str(), GENERIC_WRITE, 0, nullptr,
                               CREATE_ALWAYS,
                               FILE_ATTRIBUTE_NORMAL | FILE_FLAG_WRITE_THROUGH,
                               nullptr));
  if (!file.valid()) {
    *error_message = L"Journal temporary file could not be created.";
    return false;
  }
  DWORD bytes_written = 0;
  if (!WriteFile(file.value, contents.data(), static_cast<DWORD>(contents.size()),
                 &bytes_written, nullptr) ||
      bytes_written != contents.size() || !FlushFileBuffers(file.value)) {
    *error_message = L"Journal temporary file could not be flushed.";
    return false;
  }
  CloseHandle(file.value);
  file.value = INVALID_HANDLE_VALUE;
  if (!MoveFileExW(temporary_path.c_str(), journal_path.c_str(),
                   MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
    DeleteFileW(temporary_path.c_str());
    *error_message = L"Journal atomic replacement failed.";
    return false;
  }
  const auto reread = ReadUtf8File(journal_path);
  if (!reread || WideToUtf8(*reread) != contents) {
    *error_message = L"Journal readback did not match the committed bytes.";
    return false;
  }
  return true;
}

std::optional<Journal> ReadJournal(std::wstring* error_message) {
  const auto path = GetJournalPath();
  if (!std::filesystem::exists(path)) {
    *error_message = L"No active transaction exists.";
    return std::nullopt;
  }
  if (!IsSafeRegularFile(path)) {
    *error_message = L"Journal path is unsafe.";
    return std::nullopt;
  }
  const auto contents = ReadUtf8File(path);
  const auto journal = contents ? ParseJournal(*contents) : std::nullopt;
  if (!journal || !IsCanonicalUuidV4(journal->bindings.transaction_id) ||
      !IsLowercaseSha256(journal->helper_sha256)) {
    *error_message = L"Journal is corrupt or ambiguous.";
    return std::nullopt;
  }
  return journal;
}

bool ClearTerminalJournal(std::wstring* error_message) {
  const auto journal = ReadJournal(error_message);
  if (!journal) {
    return false;
  }
  if (!IsTerminalState(journal->state)) {
    *error_message = L"An active transaction cannot be removed.";
    return false;
  }
  std::error_code error;
  std::filesystem::remove(GetJournalPath(), error);
  if (error) {
    *error_message = L"Terminal journal could not be removed.";
    return false;
  }
  return true;
}

int RunPrepare(const RequestBindings& bindings) {
  StageVerification verification;
  std::wstring error;
  EndpointDescriptor descriptor;
  EndpointPolicy policy;
  StartUpdateLogSession(CreateUpdateLogPath());
  LogInfo(std::wstring(L"Prepare requested for transaction: ") +
          bindings.transaction_id);

  // Record the validation outcome before reserving the durable journal.
  if (!LoadValidatedEndpoint(&descriptor, &policy, &error) ||
      !ValidateCurrentProtectedExecutable(
          descriptor, policy, GetCurrentExecutablePath(),
          ComputeFileSha256(GetCurrentExecutablePath()), false,
          bindings.transaction_id, &error) ||
      !ValidateCallerIdentity(bindings) ||
      !ValidateStage(bindings, &verification, &error)) {
    LogError(error.empty() ? L"Caller identity is invalid." : error);
    std::wcerr << (error.empty() ? L"Caller identity is invalid." : error)
               << L'\n';
    return 2;
  }
  const auto existing = ReadJournal(&error);
  if (existing && !IsTerminalState(existing->state)) {
    if (BindingsEqual(existing->bindings, bindings)) {
      std::wcout << StateToString(existing->state) << L'\n';
      return 0;
    }
    std::wcerr << L"Another install transaction is active.\n";
    return 3;
  }
  Journal journal;
  journal.bindings = bindings;
  journal.state = TransactionState::prepared;
  journal.helper_executable = GetCurrentExecutablePath();
  journal.protected_helper_path = descriptor.protected_helper_path;
  journal.recovery_host_path = descriptor.recovery_host_path;
  journal.endpoint_version = descriptor.endpoint_version;
  journal.update_log_path = g_active_update_log_path;
  const auto helper_sha256 = descriptor.protected_helper_sha256;
  if (!IsLowercaseSha256(helper_sha256)) {
    LogError(L"Helper SHA-256 could not be computed.");
    std::wcerr << L"Helper SHA-256 could not be computed.\n";
    return 2;
  }
  journal.helper_sha256 = helper_sha256;
  if (!WriteJournalDurably(journal, &error)) {
    LogError(error);
    std::wcerr << error << L'\n';
    return 1;
  }
  LogInfo(L"Prepare completed successfully.");
  std::wcout << L"prepared\n";
  return 0;
}

int RunCommit(const RequestBindings& bindings) {
  std::wstring error;
  EndpointDescriptor descriptor;
  EndpointPolicy policy;
  auto journal = ReadJournal(&error);
  if (journal) {
    EnsureJournalHasUpdateLogPath(&*journal);
    StartUpdateLogSession(journal->update_log_path);
    LogInfo(std::wstring(L"Commit requested for transaction: ") +
            journal->bindings.transaction_id);
  }
  if (!journal || !LoadValidatedEndpoint(&descriptor, &policy, &error) ||
      !ValidateCurrentProtectedExecutable(
          descriptor, policy, GetCurrentExecutablePath(),
          ComputeFileSha256(GetCurrentExecutablePath()), false,
          bindings.transaction_id, &error) ||
      !ValidateJournalEndpoint(*journal, bindings, &error) ||
      !ValidateCallerIdentity(bindings)) {
    LogError(error.empty() ? L"Caller identity is invalid." : error);
    std::wcerr << (error.empty() ? L"Caller identity is invalid." : error)
               << L'\n';
    return 2;
  }
  if (journal->state == TransactionState::restaged ||
      journal->state == TransactionState::recovery_armed ||
      journal->state == TransactionState::commit_accepted ||
      journal->state == TransactionState::waiting_for_exit ||
      journal->state == TransactionState::manager_started ||
      journal->state == TransactionState::verification_pending ||
      journal->state == TransactionState::completed) {
    std::wcout << StateToString(journal->state) << L'\n';
    return 0;
  }
  if (journal->state != TransactionState::prepared) {
    std::wcerr << L"Transaction cannot be committed from its current state.\n";
    return 2;
  }
  StageVerification verification;
  if (!ValidateStage(bindings, &verification, &error)) {
    LogError(error);
    std::wcerr << error << L'\n';
    return 2;
  }
  journal->protected_helper_path = descriptor.protected_helper_path;
  journal->recovery_host_path = descriptor.recovery_host_path;
  journal->endpoint_version = descriptor.endpoint_version;
  if (!RestageInstaller(*journal, verification, &journal->restaged_installer_path,
                        &journal->restaged_installer_sha256, &error)) {
    return PersistFailure(*journal, error,
                          TransactionState::manual_action_required);
  }
  journal->state = TransactionState::restaged;
  if (!WriteJournalDurably(*journal, &error)) {
    return PersistFailure(*journal, error);
  }
  LogInfo(std::wstring(L"Installer restaged successfully to: ") +
          journal->restaged_installer_path.wstring());

  std::filesystem::path recovery_runtime_path;
  if (!CreateRecoveryRuntimeCopy(journal->recovery_host_path,
                                 descriptor.recovery_host_sha256,
                                 journal->bindings.transaction_id,
                                 &recovery_runtime_path, &error)) {
    LogWarning(L"Recovery host runtime copy could not be created.");
    return PersistFailure(*journal, error,
                          TransactionState::manual_action_required);
  }

  if (!ArmRecoveryHostTask(recovery_runtime_path, journal->bindings.transaction_id,
                           &journal->recovery_task_name, &error)) {
    LogWarning(L"Recovery host task could not be armed; using direct recovery waiter fallback.");
    return RecoverWithDirectWaiterFallback(&*journal, recovery_runtime_path,
                                           &error);
  }

  journal->recovery_armed = true;
  journal->state = TransactionState::recovery_armed;
  if (!WriteJournalDurably(*journal, &error)) {
    return PersistFailure(*journal, error);
  }
  LogInfo(L"Commit accepted and recovery host handoff requested.");
  std::wcout << L"recoveryArmed\n";
  return 0;
}

int RunQuery(const std::wstring& transaction_id) {
  if (!IsCanonicalUuidV4(transaction_id)) {
    return 64;
  }
  std::wstring error;
  const auto journal = ReadJournal(&error);
  if (!journal || journal->bindings.transaction_id != transaction_id) {
    std::wcerr << error << L'\n';
    return 4;
  }
  if (!journal->update_log_path.empty()) {
    StartUpdateLogSession(journal->update_log_path);
    LogInfo(std::wstring(L"Query requested. Current state: ") +
            StateToString(journal->state));
  }
  std::wcout << StateToString(journal->state) << L'\n';
  return 0;
}

int RunCancel(const std::wstring& transaction_id) {
  if (!IsCanonicalUuidV4(transaction_id)) {
    return 64;
  }
  std::wstring error;
  auto journal = ReadJournal(&error);
  if (journal) {
    EnsureJournalHasUpdateLogPath(&*journal);
    StartUpdateLogSession(journal->update_log_path);
    LogWarning(std::wstring(L"Cancel requested for transaction: ") +
               journal->bindings.transaction_id);
  }
  if (!journal || journal->bindings.transaction_id != transaction_id ||
      !ValidateJournalEndpoint(*journal, journal->bindings, &error)) {
    LogError(error);
    std::wcerr << error << L'\n';
    return 2;
  }
  if (journal->state != TransactionState::prepared &&
      journal->state != TransactionState::restaged &&
      journal->state != TransactionState::recovery_armed &&
      journal->state != TransactionState::commit_accepted) {
    std::wcerr << L"Mutation has started; cancellation is no longer allowed.\n";
    return 2;
  }
  journal->state = TransactionState::cancelled;
  journal->terminal_message = L"Cancelled before installer mutation.";
  if (!WriteJournalDurably(*journal, &error)) {
    LogError(error);
    std::wcerr << error << L'\n';
    return 1;
  }
  LogWarning(L"Transaction cancelled before installer launch.");
  std::wcout << L"cancelled\n";
  return 0;
}

int RunRecover(const std::wstring& transaction_id) {
  if (!IsCanonicalUuidV4(transaction_id)) {
    return 64;
  }
  std::wstring error;
  EndpointDescriptor descriptor;
  EndpointPolicy policy;
  auto journal = ReadJournal(&error);
  if (journal) {
    EnsureJournalHasUpdateLogPath(&*journal);
    StartUpdateLogSession(journal->update_log_path);
    LogInfo(std::wstring(L"Recover requested for transaction: ") +
            journal->bindings.transaction_id);
  }
  if (!journal || !LoadValidatedEndpoint(&descriptor, &policy, &error) ||
      !ValidateCurrentProtectedExecutable(
          descriptor, policy, GetCurrentExecutablePath(),
          ComputeFileSha256(GetCurrentExecutablePath()), false, transaction_id,
          &error) ||
      journal->bindings.transaction_id != transaction_id) {
    LogError(error);
    std::wcerr << error << L'\n';
    return 2;
  }

  // The protected helper may have been updated after the transaction was
  // prepared, so the journal's cached endpoint binding can be stale. The
  // current helper identity has already been proven against the registry
  // descriptor above, so rebind to the trusted endpoint and persist before
  // validating the transaction for replay.
  if (!ValidateJournalEndpoint(*journal, journal->bindings, &error)) {
    RefreshJournalEndpointBinding(&*journal, descriptor);
    if (!ValidateJournalEndpoint(*journal, journal->bindings, &error)) {
      LogError(error);
      std::wcerr << error << L'\n';
      return 2;
    }
    if (!WriteJournalDurably(*journal, &error)) {
      LogError(error);
      std::wcerr << error << L'\n';
      return 1;
    }
    LogInfo(L"Recovery rebound the transaction to the current trusted endpoint.");
  }
  if (IsTerminalState(journal->state)) {
    std::wcout << StateToString(journal->state) << L'\n';
    return 0;
  }
  if (journal->installer_started) {
    journal->state = TransactionState::manual_action_required;
    journal->terminal_message =
        L"Installer was previously started; automatic replay is forbidden.";
    WriteJournalDurably(*journal, &error);
    std::wcout << L"manualActionRequired\n";
    return 0;
  }
  if (journal->state == TransactionState::prepared) {
    StageVerification verification;
    if (!ValidateStage(journal->bindings, &verification, &error)) {
      LogError(error);
      std::wcerr << error << L'\n';
      return 2;
    }

    // Restage the verified installer before the recovery host takes ownership.
    if (!RestageInstaller(*journal, verification, &journal->restaged_installer_path,
                          &journal->restaged_installer_sha256, &error)) {
      return PersistFailure(*journal, error,
                            TransactionState::manual_action_required);
    }
    journal->state = TransactionState::restaged;
    if (!WriteJournalDurably(*journal, &error)) {
      return PersistFailure(*journal, error);
    }
  }
  // Only replay transactions that already own a verified restaged installer.
  if (!ValidateRestagedInstaller(*journal, &error)) {
    return PersistFailure(*journal, L"Restaged installer is missing or invalid.",
                          TransactionState::manual_action_required);
  }
  if (journal->state != TransactionState::restaged &&
      journal->state != TransactionState::recovery_armed &&
      journal->state != TransactionState::commit_accepted &&
      journal->state != TransactionState::waiting_for_exit) {
    std::wcerr << L"Transaction cannot be automatically replayed.\n";
    return 2;
  }

  // Mirror the commit path: when the scheduled recovery host cannot be
  // armed, fall back to running the provisioned recovery runtime copy
  // directly as a detached waiter instead of stranding the transaction in a
  // manual action state.
  std::filesystem::path recovery_runtime_path;
  if (!CreateRecoveryRuntimeCopy(journal->recovery_host_path,
                                 descriptor.recovery_host_sha256,
                                 journal->bindings.transaction_id,
                                 &recovery_runtime_path, &error)) {
    LogWarning(std::wstring(
                   L"Recovery host runtime copy could not be created (") +
               error + L").");
    return PersistFailure(*journal, error,
                          TransactionState::manual_action_required);
  }
  if (!ArmRecoveryHostTask(recovery_runtime_path, journal->bindings.transaction_id,
                           &journal->recovery_task_name, &error)) {
    LogWarning(std::wstring(L"Recovery host task could not be armed (") +
               error + L"); using direct recovery waiter fallback.");
    return RecoverWithDirectWaiterFallback(&*journal, recovery_runtime_path,
                                           &error);
  }
  // Mark the journal after the recovery host task is durably armed.
  journal->recovery_armed = true;
  journal->state = TransactionState::recovery_armed;
  if (!WriteJournalDurably(*journal, &error)) {
    return PersistFailure(*journal, error);
  }
  LogInfo(L"Recovery accepted and recovery host replay requested.");
  std::wcout << L"recoveryArmed\n";
  return 0;
}

int RunWorker(const RequestBindings& bindings) {
  std::wstring error;
  auto journal = ReadJournal(&error);
  if (journal) {
    EnsureJournalHasUpdateLogPath(&*journal);
    StartUpdateLogSession(journal->update_log_path);
    LogInfo(std::wstring(L"Worker started for transaction: ") +
            journal->bindings.transaction_id);
  }
  if (!journal || !ValidateJournalEndpoint(*journal, bindings, &error)) {
    LogError(error);
    std::wcerr << error << L'\n';
    return 2;
  }
  if (journal->installer_started) {
    return PersistFailure(*journal,
                          L"At-most-once installer launch prevented replay.",
                          TransactionState::manual_action_required);
  }
  if (journal->state != TransactionState::commit_accepted &&
      journal->state != TransactionState::waiting_for_exit) {
    std::wcerr << L"Worker was invoked from an invalid state.\n";
    return 2;
  }
  journal->state = TransactionState::waiting_for_exit;
  if (!WriteJournalDurably(*journal, &error)) {
    return PersistFailure(*journal, error);
  }
  LogInfo(L"Waiting for caller process to exit before installing.");

  ScopedHandle caller(OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION,
                                  FALSE, bindings.caller_process_id));
  if (caller.valid()) {
    std::wstring process_path(32768, L'\0');
    DWORD process_path_length = static_cast<DWORD>(process_path.size());
    if (!QueryFullProcessImageNameW(caller.value, 0, process_path.data(),
                                    &process_path_length)) {
      return PersistFailure(*journal,
                            L"Caller process identity could not be read.");
    }
    process_path.resize(process_path_length);
    if (!PathsEqual(process_path, bindings.caller_executable)) {
      return PersistFailure(*journal,
                            L"Caller PID was reused by another executable.");
    }
    if (WaitForSingleObject(caller.value, INFINITE) != WAIT_OBJECT_0) {
      return PersistFailure(*journal, L"Caller exit could not be observed.");
    }
  }
  LogInfo(L"Caller process has exited; continuing installation.");

  StageVerification verification;
  if (!ValidateStage(bindings, &verification, &error)) {
    return PersistFailure(*journal, error);
  }

  // Require the restaged installer even on the fallback path so mutation
  // never depends on the original stage executable again.
  if (!ValidateRestagedInstaller(*journal, &error)) {
    return PersistFailure(*journal, error,
                          TransactionState::manual_action_required);
  }

  // Persist the launch guard before starting the external mutation.
  journal->state = TransactionState::manager_started;
  journal->installer_started = true;
  if (!WriteJournalDurably(*journal, &error)) {
    return PersistFailure(*journal, error);
  }
  ProcessLaunchPolicy policy;
  policy.installer_path = journal->restaged_installer_path;
  policy.install_root = GetInstallRootForExecutable(bindings.caller_executable);
  policy.log_path = journal->update_log_path;
  DWORD exit_code = 0;
  if (!StartInstallerAndWait(policy, &exit_code, &error)) {
    return PersistFailure(*journal, error);
  }
  journal->installer_exit_code = exit_code;
  if (exit_code != 0) {
    return PersistFailure(*journal,
                          L"Installer returned a non-zero exit code.");
  }
  LogInfo(L"Installer finished successfully. Verifying installed application.");
  journal->state = TransactionState::verification_pending;
  if (!WriteJournalDurably(*journal, &error)) {
    return PersistFailure(*journal, error);
  }
  const auto installed_executable =
      GetInstallRootForExecutable(bindings.caller_executable) /
      kInstalledExecutableName;
  if (!IsSafeRegularFile(installed_executable) ||
      !ValidateInstalledExecutableImpl(installed_executable, verification,
                                      &error)) {
    return PersistFailure(*journal, L"Installed application identity is invalid.",
                          TransactionState::manual_action_required);
  }
  if (!RelaunchInstalledApplication(&*journal, &error)) {
    return PersistFailure(*journal, error,
                          TransactionState::manual_action_required);
  }
  LogInfo(L"Installed application relaunch requested successfully.");
  return 0;
}

}  // namespace flynarwhal::install_helper

#include "flynarwhal_install_helper.h"

#include <bcrypt.h>
#include <shellapi.h>
#include <shlobj.h>
#include <winver.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cwctype>
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
constexpr DWORD kInstallerTimeoutMilliseconds = 20U * 60U * 1000U;

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
  output << "{\"schemaVersion\":" << journal.schema_version
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
         << "\",\"helperSha256\":\"" << EscapeJson(journal.helper_sha256)
         << "\",\"installerStarted\":"
         << (journal.installer_started ? "true" : "false")
         << ",\"relaunchAttempted\":"
         << (journal.relaunch_attempted ? "true" : "false")
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
  const auto helper_sha = ExtractJsonString(json, L"helperSha256");
  const auto exit_code = ExtractJsonUnsigned(json, L"installerExitCode");
  const auto terminal_message = ExtractJsonString(json, L"terminalMessage");
  bool installer_started = false;
  bool relaunch_attempted = false;
  const auto state = state_value ? StateFromString(*state_value) : std::nullopt;
  if (!schema || *schema != 1 || !transaction || !stage || !provenance ||
      !artifact || !artifact_length || *artifact_length == 0 || !process_id ||
      *process_id > MAXDWORD || !caller || !state ||
      !helper_path || !helper_sha || !exit_code || *exit_code > MAXDWORD ||
      !terminal_message ||
      !ExtractJsonBoolean(json, L"installerStarted", &installer_started) ||
      !ExtractJsonBoolean(json, L"relaunchAttempted", &relaunch_attempted)) {
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
  journal.helper_sha256 = *helper_sha;
  journal.installer_started = installer_started;
  journal.relaunch_attempted = relaunch_attempted;
  journal.installer_exit_code = static_cast<DWORD>(*exit_code);
  journal.terminal_message = *terminal_message;
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

bool ValidateJournalEndpoint(const Journal& journal,
                             const RequestBindings& bindings,
                             std::wstring* error_message) {
  const auto helper_path = GetCurrentExecutablePath();
  const auto helper_sha = ComputeFileSha256(helper_path);
  if (!BindingsEqual(journal.bindings, bindings) ||
      !PathsEqual(journal.helper_executable, helper_path) ||
      journal.helper_sha256 != helper_sha) {
    *error_message = L"Transaction endpoint binding does not match.";
    return false;
  }
  return true;
}

std::wstring BuildWorkerCommandLine(const RequestBindings& bindings) {
  std::vector<std::wstring> values = {
      GetCurrentExecutablePath().wstring(),
      L"worker",
      L"--transaction-id",
      bindings.transaction_id,
      L"--stage",
      bindings.stage_path.wstring(),
      L"--provenance-sha256",
      bindings.stage_provenance_sha256,
      L"--artifact-sha256",
      bindings.expected_artifact_sha256,
      L"--artifact-length",
      std::to_wstring(bindings.expected_artifact_length),
      L"--caller-pid",
      std::to_wstring(bindings.caller_process_id),
      L"--caller-executable",
      bindings.caller_executable.wstring(),
  };
  std::wstring command_line;
  for (const auto& value : values) {
    if (!command_line.empty()) {
      command_line += L' ';
    }
    command_line += QuoteWindowsArgument(value);
  }
  return command_line;
}

bool StartDetachedWorker(const RequestBindings& bindings,
                         std::wstring* error_message) {
  std::wstring command_line = BuildWorkerCommandLine(bindings);
  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_information{};
  if (!CreateProcessW(GetCurrentExecutablePath().c_str(), command_line.data(),
                      nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW | DETACHED_PROCESS, nullptr, nullptr,
                      &startup_info, &process_information)) {
    *error_message = L"Unable to start the transaction worker.";
    return false;
  }
  CloseHandle(process_information.hThread);
  CloseHandle(process_information.hProcess);
  return true;
}

bool StartInstallerAndWait(const ProcessLaunchPolicy& policy,
                           DWORD* exit_code,
                           std::wstring* error_message) {
  std::wstring command_line = QuoteWindowsArgument(policy.installer_path.wstring());
  for (const auto& argument : BuildFixedInstallerArguments(policy)) {
    command_line += L' ';
    command_line += QuoteWindowsArgument(argument);
  }
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
    *error_message = L"Installer exceeded the fixed 20 minute timeout.";
    return false;
  }
  if (wait_result != WAIT_OBJECT_0 ||
      !GetExitCodeProcess(process.value, exit_code)) {
    *error_message = L"Installer completion could not be observed.";
    return false;
  }
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
  const auto executable = GetFixedInstallRoot() / kInstalledExecutableName;
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

bool ValidateInstalledExecutable(const std::filesystem::path& executable,
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
                   TransactionState state = TransactionState::failed) {
  journal.state = state;
  journal.terminal_message = message;
  std::wstring ignored;
  WriteJournalDurably(journal, &ignored);
  std::wcerr << message << L'\n';
  return 1;
}

}  // namespace

std::wstring StateToString(TransactionState state) {
  switch (state) {
    case TransactionState::prepared:
      return L"prepared";
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
  const std::array<std::pair<const wchar_t*, TransactionState>, 9> states = {{
      {L"prepared", TransactionState::prepared},
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

std::filesystem::path GetFixedInstallRoot() {
  return GetLocalAppDataPath() / L"FlyNarwhal";
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
#if defined(FLYNARWHAL_NATIVE_HELPER_DEVELOPMENT_BUILD)
  const bool caller_location_is_allowed =
      PathsEqual(bindings.caller_executable.parent_path(),
                 GetCurrentExecutablePath().parent_path());
#else
  const bool caller_location_is_allowed =
      PathsEqual(bindings.caller_executable.parent_path(),
                 GetFixedInstallRoot());
#endif
  if (!caller_location_is_allowed) {
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
  if (!ValidateCallerIdentity(bindings) ||
      !ValidateStage(bindings, &verification, &error)) {
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
  const auto helper_sha256 = ComputeFileSha256(journal.helper_executable);
  if (!IsLowercaseSha256(helper_sha256)) {
    std::wcerr << L"Helper SHA-256 could not be computed.\n";
    return 2;
  }
  journal.helper_sha256 = helper_sha256;
  if (!WriteJournalDurably(journal, &error)) {
    std::wcerr << error << L'\n';
    return 1;
  }
  std::wcout << L"prepared\n";
  return 0;
}

int RunCommit(const RequestBindings& bindings) {
  std::wstring error;
  auto journal = ReadJournal(&error);
  if (!journal || !ValidateJournalEndpoint(*journal, bindings, &error) ||
      !ValidateCallerIdentity(bindings)) {
    std::wcerr << (error.empty() ? L"Caller identity is invalid." : error)
               << L'\n';
    return 2;
  }
  if (journal->state == TransactionState::commit_accepted ||
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
    std::wcerr << error << L'\n';
    return 2;
  }
  journal->state = TransactionState::commit_accepted;
  if (!WriteJournalDurably(*journal, &error) ||
      !StartDetachedWorker(bindings, &error)) {
    return PersistFailure(*journal, error);
  }
  std::wcout << L"commitAccepted\n";
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
  std::wcout << StateToString(journal->state) << L'\n';
  return 0;
}

int RunCancel(const std::wstring& transaction_id) {
  if (!IsCanonicalUuidV4(transaction_id)) {
    return 64;
  }
  std::wstring error;
  auto journal = ReadJournal(&error);
  if (!journal || journal->bindings.transaction_id != transaction_id ||
      !ValidateJournalEndpoint(*journal, journal->bindings, &error)) {
    std::wcerr << error << L'\n';
    return 2;
  }
  if (journal->state != TransactionState::prepared &&
      journal->state != TransactionState::commit_accepted) {
    std::wcerr << L"Mutation has started; cancellation is no longer allowed.\n";
    return 2;
  }
  journal->state = TransactionState::cancelled;
  journal->terminal_message = L"Cancelled before installer mutation.";
  if (!WriteJournalDurably(*journal, &error)) {
    std::wcerr << error << L'\n';
    return 1;
  }
  std::wcout << L"cancelled\n";
  return 0;
}

int RunRecover(const std::wstring& transaction_id) {
  if (!IsCanonicalUuidV4(transaction_id)) {
    return 64;
  }
  std::wstring error;
  auto journal = ReadJournal(&error);
  if (!journal || journal->bindings.transaction_id != transaction_id ||
      !ValidateJournalEndpoint(*journal, journal->bindings, &error)) {
    std::wcerr << error << L'\n';
    return 2;
  }
  if (IsTerminalState(journal->state)) {
    std::wcout << StateToString(journal->state) << L'\n';
    return 0;
  }
  StageVerification verification;
  if (!ValidateStage(journal->bindings, &verification, &error)) {
    std::wcerr << error << L'\n';
    return 2;
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
    journal->state = TransactionState::commit_accepted;
    if (!WriteJournalDurably(*journal, &error)) {
      return PersistFailure(*journal, error);
    }
  }
  if (journal->state != TransactionState::commit_accepted &&
      journal->state != TransactionState::waiting_for_exit) {
    std::wcerr << L"Transaction cannot be automatically replayed.\n";
    return 2;
  }
  // Resume exclusively with the caller and stage bindings sealed in journal.
  if (!StartDetachedWorker(journal->bindings, &error)) {
    return PersistFailure(*journal, error);
  }
  std::wcout << L"recoveryAccepted\n";
  return 0;
}

int RunWorker(const RequestBindings& bindings) {
  std::wstring error;
  auto journal = ReadJournal(&error);
  if (!journal || !ValidateJournalEndpoint(*journal, bindings, &error)) {
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

  StageVerification verification;
  if (!ValidateStage(bindings, &verification, &error)) {
    return PersistFailure(*journal, error);
  }

  // Persist the launch guard before starting the external mutation.
  journal->state = TransactionState::manager_started;
  journal->installer_started = true;
  if (!WriteJournalDurably(*journal, &error)) {
    return PersistFailure(*journal, error);
  }
  ProcessLaunchPolicy policy;
  policy.installer_path = verification.installer_path;
  policy.install_root = GetFixedInstallRoot();
  policy.log_path = GetLocalAppDataPath() / L"Temp" /
                    (L"FlyNarwhal-install-" + bindings.transaction_id + L".log");
  DWORD exit_code = 0;
  if (!StartInstallerAndWait(policy, &exit_code, &error)) {
    return PersistFailure(*journal, error);
  }
  journal->installer_exit_code = exit_code;
  if (exit_code != 0) {
    return PersistFailure(*journal,
                          L"Installer returned a non-zero exit code.");
  }
  journal->state = TransactionState::verification_pending;
  if (!WriteJournalDurably(*journal, &error)) {
    return PersistFailure(*journal, error);
  }
  const auto installed_executable = GetFixedInstallRoot() / kInstalledExecutableName;
  if (!IsSafeRegularFile(installed_executable) ||
      !ValidateInstalledExecutable(installed_executable, verification, &error)) {
    return PersistFailure(*journal, L"Installed application identity is invalid.",
                          TransactionState::manual_action_required);
  }
  if (!RelaunchInstalledApplication(&*journal, &error)) {
    return PersistFailure(*journal, error,
                          TransactionState::manual_action_required);
  }
  return 0;
}

}  // namespace flynarwhal::install_helper

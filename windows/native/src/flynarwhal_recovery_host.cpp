#include "flynarwhal_recovery_host.h"

#include "flynarwhal_install_helper.h"
#include "flynarwhal_updater_endpoint.h"

#include <Windows.h>

#include <shellapi.h>

#include <array>
#include <cwchar>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

namespace flynarwhal::install_helper {
namespace {

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

bool IsSafeRegularFileLocal(const std::filesystem::path& path) {
  if (HasReparsePointInExistingPath(path)) {
    return false;
  }
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0 &&
         (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0;
}

std::wstring TrimWhitespace(const std::wstring& value) {
  const std::size_t begin = value.find_first_not_of(L" \t\r\n");
  if (begin == std::wstring::npos) {
    return {};
  }
  const std::size_t end = value.find_last_not_of(L" \t\r\n");
  return value.substr(begin, end - begin + 1);
}

bool RunCommandAndWait(const std::wstring& executable,
                       const std::vector<std::wstring>& arguments,
                       DWORD* exit_code,
                       std::wstring* error_message,
                       std::wstring* command_output = nullptr) {
  std::wstring command_line = QuoteWindowsArgument(executable);
  for (const auto& argument : arguments) {
    command_line += L' ';
    command_line += QuoteWindowsArgument(argument);
  }
  // Capture child output when requested so failures are diagnosable.
  HANDLE read_handle = nullptr;
  HANDLE write_handle = nullptr;
  bool capture = command_output != nullptr;
  SECURITY_ATTRIBUTES attributes{};
  attributes.nLength = sizeof(attributes);
  attributes.bInheritHandle = TRUE;
  if (capture && !CreatePipe(&read_handle, &write_handle, &attributes, 0)) {
    capture = false;
  }
  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  if (capture) {
    SetHandleInformation(read_handle, HANDLE_FLAG_INHERIT, 0);
    startup_info.dwFlags = STARTF_USESTDHANDLES;
    startup_info.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    startup_info.hStdOutput = write_handle;
    startup_info.hStdError = write_handle;
  }
  PROCESS_INFORMATION process_information{};
  if (!CreateProcessW(executable.c_str(), command_line.data(), nullptr, nullptr,
                      capture ? TRUE : FALSE, CREATE_NO_WINDOW, nullptr,
                      nullptr, &startup_info, &process_information)) {
    if (read_handle != nullptr) {
      CloseHandle(read_handle);
    }
    if (write_handle != nullptr) {
      CloseHandle(write_handle);
    }
    *error_message = L"Recovery host command could not be started.";
    return false;
  }
  // Close the inherited write end so reads reach EOF when the child exits.
  if (write_handle != nullptr) {
    CloseHandle(write_handle);
  }
  ScopedHandle process(process_information.hProcess);
  CloseHandle(process_information.hThread);
  if (capture) {
    std::string raw_output;
    char buffer[4096];
    DWORD bytes_read = 0;
    while (ReadFile(read_handle, buffer, sizeof(buffer), &bytes_read,
                    nullptr) &&
           bytes_read > 0) {
      raw_output.append(buffer, bytes_read);
    }
    CloseHandle(read_handle);
    // Console tools emit text in the ANSI console code page.
    const int wide_length = MultiByteToWideChar(
        CP_ACP, 0, raw_output.data(),
        static_cast<int>(raw_output.size()), nullptr, 0);
    if (wide_length > 0) {
      command_output->assign(static_cast<std::size_t>(wide_length), L'\0');
      MultiByteToWideChar(CP_ACP, 0, raw_output.data(),
                          static_cast<int>(raw_output.size()),
                          command_output->data(), wide_length);
      *command_output = TrimWhitespace(*command_output);
    }
  }
  if (WaitForSingleObject(process.value, INFINITE) != WAIT_OBJECT_0 ||
      !GetExitCodeProcess(process.value, exit_code)) {
    *error_message = L"Recovery host command completion could not be observed.";
    return false;
  }
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

bool RelaunchInstalledApplication(const std::filesystem::path& install_root,
                                  std::wstring* error_message) {
  const auto executable = install_root / L"FlyNarwhal.exe";
  if (!IsSafeRegularFileLocal(executable)) {
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

bool PersistFailure(Journal* journal,
                    const std::wstring& message,
                    TransactionState state) {
  if (journal == nullptr) {
    return false;
  }
  LogError(std::wstring(L"Recovery host failed: ") + message);
  std::wstring ignored;
  journal->state = state;
  journal->terminal_message = message;
  return WriteJournalDurably(*journal, &ignored);
}

}  // namespace

std::wstring BuildRecoveryTaskName(const std::wstring& transaction_id) {
  return L"FlyNarwhal.UpdateRecovery." + transaction_id;
}

bool CreateRecoveryRuntimeCopy(const std::filesystem::path& source_path,
                               const std::wstring& expected_sha256,
                               const std::wstring& transaction_id,
                               std::filesystem::path* runtime_path,
                               std::wstring* error_message) {
  const auto runtime_root = GetRecoveryRuntimeRoot();
  std::error_code directory_error;
  std::filesystem::create_directories(runtime_root, directory_error);
  if (directory_error || HasReparsePointInExistingPath(runtime_root)) {
    *error_message = L"Recovery runtime directory is unsafe.";
    return false;
  }
  const auto transaction_runtime = runtime_root / transaction_id;
  std::filesystem::create_directories(transaction_runtime, directory_error);
  if (directory_error || HasReparsePointInExistingPath(transaction_runtime)) {
    *error_message = L"Recovery runtime path is unsafe.";
    return false;
  }
  const auto target_path = transaction_runtime / L"FlyNarwhalRecoveryHost.exe";
  std::filesystem::copy_file(source_path, target_path,
                             std::filesystem::copy_options::overwrite_existing,
                             directory_error);
  if (directory_error || !IsSafeRegularFileLocal(target_path) ||
      ComputeFileSha256(target_path) != expected_sha256) {
    *error_message = L"Recovery runtime copy could not be created.";
    return false;
  }
  *runtime_path = target_path;
  return true;
}

// schtasks /SD expects the date in the user's locale short-date format. A
// hardcoded MM/DD/YYYY fails on non-US systems (e.g. zh-CN expects
// yyyy/M/d), so build the value from the locale pattern instead.
std::wstring BuildLocaleShortDate(const SYSTEMTIME& local_time) {
  wchar_t year_buffer[8]{};
  wchar_t month_buffer[8]{};
  wchar_t day_buffer[8]{};
  swprintf_s(year_buffer, L"%04u", local_time.wYear);
  swprintf_s(month_buffer, L"%02u", local_time.wMonth);
  swprintf_s(day_buffer, L"%02u", local_time.wDay);

  wchar_t pattern_buffer[80]{};
  const int pattern_length =
      GetLocaleInfoEx(LOCALE_NAME_USER_DEFAULT, LOCALE_SSHORTDATE,
                      pattern_buffer,
                      static_cast<int>(std::size(pattern_buffer)));
  const std::wstring pattern(pattern_buffer,
                             pattern_length > 0 ? pattern_length - 1 : 0);

  std::wstring result;
  bool has_year = false;
  bool has_month = false;
  bool has_day = false;
  for (std::size_t index = 0; index < pattern.size();) {
    const wchar_t token = pattern[index];
    if (token == L'y' || token == L'Y') {
      result += year_buffer;
      has_year = true;
    } else if (token == L'M') {
      result += month_buffer;
      has_month = true;
    } else if (token == L'd' || token == L'D') {
      result += day_buffer;
      has_day = true;
    } else {
      result += token;
      ++index;
      continue;
    }
    while (index < pattern.size() &&
           (pattern[index] == token ||
            (token == L'y' && pattern[index] == L'Y') ||
            (token == L'Y' && pattern[index] == L'y') ||
            (token == L'd' && pattern[index] == L'D') ||
            (token == L'D' && pattern[index] == L'd'))) {
      ++index;
    }
  }
  if (!has_year || !has_month || !has_day || result.empty()) {
    // Conservative fallback accepted by most locale configurations.
    return std::wstring(year_buffer) + L"/" + month_buffer + L"/" +
           day_buffer;
  }
  return result;
}

bool ArmRecoveryHostTask(const std::filesystem::path& runtime_path,
                         const std::wstring& transaction_id,
                         std::wstring* task_name,
                         std::wstring* error_message) {
  if (task_name == nullptr) {
    *error_message = L"Recovery task output target is invalid.";
    return false;
  }
  *task_name = BuildRecoveryTaskName(transaction_id);
  DeleteRecoveryHostTask(*task_name);

  SYSTEMTIME local_time{};
  GetLocalTime(&local_time);
  local_time.wMinute =
      static_cast<WORD>((local_time.wMinute + 1) % 60);
  if (local_time.wMinute == 0) {
    local_time.wHour = static_cast<WORD>((local_time.wHour + 1) % 24);
  }
  wchar_t time_buffer[6]{};
  swprintf_s(time_buffer, L"%02u:%02u", local_time.wHour, local_time.wMinute);
  const std::wstring date_value = BuildLocaleShortDate(local_time);

  const std::wstring task_command =
      QuoteWindowsArgument(runtime_path.wstring()) + L" resume --transaction-id " +
      QuoteWindowsArgument(transaction_id);
  LogInfo(std::wstring(L"Creating recovery host task ") + *task_name +
          L" (start " + time_buffer + L" on " + date_value + L").");
  DWORD exit_code = 0;
  std::wstring command_output;
  if (!RunCommandAndWait(L"C:\\Windows\\System32\\schtasks.exe",
                         {L"/Create", L"/TN", *task_name, L"/TR", task_command,
                          L"/SC", L"ONCE", L"/ST", time_buffer, L"/SD",
                          date_value, L"/F"},
                         &exit_code, error_message, &command_output) ||
      exit_code != 0) {
    *error_message = L"Recovery host task could not be created.";
    LogWarning(std::wstring(L"schtasks /Create failed with exit code ") +
               std::to_wstring(exit_code) +
               (command_output.empty() ? L"." : L": " + command_output));
    return false;
  }
  if (!RunCommandAndWait(L"C:\\Windows\\System32\\schtasks.exe",
                         {L"/Run", L"/TN", *task_name}, &exit_code,
                         error_message, &command_output) ||
      exit_code != 0) {
    *error_message = L"Recovery host task could not be started.";
    LogWarning(std::wstring(L"schtasks /Run failed with exit code ") +
               std::to_wstring(exit_code) +
               (command_output.empty() ? L"." : L": " + command_output));
    return false;
  }
  LogInfo(L"Recovery host task created and started.");
  return true;
}

void DeleteRecoveryHostTask(const std::wstring& task_name) {
  if (task_name.empty()) {
    return;
  }
  DWORD exit_code = 0;
  std::wstring ignored;
  RunCommandAndWait(L"C:\\Windows\\System32\\schtasks.exe",
                    {L"/Delete", L"/TN", task_name, L"/F"}, &exit_code,
                    &ignored);
}

int RunRecoveryHostResume(const std::wstring& transaction_id) {
  if (!IsCanonicalUuidV4(transaction_id)) {
    return 64;
  }
  std::wstring error;
  auto journal = ReadJournal(&error);
  if (!journal || journal->bindings.transaction_id != transaction_id) {
    std::wcerr << (error.empty() ? L"No active transaction exists." : error)
               << L'\n';
    return 2;
  }
  // Attach the durable update log before doing anything else so every
  // recovery host step is visible in release builds.
  const bool log_path_added = journal->update_log_path.empty();
  EnsureJournalHasUpdateLogPath(&*journal);
  StartUpdateLogSession(journal->update_log_path);
  if (log_path_added) {
    std::wstring ignored;
    WriteJournalDurably(*journal, &ignored);
  }
  LogInfo(std::wstring(L"Recovery host resuming transaction ") +
          transaction_id + L" in state " +
          StateToString(journal->state) + L".");
  EndpointDescriptor descriptor;
  EndpointPolicy policy;
  if (!ReadRegisteredEndpoint(&descriptor, &error) ||
      !ReadEndpointPolicy(descriptor.policy_path, &policy, &error) ||
      !ValidateCurrentProtectedExecutable(
          descriptor, policy, GetCurrentExecutablePath(),
          ComputeFileSha256(GetCurrentExecutablePath()), true, transaction_id,
          &error)) {
    PersistFailure(&*journal, error.empty() ? L"Recovery host identity is invalid."
                                            : error,
                   TransactionState::manual_action_required);
    std::wcerr << (error.empty() ? L"Recovery host identity is invalid." : error)
               << L'\n';
    return 2;
  }
  if (IsTerminalState(journal->state)) {
    std::wcout << StateToString(journal->state) << L'\n';
    return 0;
  }
  if (journal->state != TransactionState::recovery_armed &&
      journal->state != TransactionState::commit_accepted &&
      journal->state != TransactionState::waiting_for_exit) {
    std::wcerr << L"Recovery host was invoked from an invalid state.\n";
    return 2;
  }

  journal->state = TransactionState::waiting_for_exit;
  if (!WriteJournalDurably(*journal, &error)) {
    std::wcerr << error << L'\n';
    return 1;
  }

  ScopedHandle caller(OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION,
                                  FALSE, journal->bindings.caller_process_id));
  if (caller.valid()) {
    std::wstring process_path(32768, L'\0');
    DWORD process_path_length = static_cast<DWORD>(process_path.size());
    if (!QueryFullProcessImageNameW(caller.value, 0, process_path.data(),
                                    &process_path_length)) {
      PersistFailure(&*journal, L"Caller process identity could not be read.",
                     TransactionState::failed);
      return 1;
    }
    process_path.resize(process_path_length);
    std::error_code path_error;
    const auto normalized_process_path =
        std::filesystem::weakly_canonical(process_path, path_error);
    const auto normalized_caller =
        std::filesystem::weakly_canonical(journal->bindings.caller_executable,
                                          path_error);
    if (path_error || normalized_process_path != normalized_caller) {
      PersistFailure(&*journal, L"Caller PID was reused by another executable.",
                     TransactionState::failed);
      return 1;
    }
    if (WaitForSingleObject(caller.value, INFINITE) != WAIT_OBJECT_0) {
      PersistFailure(&*journal, L"Caller exit could not be observed.",
                     TransactionState::failed);
      return 1;
    }
  }
  LogInfo(L"Caller process has exited; continuing installation.");

  StageVerification verification;
  if (!ValidateStage(journal->bindings, &verification, &error)) {
    PersistFailure(&*journal, error, TransactionState::failed);
    std::wcerr << error << L'\n';
    return 1;
  }
  if (!IsSafeRegularFileLocal(journal->restaged_installer_path) ||
      ComputeFileSha256(journal->restaged_installer_path) !=
          journal->restaged_installer_sha256) {
    PersistFailure(&*journal, L"Restaged installer is missing or invalid.",
                   TransactionState::manual_action_required);
    std::wcerr << L"Restaged installer is missing or invalid.\n";
    return 1;
  }

  journal->state = TransactionState::manager_started;
  journal->installer_started = true;
  if (!WriteJournalDurably(*journal, &error)) {
    std::wcerr << error << L'\n';
    return 1;
  }

  ProcessLaunchPolicy policy_to_launch;
  policy_to_launch.installer_path = journal->restaged_installer_path;
  policy_to_launch.install_root =
      GetInstallRootForExecutable(journal->bindings.caller_executable);
  policy_to_launch.log_path = journal->update_log_path;
  DWORD exit_code = 0;
  if (!StartInstallerAndWait(policy_to_launch, &exit_code, &error)) {
    PersistFailure(&*journal, error, TransactionState::failed);
    std::wcerr << error << L'\n';
    return 1;
  }

  journal->installer_exit_code = exit_code;
  LogInfo(std::wstring(L"Installer process exited with code: ") +
          std::to_wstring(exit_code));
  if (exit_code != 0) {
    PersistFailure(&*journal, L"Installer returned a non-zero exit code.",
                   TransactionState::failed);
    std::wcerr << L"Installer returned a non-zero exit code.\n";
    return 1;
  }

  LogInfo(L"Installer finished successfully. Verifying installed application.");
  journal->state = TransactionState::verification_pending;
  if (!WriteJournalDurably(*journal, &error)) {
    std::wcerr << error << L'\n';
    return 1;
  }

  const auto installed_executable =
      GetInstallRootForExecutable(journal->bindings.caller_executable) /
      L"FlyNarwhal.exe";
  // Reuse the shared post-install verification contract before relaunching.
  if (!IsSafeRegularFileLocal(installed_executable) ||
      !ValidateInstalledExecutable(installed_executable, verification,
                                   &error)) {
    PersistFailure(&*journal, L"Installed application identity is invalid.",
                   TransactionState::manual_action_required);
    std::wcerr << L"Installed application identity is invalid.\n";
    return 1;
  }
  if (!RelaunchInstalledApplication(
          GetInstallRootForExecutable(journal->bindings.caller_executable),
          &error)) {
    PersistFailure(&*journal, error, TransactionState::manual_action_required);
    std::wcerr << error << L'\n';
    return 1;
  }
  LogInfo(L"Installed application relaunch requested successfully.");

  journal->relaunch_attempted = true;
  journal->state = TransactionState::completed;
  journal->terminal_message =
      L"Installation completed; recovery host requested relaunch.";
  if (!WriteJournalDurably(*journal, &error)) {
    std::wcerr << error << L'\n';
    return 1;
  }
  DeleteRecoveryHostTask(journal->recovery_task_name);
  std::wcout << L"completed\n";
  return 0;
}

}  // namespace flynarwhal::install_helper

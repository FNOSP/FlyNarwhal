#include "flynarwhal_recovery_host.h"

#include "flynarwhal_install_helper.h"
#include "flynarwhal_updater_endpoint.h"

#include <Windows.h>

#include <objbase.h>
#include <shellapi.h>
#include <taskschd.h>

#include <array>
#include <cwchar>
#include <filesystem>
#include <iostream>
#include <string>

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

struct ComScope {
  bool active = false;

  ComScope() {
    active = SUCCEEDED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED));
  }
  ComScope(const ComScope&) = delete;
  ComScope& operator=(const ComScope&) = delete;
  ~ComScope() {
    if (active) {
      CoUninitialize();
    }
  }
};

template <typename Interface>
struct ComPtr {
  Interface* value = nullptr;

  ComPtr() = default;
  ComPtr(const ComPtr&) = delete;
  ComPtr& operator=(const ComPtr&) = delete;
  ~ComPtr() {
    if (value != nullptr) {
      value->Release();
    }
  }

  Interface** receive() { return &value; }
  Interface* operator->() const { return value; }
};

struct ScopedBstr {
  BSTR value = nullptr;

  explicit ScopedBstr(const wchar_t* text) { value = SysAllocString(text); }
  ScopedBstr(const ScopedBstr&) = delete;
  ScopedBstr& operator=(const ScopedBstr&) = delete;
  ~ScopedBstr() {
    if (value != nullptr) {
      SysFreeString(value);
    }
  }

  bool valid() const { return value != nullptr; }
};

// Task Scheduler time triggers expect an ISO 8601 local timestamp with an
// explicit UTC offset, so build the value from the local time and the
// resolved time zone difference instead of relying on a locale date format.
std::wstring BuildTaskStartBoundary(const SYSTEMTIME& local_time) {
  LONG offset_minutes = 0;
  SYSTEMTIME utc_time{};
  if (TzSpecificLocalTimeToSystemTime(nullptr, &local_time, &utc_time)) {
    FILETIME local_file_time{};
    FILETIME utc_file_time{};
    if (SystemTimeToFileTime(&local_time, &local_file_time) &&
        SystemTimeToFileTime(&utc_time, &utc_file_time)) {
      ULARGE_INTEGER local_value{};
      ULARGE_INTEGER utc_value{};
      local_value.HighPart = local_file_time.dwHighDateTime;
      local_value.LowPart = local_file_time.dwLowDateTime;
      utc_value.HighPart = utc_file_time.dwHighDateTime;
      utc_value.LowPart = utc_file_time.dwLowDateTime;
      offset_minutes = static_cast<LONG>(
          (static_cast<long long>(local_value.QuadPart) -
           static_cast<long long>(utc_value.QuadPart)) /
          (10000000LL * 60LL));
    }
  }
  const wchar_t sign = offset_minutes < 0 ? L'-' : L'+';
  const unsigned long magnitude = static_cast<unsigned long>(
      offset_minutes < 0 ? -offset_minutes : offset_minutes);
  wchar_t buffer[40]{};
  swprintf_s(buffer, L"%04u-%02u-%02uT%02u:%02u:%02u%c%02lu:%02lu",
             local_time.wYear, local_time.wMonth, local_time.wDay,
             local_time.wHour, local_time.wMinute, local_time.wSecond, sign,
             magnitude / 60UL, magnitude % 60UL);
  return buffer;
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

// Creates and starts the one-shot recovery task through the Task Scheduler
// COM API. The schtasks.exe command-line route is deliberately avoided
// because spawning the scheduler CLI is a common persistence pattern that
// security products flag heuristically.
bool ArmRecoveryHostTask(const std::filesystem::path& runtime_path,
                         const std::wstring& transaction_id,
                         std::wstring* task_name,
                         std::wstring* error_message) {
  if (task_name == nullptr) {
    *error_message = L"Recovery task output target is invalid.";
    return false;
  }
  *task_name = BuildRecoveryTaskName(transaction_id);

  SYSTEMTIME local_time{};
  GetLocalTime(&local_time);
  local_time.wMinute = static_cast<WORD>((local_time.wMinute + 1) % 60);
  if (local_time.wMinute == 0) {
    local_time.wHour = static_cast<WORD>((local_time.wHour + 1) % 24);
  }
  const std::wstring boundary = BuildTaskStartBoundary(local_time);
  const std::wstring task_arguments =
      L"resume --transaction-id " + QuoteWindowsArgument(transaction_id);
  LogInfo(std::wstring(L"Creating recovery host task ") + *task_name +
          L" (boundary " + boundary + L").");

  ComScope com_scope;
  ComPtr<ITaskService> service;
  HRESULT result = CoCreateInstance(CLSID_TaskScheduler, nullptr,
                                    CLSCTX_INPROC_SERVER, IID_ITaskService,
                                    reinterpret_cast<void**>(service.receive()));
  VARIANT empty{};
  VariantInit(&empty);
  if (FAILED(result)) {
    LogWarning(std::wstring(L"Task Scheduler could not be instantiated; HRESULT ") +
               std::to_wstring(static_cast<unsigned long>(result)));
    *error_message = L"Recovery host task could not be created.";
    return false;
  }
  result = service->Connect(empty, empty, empty, empty);
  if (FAILED(result)) {
    LogWarning(std::wstring(L"Task Scheduler connection failed; HRESULT ") +
               std::to_wstring(static_cast<unsigned long>(result)));
    *error_message = L"Recovery host task could not be created.";
    return false;
  }
  ScopedBstr root_path(L"\\");
  ComPtr<ITaskFolder> root;
  if (!root_path.valid() ||
      FAILED(service->GetFolder(root_path.value, root.receive()))) {
    LogWarning(L"Task Scheduler root folder could not be opened.");
    *error_message = L"Recovery host task could not be created.";
    return false;
  }
  // Replace any stale task that still carries this transaction name.
  ScopedBstr task_bstr(task_name->c_str());
  if (task_bstr.valid()) {
    root->DeleteTask(task_bstr.value, 0);
  }

  ComPtr<ITaskDefinition> task;
  result = service->NewTask(0, task.receive());
  if (FAILED(result)) {
    LogWarning(std::wstring(L"Recovery task definition could not be created; HRESULT ") +
               std::to_wstring(static_cast<unsigned long>(result)));
    *error_message = L"Recovery host task could not be created.";
    return false;
  }
  ComPtr<ITaskSettings> settings;
  if (SUCCEEDED(task->get_Settings(settings.receive())) && settings.value != nullptr) {
    // The task is started explicitly right after registration; keep it
    // runnable on battery and without a duration cap so the waiter can wait
    // for the caller process to exit on its own schedule.
    settings->put_StartWhenAvailable(VARIANT_TRUE);
    settings->put_StopIfGoingOnBatteries(VARIANT_FALSE);
    settings->put_DisallowStartIfOnBatteries(VARIANT_FALSE);
    settings->put_ExecutionTimeLimit(L"PT0S");
  }
  ComPtr<ITriggerCollection> triggers;
  ComPtr<ITrigger> trigger;
  ComPtr<ITimeTrigger> time_trigger;
  result = task->get_Triggers(triggers.receive());
  if (FAILED(result) ||
      FAILED(triggers->Create(TASK_TRIGGER_TIME, trigger.receive())) ||
      FAILED(trigger->QueryInterface(IID_ITimeTrigger,
                                     reinterpret_cast<void**>(time_trigger.receive()))) ||
      FAILED(time_trigger->put_StartBoundary(boundary.c_str()))) {
    LogWarning(L"Recovery task trigger could not be attached.");
    *error_message = L"Recovery host task could not be created.";
    return false;
  }
  ComPtr<IActionCollection> actions;
  ComPtr<IAction> action;
  ComPtr<IExecAction> exec_action;
  const std::wstring runtime_path_text = runtime_path.wstring();
  result = task->get_Actions(actions.receive());
  if (FAILED(result) ||
      FAILED(actions->Create(TASK_ACTION_EXEC, action.receive())) ||
      FAILED(action->QueryInterface(IID_IExecAction,
                                    reinterpret_cast<void**>(exec_action.receive()))) ||
      FAILED(exec_action->put_Path(runtime_path_text.c_str())) ||
      FAILED(exec_action->put_Arguments(task_arguments.c_str()))) {
    LogWarning(L"Recovery task action could not be attached.");
    *error_message = L"Recovery host task could not be created.";
    return false;
  }
  ComPtr<IRegisteredTask> registered;
  result = root->RegisterTaskDefinition(task_bstr.value, task.value,
                                        TASK_CREATE_OR_REPLACE, empty, empty,
                                        TASK_LOGON_INTERACTIVE_TOKEN, empty,
                                        registered.receive());
  if (FAILED(result)) {
    LogWarning(std::wstring(L"RegisterTaskDefinition failed; HRESULT ") +
               std::to_wstring(static_cast<unsigned long>(result)));
    *error_message = L"Recovery host task could not be created.";
    return false;
  }
  result = registered->Run(empty);
  if (FAILED(result)) {
    LogWarning(std::wstring(L"Recovery task could not be started; HRESULT ") +
               std::to_wstring(static_cast<unsigned long>(result)));
    *error_message = L"Recovery host task could not be started.";
    return false;
  }
  LogInfo(L"Recovery host task created and started.");
  return true;
}

void DeleteRecoveryHostTask(const std::wstring& task_name) {
  if (task_name.empty()) {
    return;
  }
  ComScope com_scope;
  ComPtr<ITaskService> service;
  if (FAILED(CoCreateInstance(CLSID_TaskScheduler, nullptr,
                              CLSCTX_INPROC_SERVER, IID_ITaskService,
                              reinterpret_cast<void**>(service.receive())))) {
    return;
  }
  VARIANT empty{};
  VariantInit(&empty);
  if (FAILED(service->Connect(empty, empty, empty, empty))) {
    return;
  }
  ScopedBstr root_path(L"\\");
  ComPtr<ITaskFolder> root;
  if (!root_path.valid() ||
      FAILED(service->GetFolder(root_path.value, root.receive()))) {
    return;
  }
  ScopedBstr task_bstr(task_name.c_str());
  if (!task_bstr.valid()) {
    return;
  }
  root->DeleteTask(task_bstr.value, 0);
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

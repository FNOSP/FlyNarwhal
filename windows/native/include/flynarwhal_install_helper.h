#pragma once

#include <Windows.h>

#include <cstdint>
#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace flynarwhal::install_helper {

// Defined in flynarwhal_updater_endpoint.h; referenced here by const
// reference so the install helper header can avoid an include cycle.
struct EndpointDescriptor;

enum class TransactionState {
  prepared,
  restaged,
  recovery_armed,
  commit_accepted,
  waiting_for_exit,
  manager_started,
  verification_pending,
  completed,
  failed,
  cancelled,
  manual_action_required,
};

// How the restaged artifact is applied once the caller has exited:
// installer launches the Inno Setup package, portable extracts the zip
// archive straight over the caller's application directory.
enum class PackageMode { installer, portable };

struct RequestBindings {
  std::wstring transaction_id;
  std::filesystem::path stage_path;
  std::wstring stage_provenance_sha256;
  std::wstring expected_artifact_sha256;
  std::uint64_t expected_artifact_length = 0;
  DWORD caller_process_id = 0;
  std::filesystem::path caller_executable;
};

struct Journal {
  int schema_version = 1;
  RequestBindings bindings;
  TransactionState state = TransactionState::prepared;
  PackageMode package_mode = PackageMode::installer;
  std::filesystem::path helper_executable;
  std::filesystem::path protected_helper_path;
  std::filesystem::path recovery_host_path;
  std::filesystem::path restaged_installer_path;
  std::filesystem::path update_log_path;
  std::wstring helper_sha256;
  std::wstring restaged_installer_sha256;
  std::wstring endpoint_version;
  std::wstring recovery_task_name;
  bool installer_started = false;
  bool relaunch_attempted = false;
  bool recovery_armed = false;
  DWORD installer_exit_code = 0;
  std::wstring terminal_message;
};

struct StageVerification {
  std::filesystem::path installer_path;
  std::filesystem::path authority_path;
  std::filesystem::path provenance_path;
  std::uint64_t artifact_length = 0;
  std::wstring candidate_version;
  std::wstring candidate_architecture;
  PackageMode package_mode = PackageMode::installer;
};

struct ProcessLaunchPolicy {
  std::filesystem::path installer_path;
  std::filesystem::path install_root;
  std::filesystem::path log_path;
};

// Release-visible update log session helpers shared by every native binary.
void LogInfo(const std::wstring& message);
void LogWarning(const std::wstring& message);
void LogError(const std::wstring& message);
void StartUpdateLogSession(const std::filesystem::path& log_path);
std::filesystem::path CreateUpdateLogPath();
void EnsureJournalHasUpdateLogPath(Journal* journal);

std::wstring StateToString(TransactionState state);
std::optional<TransactionState> StateFromString(const std::wstring& value);
bool IsTerminalState(TransactionState state);
bool IsCanonicalUuidV4(const std::wstring& value);
bool IsLowercaseSha256(const std::wstring& value);
std::filesystem::path GetLocalAppDataPath();
std::filesystem::path GetJournalPath();
std::filesystem::path GetInstallRootForExecutable(
    const std::filesystem::path& executable_path);
std::filesystem::path GetCurrentExecutablePath();
std::wstring ComputeFileSha256(const std::filesystem::path& path);
bool HasReparsePointInExistingPath(const std::filesystem::path& path);
bool ValidateCallerInstallRoot(
    const std::filesystem::path& helper_executable_path,
    const std::filesystem::path& caller_executable_path);
bool ValidateJournalExecutableBinding(
    const Journal& journal,
    const std::filesystem::path& current_executable_path,
    const std::wstring& current_executable_sha);
bool ValidateCallerIdentity(const RequestBindings& bindings);
bool ValidateStage(const RequestBindings& bindings,
                   StageVerification* verification,
                   std::wstring* error_message);
bool ValidateInstalledExecutable(const std::filesystem::path& executable,
                                 const StageVerification& verification,
                                 std::wstring* error_message);
std::vector<std::wstring> BuildFixedInstallerArguments(
    const ProcessLaunchPolicy& policy);
// Applies the restaged artifact for the transaction: launches the Inno Setup
// installer for installer mode, or extracts the portable zip archive over
// the install root for portable mode. Shared by the protected helper worker
// and the recovery host resume path.
bool ApplyRestagedArtifact(const Journal& journal,
                           const ProcessLaunchPolicy& policy,
                           DWORD* exit_code,
                           std::wstring* error_message);
std::wstring QuoteWindowsArgument(const std::wstring& argument);
bool WriteJournalDurably(const Journal& journal, std::wstring* error_message);
std::optional<Journal> ReadJournal(std::wstring* error_message);
bool ClearTerminalJournal(std::wstring* error_message);
void RefreshJournalEndpointBinding(Journal* journal,
                                   const EndpointDescriptor& descriptor);
int RunPrepare(const RequestBindings& bindings);
int RunCommit(const RequestBindings& bindings);
int RunQuery(const std::wstring& transaction_id);
int RunCancel(const std::wstring& transaction_id);
int RunRecover(const std::wstring& transaction_id);
int RunWorker(const RequestBindings& bindings);

}  // namespace flynarwhal::install_helper

#pragma once

#include <Windows.h>

#include <cstdint>
#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <vector>

namespace flynarwhal::install_helper {

enum class TransactionState {
  prepared,
  commit_accepted,
  waiting_for_exit,
  manager_started,
  verification_pending,
  completed,
  failed,
  cancelled,
  manual_action_required,
};

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
  std::filesystem::path helper_executable;
  std::wstring helper_sha256;
  bool installer_started = false;
  bool relaunch_attempted = false;
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
};

struct ProcessLaunchPolicy {
  std::filesystem::path installer_path;
  std::filesystem::path install_root;
  std::filesystem::path log_path;
};

std::wstring StateToString(TransactionState state);
std::optional<TransactionState> StateFromString(const std::wstring& value);
bool IsTerminalState(TransactionState state);
bool IsCanonicalUuidV4(const std::wstring& value);
bool IsLowercaseSha256(const std::wstring& value);
std::filesystem::path GetLocalAppDataPath();
std::filesystem::path GetJournalPath();
std::filesystem::path GetFixedInstallRoot();
std::filesystem::path GetCurrentExecutablePath();
std::wstring ComputeFileSha256(const std::filesystem::path& path);
bool HasReparsePointInExistingPath(const std::filesystem::path& path);
bool ValidateCallerIdentity(const RequestBindings& bindings);
bool ValidateStage(const RequestBindings& bindings,
                   StageVerification* verification,
                   std::wstring* error_message);
std::vector<std::wstring> BuildFixedInstallerArguments(
    const ProcessLaunchPolicy& policy);
std::wstring QuoteWindowsArgument(const std::wstring& argument);
bool WriteJournalDurably(const Journal& journal, std::wstring* error_message);
std::optional<Journal> ReadJournal(std::wstring* error_message);
bool ClearTerminalJournal(std::wstring* error_message);
int RunPrepare(const RequestBindings& bindings);
int RunCommit(const RequestBindings& bindings);
int RunQuery(const std::wstring& transaction_id);
int RunCancel(const std::wstring& transaction_id);
int RunRecover(const std::wstring& transaction_id);
int RunWorker(const RequestBindings& bindings);

}  // namespace flynarwhal::install_helper

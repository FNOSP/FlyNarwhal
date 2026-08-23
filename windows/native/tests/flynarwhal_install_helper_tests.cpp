#include "flynarwhal_install_helper.h"
#include "flynarwhal_updater_endpoint.h"

#include <Windows.h>

#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

namespace helper = flynarwhal::install_helper;

namespace {

int failures = 0;

void Expect(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAILED: " << message << '\n';
    ++failures;
  }
}

void TestTransactionValidation() {
  Expect(helper::IsCanonicalUuidV4(
             L"123e4567-e89b-42d3-a456-426614174000"),
         "canonical UUID v4 should be accepted");
  Expect(!helper::IsCanonicalUuidV4(
             L"123e4567-e89b-12d3-a456-426614174000"),
         "non-v4 UUID should be rejected");
  Expect(!helper::IsCanonicalUuidV4(
             L"123E4567-E89B-42D3-A456-426614174000"),
         "uppercase UUID should be rejected");
}

void TestExtendedTransactionStates() {
  const auto restaged = helper::StateFromString(L"restaged");
  const auto recovery_armed = helper::StateFromString(L"recoveryArmed");
  Expect(restaged.has_value() &&
             restaged.value() == helper::TransactionState::restaged,
         "restaged state should parse");
  Expect(recovery_armed.has_value() &&
             recovery_armed.value() == helper::TransactionState::recovery_armed,
         "recoveryArmed state should parse");
}

void TestFixedPolicy() {
  helper::ProcessLaunchPolicy policy;
  policy.installer_path = L"C:\\stage with space\\installer.exe";
  policy.install_root = L"D:\\Program Files\\FlyNarwhal";
  policy.log_path = L"C:\\logs\\install.log";
  const std::vector<std::wstring> arguments =
      helper::BuildFixedInstallerArguments(policy);
  Expect(arguments.size() == 6, "fixed policy should contain six arguments");
  Expect(arguments[0] == L"/SILENT", "silent flag should be fixed");
  Expect(arguments[1] == L"/SUPPRESSMSGBOXES",
         "message boxes should be suppressed");
  Expect(arguments[2] == L"/NORESTART", "restart flag should be fixed");
  Expect(arguments[3] == L"/CLOSEAPPLICATIONS",
         "close applications flag should be fixed");
  Expect(arguments[4] == L"/DIR=D:\\Program Files\\FlyNarwhal",
         "install root should preserve the caller supplied path");
  Expect(arguments[5].rfind(L"/LOG=", 0) == 0,
         "log path should be policy supplied");
}

void TestInstallRootResolution() {
  const auto install_root = helper::GetInstallRootForExecutable(
      L"D:\\Program Files\\FlyNarwhal\\FlyNarwhal.exe");
  Expect(install_root == L"D:\\Program Files\\FlyNarwhal",
         "install root should resolve from the executable parent directory");
}

void TestJournalRoundTripAndCancel() {
  const std::wstring transaction_id =
      L"123e4567-e89b-42d3-a456-426614174000";
  helper::Journal journal;
  journal.bindings.transaction_id = transaction_id;
  journal.bindings.stage_path = L"C:\\owned\\desktop_updater_stage_" +
                                transaction_id;
  journal.bindings.stage_provenance_sha256 = std::wstring(64, L'a');
  journal.bindings.expected_artifact_sha256 = std::wstring(64, L'b');
  journal.bindings.expected_artifact_length = 1024;
  journal.bindings.caller_process_id = GetCurrentProcessId();
  journal.bindings.caller_executable = helper::GetCurrentExecutablePath();
  journal.helper_executable = helper::GetCurrentExecutablePath();
  // Point the protected helper at the running test executable so endpoint
  // binding validation matches during cancel/query roundtrip checks.
  journal.protected_helper_path = helper::GetCurrentExecutablePath();
  journal.recovery_host_path =
      helper::GetLocalAppDataPath() / L"FlyNarwhal" / L"updater" /
      L"protected" / L"FlyNarwhalRecoveryHost.exe";
  journal.restaged_installer_path =
      helper::GetLocalAppDataPath() / L"FlyNarwhal" / L"updates" /
      L"restaged" / transaction_id / L"installer.exe";
  journal.update_log_path =
      helper::GetLocalAppDataPath() / L"logs" /
      L"update_ 20260818_120000.log";
  journal.helper_sha256 = helper::ComputeFileSha256(journal.helper_executable);
  journal.restaged_installer_sha256 = std::wstring(64, L'c');
  journal.endpoint_version = L"2.1.0";
  journal.recovery_task_name = L"FlyNarwhal.UpdateRecovery." + transaction_id;
  journal.state = helper::TransactionState::prepared;

  std::wstring error;
  Expect(helper::WriteJournalDurably(journal, &error),
         "journal should be written durably");
  const auto restored = helper::ReadJournal(&error);
  Expect(restored.has_value(), "journal should be readable");
  if (restored.has_value()) {
    Expect(restored->bindings.transaction_id == transaction_id,
           "transaction ID should survive roundtrip");
    Expect(restored->state == helper::TransactionState::prepared,
           "state should survive roundtrip");
    Expect(restored->update_log_path == journal.update_log_path,
           "update log path should survive roundtrip");
    Expect(restored->protected_helper_path == journal.protected_helper_path,
           "protected helper path should survive roundtrip");
    Expect(restored->restaged_installer_path == journal.restaged_installer_path,
           "restaged installer path should survive roundtrip");
    Expect(restored->recovery_task_name == journal.recovery_task_name,
           "recovery task name should survive roundtrip");
  }

  const int query_result = helper::RunQuery(transaction_id);
  Expect(query_result == 0, "query should find the prepared transaction");
  const int cancel_result = helper::RunCancel(transaction_id);
  Expect(cancel_result == 0, "cancel should terminate a prepared transaction");
  const auto cancelled = helper::ReadJournal(&error);
  Expect(cancelled.has_value() &&
             cancelled->state == helper::TransactionState::cancelled,
         "cancel should persist a terminal state");
  Expect(helper::ClearTerminalJournal(&error),
         "terminal journal should be removable by tests");
}

void TestIllegalStage() {
  helper::RequestBindings bindings;
  bindings.transaction_id = L"123e4567-e89b-42d3-a456-426614174000";
  bindings.stage_path = L"C:\\not-owned\\stage";
  bindings.stage_provenance_sha256 = std::wstring(64, L'a');
  bindings.expected_artifact_sha256 = std::wstring(64, L'b');
  bindings.expected_artifact_length = 1024;
  bindings.caller_process_id = GetCurrentProcessId();
  bindings.caller_executable = helper::GetCurrentExecutablePath();
  helper::StageVerification verification;
  std::wstring error;
  Expect(!helper::ValidateStage(bindings, &verification, &error),
         "non-owned stage should be rejected");
}

void TestRefreshJournalEndpointBinding() {
  const std::wstring transaction_id =
      L"123e4567-e89b-42d3-a456-426614174000";
  helper::Journal journal;
  journal.bindings.transaction_id = transaction_id;
  journal.helper_executable = L"C:\\old\\FlyNarwhalProtectedHelper.exe";
  journal.protected_helper_path = L"C:\\old\\FlyNarwhalProtectedHelper.exe";
  journal.recovery_host_path = L"C:\\old\\FlyNarwhalRecoveryHost.exe";
  journal.helper_sha256 = std::wstring(64, L'a');
  journal.endpoint_version = L"2.1.0";

  helper::EndpointDescriptor descriptor;
  descriptor.endpoint_version = L"2.2.0";
  descriptor.protected_helper_path =
      L"C:\\new\\FlyNarwhalProtectedHelper.exe";
  descriptor.protected_helper_sha256 = std::wstring(64, L'b');
  descriptor.recovery_host_path = L"C:\\new\\FlyNarwhalRecoveryHost.exe";
  descriptor.recovery_host_sha256 = std::wstring(64, L'c');

  // A stale journal must not validate against the freshly updated endpoint.
  Expect(!helper::ValidateJournalExecutableBinding(
             journal, descriptor.protected_helper_path,
             descriptor.protected_helper_sha256),
         "stale journal binding should not match the updated endpoint");

  helper::RefreshJournalEndpointBinding(&journal, descriptor);

  Expect(journal.helper_executable == descriptor.protected_helper_path,
         "helper executable should be rebound to the endpoint");
  Expect(journal.protected_helper_path == descriptor.protected_helper_path,
         "protected helper path should be rebound");
  Expect(journal.recovery_host_path == descriptor.recovery_host_path,
         "recovery host path should be rebound");
  Expect(journal.endpoint_version == descriptor.endpoint_version,
         "endpoint version should be rebound");
  Expect(journal.helper_sha256 == descriptor.protected_helper_sha256,
         "helper digest should be rebound");

  // The refreshed binding must validate against the current endpoint.
  Expect(helper::ValidateJournalExecutableBinding(
             journal, descriptor.protected_helper_path,
             descriptor.protected_helper_sha256),
         "refreshed journal binding should match the current endpoint");
}

}  // namespace

// Redirects the updater data root to a hermetic temp directory so journal
// writes never touch the real production journal or application data.
void RedirectUpdaterDataRootToTemp() {
  wchar_t temp_root[MAX_PATH]{};
  const DWORD temp_length = GetTempPathW(MAX_PATH, temp_root);
  if (temp_length == 0 || temp_length >= MAX_PATH) {
    return;
  }
  const std::filesystem::path data_root =
      std::filesystem::path(std::wstring(temp_root, temp_length)) /
      L"flynarwhal_native_tests" / std::to_wstring(GetCurrentProcessId());
  std::error_code ignored;
  std::filesystem::create_directories(data_root, ignored);
  SetEnvironmentVariableW(L"FLYNARWHAL_UPDATER_DATA_ROOT",
                          data_root.c_str());
}

int wmain() {
  RedirectUpdaterDataRootToTemp();
  TestTransactionValidation();
  TestExtendedTransactionStates();
  TestFixedPolicy();
  TestInstallRootResolution();
  TestJournalRoundTripAndCancel();
  TestIllegalStage();
  TestRefreshJournalEndpointBinding();
  if (failures != 0) {
    std::cerr << failures << " test assertion(s) failed\n";
    return 1;
  }
  std::cout << "All native helper tests passed\n";
  return 0;
}

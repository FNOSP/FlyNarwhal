#include "flynarwhal_install_helper.h"

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

void TestFixedPolicy() {
  helper::ProcessLaunchPolicy policy;
  policy.installer_path = L"C:\\stage with space\\installer.exe";
  policy.install_root = helper::GetFixedInstallRoot();
  policy.log_path = L"C:\\logs\\install.log";
  const std::vector<std::wstring> arguments =
      helper::BuildFixedInstallerArguments(policy);
  Expect(arguments.size() == 7, "fixed policy should contain seven arguments");
  Expect(arguments[0] == L"/VERYSILENT", "silent flag should be fixed");
  Expect(arguments[5].rfind(L"/DIR=", 0) == 0,
         "install root should be policy supplied");
  Expect(arguments[6].rfind(L"/LOG=", 0) == 0,
         "log path should be policy supplied");
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
  journal.helper_sha256 = helper::ComputeFileSha256(journal.helper_executable);
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

}  // namespace

int wmain() {
  TestTransactionValidation();
  TestFixedPolicy();
  TestJournalRoundTripAndCancel();
  TestIllegalStage();
  if (failures != 0) {
    std::cerr << failures << " test assertion(s) failed\n";
    return 1;
  }
  std::cout << "All native helper tests passed\n";
  return 0;
}

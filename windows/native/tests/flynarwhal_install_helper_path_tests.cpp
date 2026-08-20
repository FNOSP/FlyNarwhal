#include "flynarwhal_install_helper.h"

#include <iostream>
#include <string>

namespace helper = flynarwhal::install_helper;

namespace {

int failures = 0;

void Expect(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAILED: " << message << '\n';
    ++failures;
  }
}

void TestInstallRootResolution() {
  const auto install_root = helper::GetInstallRootForExecutable(
      L"D:\\Program Files\\FlyNarwhal\\FlyNarwhal.exe");
  Expect(install_root == L"D:\\Program Files\\FlyNarwhal",
         "install root should resolve from the executable parent directory");
}

void TestCallerInstallRootValidation() {
  // Allow the installed app and helper to share any real bundle directory.
  Expect(helper::ValidateCallerInstallRoot(
             L"D:\\Program Files\\FlyNarwhal\\FlyNarwhalInstallHelper.exe",
             L"D:\\Program Files\\FlyNarwhal\\FlyNarwhal.exe"),
         "caller should be accepted when it shares the helper install root");

  // Reject callers from a different bundle directory.
  Expect(!helper::ValidateCallerInstallRoot(
             L"C:\\Users\\tester\\AppData\\Local\\FlyNarwhal\\FlyNarwhalInstallHelper.exe",
             L"D:\\Program Files\\FlyNarwhal\\FlyNarwhal.exe"),
         "caller should be rejected when it comes from another install root");
}

void TestJournalExecutableBinding() {
  helper::Journal journal;
  journal.bindings.transaction_id =
      L"123e4567-e89b-42d3-a456-426614174000";
  journal.helper_executable =
      L"D:\\Program Files\\FlyNarwhal\\FlyNarwhalInstallHelper.exe";
  journal.protected_helper_path =
      L"C:\\Users\\tester\\AppData\\Local\\FlyNarwhal\\updater\\protected\\FlyNarwhalProtectedHelper.exe";
  journal.helper_sha256 = std::wstring(64, L'a');
  const auto workerPath =
      helper::GetLocalAppDataPath() / L"FlyNarwhal" / L"updates" /
      L"worker-runtime" / journal.bindings.transaction_id /
      L"FlyNarwhalInstallHelper.exe";

  Expect(helper::ValidateJournalExecutableBinding(
             journal,
             L"C:\\Users\\tester\\AppData\\Local\\FlyNarwhal\\updater\\protected\\FlyNarwhalProtectedHelper.exe",
             std::wstring(64, L'a')),
         "protected helper path should remain a valid transaction endpoint");

  Expect(helper::ValidateJournalExecutableBinding(
             journal, workerPath,
             std::wstring(64, L'a')),
         "worker runtime copy should be accepted as a valid endpoint");

  Expect(!helper::ValidateJournalExecutableBinding(
             journal, workerPath,
             std::wstring(64, L'b')),
         "worker runtime copy should still require the trusted helper digest");
}

}  // namespace

int wmain() {
  TestInstallRootResolution();
  TestCallerInstallRootValidation();
  TestJournalExecutableBinding();
  if (failures != 0) {
    std::cerr << failures << " test assertion(s) failed\n";
    return 1;
  }
  std::cout << "All helper path tests passed\n";
  return 0;
}

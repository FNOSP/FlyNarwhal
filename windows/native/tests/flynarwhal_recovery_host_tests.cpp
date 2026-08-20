#include "flynarwhal_recovery_host.h"

#include <iostream>

namespace helper = flynarwhal::install_helper;

namespace {

int failures = 0;

void Expect(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAILED: " << message << '\n';
    ++failures;
  }
}

void TestRecoveryTaskName() {
  const auto task_name = helper::BuildRecoveryTaskName(
      L"123e4567-e89b-42d3-a456-426614174000");
  Expect(task_name == L"FlyNarwhal.UpdateRecovery.123e4567-e89b-42d3-a456-426614174000",
         "recovery task name should use the fixed prefix");
}

}  // namespace

int wmain() {
  TestRecoveryTaskName();
  if (failures != 0) {
    std::cerr << failures << " test assertion(s) failed\n";
    return 1;
  }
  std::cout << "All recovery host tests passed\n";
  return 0;
}

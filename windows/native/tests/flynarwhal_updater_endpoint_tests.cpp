#include "flynarwhal_install_helper.h"
#include "flynarwhal_updater_endpoint.h"

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

void TestPolicyRoundTrip() {
  helper::EndpointPolicy policy;
  policy.endpoint_version = L"2.1.0";
  policy.protected_root =
      helper::GetLocalAppDataPath() / L"FlyNarwhal" / L"updater" / L"protected";
  const auto parsed =
      helper::ParseEndpointPolicy(helper::SerializeEndpointPolicy(policy));
  Expect(parsed.has_value(), "policy should roundtrip");
  if (!parsed.has_value()) {
    return;
  }
  Expect(parsed->endpoint_version == policy.endpoint_version,
         "policy version should roundtrip");
  Expect(parsed->protected_root == policy.protected_root,
         "policy root should roundtrip");
}

void TestRecoveryRuntimePath() {
  const auto path = helper::GetRecoveryRuntimePath(
      L"123e4567-e89b-42d3-a456-426614174000");
  Expect(path.filename() == L"FlyNarwhalRecoveryHost.exe",
         "recovery runtime path should end with the recovery host name");
}

}  // namespace

int wmain() {
  TestPolicyRoundTrip();
  TestRecoveryRuntimePath();
  if (failures != 0) {
    std::cerr << failures << " test assertion(s) failed\n";
    return 1;
  }
  std::cout << "All updater endpoint tests passed\n";
  return 0;
}

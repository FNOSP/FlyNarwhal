#pragma once

#include <filesystem>
#include <optional>
#include <string>

namespace flynarwhal::install_helper {

struct EndpointDescriptor {
  int schema_version = 1;
  std::wstring endpoint_version;
  std::filesystem::path protected_helper_path;
  std::wstring protected_helper_sha256;
  std::filesystem::path recovery_host_path;
  std::wstring recovery_host_sha256;
  std::filesystem::path policy_path;
};

struct EndpointPolicy {
  int schema_version = 1;
  std::wstring endpoint_version;
  std::filesystem::path protected_root;
};

std::wstring GetEndpointRegistrySubkey();
std::filesystem::path GetProtectedEndpointRoot();
std::filesystem::path GetEndpointPolicyPath();
std::filesystem::path GetRecoveryRuntimeRoot();
std::filesystem::path GetRecoveryRuntimePath(const std::wstring& transaction_id);
bool IsPathUnderRoot(const std::filesystem::path& candidate,
                     const std::filesystem::path& root);
bool ReadRegisteredEndpoint(EndpointDescriptor* descriptor,
                            std::wstring* error_message);
bool ReadEndpointPolicy(const std::filesystem::path& policy_path,
                        EndpointPolicy* policy,
                        std::wstring* error_message);
bool ValidateEndpointDescriptor(const EndpointDescriptor& descriptor,
                                const EndpointPolicy& policy,
                                std::wstring* error_message);
bool ValidateCurrentProtectedExecutable(const EndpointDescriptor& descriptor,
                                        const EndpointPolicy& policy,
                                        const std::filesystem::path& current_executable,
                                        const std::wstring& current_sha256,
                                        bool expect_recovery_host,
                                        const std::wstring& transaction_id,
                                        std::wstring* error_message);
std::wstring SerializeEndpointPolicy(const EndpointPolicy& policy);
std::optional<EndpointPolicy> ParseEndpointPolicy(const std::wstring& json);

}  // namespace flynarwhal::install_helper

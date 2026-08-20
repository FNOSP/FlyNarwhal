#include "flynarwhal_updater_endpoint.h"

#include "flynarwhal_install_helper.h"

#include <Windows.h>

#include <algorithm>
#include <fstream>
#include <optional>
#include <regex>
#include <sstream>

namespace flynarwhal::install_helper {
namespace {

std::wstring ToLower(std::wstring value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](wchar_t character) {
                   return static_cast<wchar_t>(towlower(character));
                 });
  return value;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return {};
  }
  const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                       value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) {
    return {};
  }
  std::string converted(static_cast<std::size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), converted.data(), size,
                      nullptr, nullptr);
  return converted;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0);
  if (size <= 0) {
    return {};
  }
  std::wstring converted(static_cast<std::size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), converted.data(), size);
  return converted;
}

std::string EscapeJson(const std::wstring& value) {
  const std::string utf8 = WideToUtf8(value);
  std::string escaped;
  escaped.reserve(utf8.size());
  for (const char character : utf8) {
    switch (character) {
      case '\\':
        escaped += "\\\\";
        break;
      case '"':
        escaped += "\\\"";
        break;
      case '\n':
        escaped += "\\n";
        break;
      case '\r':
        escaped += "\\r";
        break;
      case '\t':
        escaped += "\\t";
        break;
      default:
        escaped += character;
        break;
    }
  }
  return escaped;
}

std::wstring UnescapeJson(const std::string& value) {
  std::string unescaped;
  unescaped.reserve(value.size());
  bool escaping = false;
  for (const char character : value) {
    if (!escaping && character == '\\') {
      escaping = true;
      continue;
    }
    if (escaping) {
      switch (character) {
        case 'n':
          unescaped += '\n';
          break;
        case 'r':
          unescaped += '\r';
          break;
        case 't':
          unescaped += '\t';
          break;
        default:
          unescaped += character;
          break;
      }
      escaping = false;
      continue;
    }
    unescaped += character;
  }
  return Utf8ToWide(unescaped);
}

std::optional<std::wstring> ReadUtf8File(const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) {
    return std::nullopt;
  }
  std::ostringstream contents;
  contents << stream.rdbuf();
  if (!stream.good() && !stream.eof()) {
    return std::nullopt;
  }
  return Utf8ToWide(contents.str());
}

std::optional<std::wstring> ExtractJsonString(const std::wstring& json,
                                              const std::wstring& key) {
  const std::wregex expression(L"\\\"" + key +
                               L"\\\"\\s*:\\s*\\\"((?:\\\\.|[^\\\"])*)\\\"");
  std::wsmatch match;
  if (!std::regex_search(json, match, expression)) {
    return std::nullopt;
  }
  return UnescapeJson(WideToUtf8(match[1].str()));
}

std::optional<std::uint64_t> ExtractJsonUnsigned(const std::wstring& json,
                                                 const std::wstring& key) {
  const std::wregex expression(L"\\\"" + key + L"\\\"\\s*:\\s*([0-9]+)");
  std::wsmatch match;
  if (!std::regex_search(json, match, expression)) {
    return std::nullopt;
  }
  try {
    return std::stoull(match[1].str());
  } catch (...) {
    return std::nullopt;
  }
}

bool ReadRegistryString(const std::wstring& name,
                        std::wstring* value,
                        std::wstring* error_message) {
  DWORD type = 0;
  DWORD size = 0;
  const auto status =
      RegGetValueW(HKEY_CURRENT_USER, GetEndpointRegistrySubkey().c_str(),
                   name.c_str(), RRF_RT_REG_SZ, &type, nullptr, &size);
  if (status != ERROR_SUCCESS || size < sizeof(wchar_t)) {
    *error_message = L"Endpoint registry value is missing.";
    return false;
  }
  std::wstring buffer(size / sizeof(wchar_t), L'\0');
  if (RegGetValueW(HKEY_CURRENT_USER, GetEndpointRegistrySubkey().c_str(),
                   name.c_str(), RRF_RT_REG_SZ, &type, buffer.data(),
                   &size) != ERROR_SUCCESS) {
    *error_message = L"Endpoint registry value could not be read.";
    return false;
  }
  // RegGetValueW may append an extra null terminator, so truncate at the
  // first null instead of only popping the trailing one.
  const std::size_t terminator = buffer.find(L'\0');
  if (terminator != std::wstring::npos) {
    buffer.resize(terminator);
  }
  *value = buffer;
  return true;
}

bool ReadRegistryDword(const std::wstring& name,
                       int* value,
                       std::wstring* error_message) {
  DWORD raw = 0;
  DWORD size = sizeof(raw);
  DWORD type = 0;
  if (RegGetValueW(HKEY_CURRENT_USER, GetEndpointRegistrySubkey().c_str(),
                   name.c_str(), RRF_RT_REG_DWORD, &type, &raw,
                   &size) != ERROR_SUCCESS) {
    *error_message = L"Endpoint registry schema is missing.";
    return false;
  }
  *value = static_cast<int>(raw);
  return true;
}

bool PathsEqual(const std::filesystem::path& left,
                const std::filesystem::path& right) {
  std::error_code error;
  const auto canonical_left = std::filesystem::weakly_canonical(left, error);
  if (error) {
    return false;
  }
  const auto canonical_right = std::filesystem::weakly_canonical(right, error);
  return !error &&
         ToLower(canonical_left.wstring()) == ToLower(canonical_right.wstring());
}

bool IsSafeRegularFileLocal(const std::filesystem::path& path) {
  if (HasReparsePointInExistingPath(path)) {
    return false;
  }
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0 &&
         (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0;
}

}  // namespace

std::wstring GetEndpointRegistrySubkey() {
  return L"Software\\JankinWu\\FlyNarwhal\\Updater\\Endpoint\\Current";
}

std::filesystem::path GetProtectedEndpointRoot() {
  return GetLocalAppDataPath() / L"FlyNarwhal" / L"updater" / L"protected";
}

std::filesystem::path GetEndpointPolicyPath() {
  return GetProtectedEndpointRoot() / L"endpoint-policy.json";
}

std::filesystem::path GetRecoveryRuntimeRoot() {
  return GetLocalAppDataPath() / L"FlyNarwhal" / L"updates" / L"recovery-runtime";
}

std::filesystem::path GetRecoveryRuntimePath(const std::wstring& transaction_id) {
  return GetRecoveryRuntimeRoot() / transaction_id / L"FlyNarwhalRecoveryHost.exe";
}

bool IsPathUnderRoot(const std::filesystem::path& candidate,
                     const std::filesystem::path& root) {
  std::error_code error;
  const auto canonical_root = std::filesystem::weakly_canonical(root, error);
  if (error) {
    return false;
  }
  const auto canonical_candidate =
      std::filesystem::weakly_canonical(candidate, error);
  if (error) {
    return false;
  }
  const auto candidate_value = ToLower(canonical_candidate.wstring());
  auto root_value = ToLower(canonical_root.wstring());
  if (!root_value.empty() && root_value.back() != L'\\') {
    root_value += L'\\';
  }
  return candidate_value == ToLower(canonical_root.wstring()) ||
         candidate_value.rfind(root_value, 0) == 0;
}

bool ReadRegisteredEndpoint(EndpointDescriptor* descriptor,
                            std::wstring* error_message) {
  if (descriptor == nullptr) {
    *error_message = L"Endpoint descriptor target is invalid.";
    return false;
  }
  if (!ReadRegistryDword(L"SchemaVersion", &descriptor->schema_version,
                         error_message) ||
      !ReadRegistryString(L"EndpointVersion", &descriptor->endpoint_version,
                          error_message)) {
    return false;
  }

  std::wstring protected_helper_path;
  std::wstring protected_helper_sha;
  std::wstring recovery_host_path;
  std::wstring recovery_host_sha;
  std::wstring policy_path;
  if (!ReadRegistryString(L"ProtectedHelperPath", &protected_helper_path,
                          error_message) ||
      !ReadRegistryString(L"ProtectedHelperSha256", &protected_helper_sha,
                          error_message) ||
      !ReadRegistryString(L"RecoveryHostPath", &recovery_host_path,
                          error_message) ||
      !ReadRegistryString(L"RecoveryHostSha256", &recovery_host_sha,
                          error_message) ||
      !ReadRegistryString(L"PolicyPath", &policy_path, error_message)) {
    return false;
  }
  descriptor->protected_helper_path = protected_helper_path;
  descriptor->protected_helper_sha256 = protected_helper_sha;
  descriptor->recovery_host_path = recovery_host_path;
  descriptor->recovery_host_sha256 = recovery_host_sha;
  descriptor->policy_path = policy_path;
  return true;
}

std::wstring SerializeEndpointPolicy(const EndpointPolicy& policy) {
  std::ostringstream output;
  output << "{\"schemaVersion\":" << policy.schema_version
         << ",\"endpointVersion\":\"" << EscapeJson(policy.endpoint_version)
         << "\",\"protectedRoot\":\""
         << EscapeJson(policy.protected_root.wstring()) << "\"}";
  return Utf8ToWide(output.str());
}

std::optional<EndpointPolicy> ParseEndpointPolicy(const std::wstring& json) {
  EndpointPolicy policy;
  const auto schema = ExtractJsonUnsigned(json, L"schemaVersion");
  const auto version = ExtractJsonString(json, L"endpointVersion");
  const auto protected_root = ExtractJsonString(json, L"protectedRoot");
  if (!schema || *schema != 1 || !version || !protected_root) {
    return std::nullopt;
  }
  policy.schema_version = static_cast<int>(*schema);
  policy.endpoint_version = *version;
  policy.protected_root = *protected_root;
  return policy;
}

bool ReadEndpointPolicy(const std::filesystem::path& policy_path,
                        EndpointPolicy* policy,
                        std::wstring* error_message) {
  if (policy == nullptr) {
    *error_message = L"Endpoint policy target is invalid.";
    return false;
  }
  const auto contents = ReadUtf8File(policy_path);
  const auto parsed = contents ? ParseEndpointPolicy(*contents) : std::nullopt;
  if (!parsed) {
    *error_message = L"Endpoint policy is unreadable.";
    return false;
  }
  *policy = *parsed;
  return true;
}

bool ValidateEndpointDescriptor(const EndpointDescriptor& descriptor,
                                const EndpointPolicy& policy,
                                std::wstring* error_message) {
  // Report the exact failing check so deployments can be diagnosed remotely.
  if (descriptor.schema_version != 1) {
    *error_message = L"Protected endpoint descriptor schema is invalid.";
    return false;
  }
  if (policy.schema_version != 1) {
    *error_message = L"Protected endpoint policy schema is invalid.";
    return false;
  }
  if (descriptor.endpoint_version.empty() ||
      descriptor.endpoint_version != policy.endpoint_version) {
    *error_message = L"Protected endpoint version does not match the policy.";
    return false;
  }
  if (descriptor.protected_helper_path.filename() !=
          L"FlyNarwhalProtectedHelper.exe" ||
      descriptor.recovery_host_path.filename() !=
          L"FlyNarwhalRecoveryHost.exe" ||
      descriptor.policy_path.filename() != L"endpoint-policy.json") {
    *error_message = L"Protected endpoint file names are invalid.";
    return false;
  }
  if (descriptor.protected_helper_sha256.size() != 64 ||
      descriptor.recovery_host_sha256.size() != 64) {
    *error_message = L"Protected endpoint digests are malformed.";
    return false;
  }
  if (!IsPathUnderRoot(descriptor.protected_helper_path,
                       policy.protected_root) ||
      !IsPathUnderRoot(descriptor.recovery_host_path,
                       policy.protected_root)) {
    *error_message = L"Protected endpoint paths escape the protected root.";
    return false;
  }
  if (!PathsEqual(descriptor.policy_path, GetEndpointPolicyPath())) {
    *error_message = L"Protected endpoint policy path does not match.";
    return false;
  }
  if (!PathsEqual(policy.protected_root, GetProtectedEndpointRoot())) {
    *error_message = L"Protected endpoint root does not match.";
    return false;
  }
  if (HasReparsePointInExistingPath(policy.protected_root)) {
    *error_message = L"Protected endpoint root contains a reparse point.";
    return false;
  }
  if (!IsSafeRegularFileLocal(descriptor.protected_helper_path) ||
      !IsSafeRegularFileLocal(descriptor.recovery_host_path) ||
      !IsSafeRegularFileLocal(descriptor.policy_path) ||
      ComputeFileSha256(descriptor.protected_helper_path) !=
          descriptor.protected_helper_sha256 ||
      ComputeFileSha256(descriptor.recovery_host_path) !=
          descriptor.recovery_host_sha256) {
    *error_message = L"Protected endpoint files did not verify.";
    return false;
  }
  return true;
}

bool ValidateCurrentProtectedExecutable(const EndpointDescriptor& descriptor,
                                        const EndpointPolicy& policy,
                                        const std::filesystem::path& current_executable,
                                        const std::wstring& current_sha256,
                                        bool expect_recovery_host,
                                        const std::wstring& transaction_id,
                                        std::wstring* error_message) {
  const auto expected_registered_path = expect_recovery_host
                                            ? descriptor.recovery_host_path
                                            : descriptor.protected_helper_path;
  const auto expected_sha = expect_recovery_host
                                ? descriptor.recovery_host_sha256
                                : descriptor.protected_helper_sha256;
  const auto runtime_path =
      expect_recovery_host ? GetRecoveryRuntimePath(transaction_id)
                           : std::filesystem::path();
  const bool path_matches =
      PathsEqual(current_executable, expected_registered_path) ||
      (expect_recovery_host && PathsEqual(current_executable, runtime_path));
  if (!path_matches || current_sha256 != expected_sha ||
      !ValidateEndpointDescriptor(descriptor, policy, error_message)) {
    if (error_message->empty()) {
      *error_message = L"Protected endpoint identity is invalid.";
    }
    return false;
  }
  return true;
}

}  // namespace flynarwhal::install_helper

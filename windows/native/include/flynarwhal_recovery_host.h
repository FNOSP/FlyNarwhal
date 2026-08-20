#pragma once

#include <filesystem>
#include <string>

namespace flynarwhal::install_helper {

std::wstring BuildRecoveryTaskName(const std::wstring& transaction_id);
bool CreateRecoveryRuntimeCopy(const std::filesystem::path& source_path,
                               const std::wstring& expected_sha256,
                               const std::wstring& transaction_id,
                               std::filesystem::path* runtime_path,
                               std::wstring* error_message);
bool ArmRecoveryHostTask(const std::filesystem::path& runtime_path,
                         const std::wstring& transaction_id,
                         std::wstring* task_name,
                         std::wstring* error_message);
void DeleteRecoveryHostTask(const std::wstring& task_name);
int RunRecoveryHostResume(const std::wstring& transaction_id);

}  // namespace flynarwhal::install_helper

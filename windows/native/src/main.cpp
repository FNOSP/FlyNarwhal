#include "flynarwhal_install_helper.h"

#include <Windows.h>

#include <iostream>
#include <map>
#include <string>

namespace helper = flynarwhal::install_helper;

namespace {

std::map<std::wstring, std::wstring> ParseOptions(int argument_count,
                                                  wchar_t** arguments,
                                                  int first_option) {
  if ((argument_count - first_option) % 2 != 0) {
    return {};
  }
  std::map<std::wstring, std::wstring> options;
  for (int index = first_option; index + 1 < argument_count; index += 2) {
    const std::wstring name = arguments[index];
    if (name.rfind(L"--", 0) != 0 || options.count(name) != 0) {
      return {};
    }
    options.emplace(name, arguments[index + 1]);
  }
  return options;
}

bool ParseProcessId(const std::wstring& value, DWORD* process_id) {
  try {
    const unsigned long parsed = std::stoul(value);
    if (parsed == 0) {
      return false;
    }
    *process_id = static_cast<DWORD>(parsed);
    return true;
  } catch (...) {
    return false;
  }
}

bool ParseUnsignedLength(const std::wstring& value,
                         std::uint64_t* artifact_length) {
  try {
    const unsigned long long parsed = std::stoull(value);
    if (parsed == 0) {
      return false;
    }
    *artifact_length = static_cast<std::uint64_t>(parsed);
    return true;
  } catch (...) {
    return false;
  }
}

bool BuildBindings(const std::map<std::wstring, std::wstring>& options,
                   helper::RequestBindings* bindings) {
  const wchar_t* required_names[] = {
      L"--transaction-id", L"--stage", L"--provenance-sha256",
      L"--artifact-sha256", L"--artifact-length", L"--caller-pid",
      L"--caller-executable"};
  if (options.size() != std::size(required_names)) {
    return false;
  }
  for (const wchar_t* name : required_names) {
    if (options.count(name) != 1) {
      return false;
    }
  }

  bindings->transaction_id = options.at(L"--transaction-id");
  bindings->stage_path = options.at(L"--stage");
  bindings->stage_provenance_sha256 = options.at(L"--provenance-sha256");
  bindings->expected_artifact_sha256 = options.at(L"--artifact-sha256");
  bindings->caller_executable = options.at(L"--caller-executable");
  return ParseUnsignedLength(options.at(L"--artifact-length"),
                             &bindings->expected_artifact_length) &&
         ParseProcessId(options.at(L"--caller-pid"),
                        &bindings->caller_process_id);
}

void PrintUsage() {
  std::wcerr
      << L"Usage: FlyNarwhalInstallHelper.exe "
      << L"prepare|commit|query|recover|cancel|worker <sealed bindings>\n";
}

}  // namespace

int wmain(int argument_count, wchar_t** arguments) {
  if (argument_count < 2) {
    PrintUsage();
    return 64;
  }

  const std::wstring command = arguments[1];
  const auto options = ParseOptions(argument_count, arguments, 2);
  if (command == L"query" || command == L"recover" ||
      command == L"cancel") {
    if (options.size() != 1 || options.count(L"--transaction-id") != 1) {
      PrintUsage();
      return 64;
    }
    const std::wstring transaction_id = options.at(L"--transaction-id");
    if (command == L"query") {
      return helper::RunQuery(transaction_id);
    }
    if (command == L"recover") {
      return helper::RunRecover(transaction_id);
    }
    return helper::RunCancel(transaction_id);
  }

  helper::RequestBindings bindings;
  if (!BuildBindings(options, &bindings)) {
    PrintUsage();
    return 64;
  }
  if (command == L"prepare") {
    return helper::RunPrepare(bindings);
  }
  if (command == L"commit") {
    return helper::RunCommit(bindings);
  }
  if (command == L"worker") {
    return helper::RunWorker(bindings);
  }

  PrintUsage();
  return 64;
}

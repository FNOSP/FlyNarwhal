#include "flynarwhal_recovery_host.h"

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

void PrintUsage() {
  std::wcerr << L"Usage: FlyNarwhalRecoveryHost.exe resume --transaction-id <id>\n";
}

}  // namespace

int wmain(int argument_count, wchar_t** arguments) {
  if (argument_count < 4) {
    PrintUsage();
    return 64;
  }
  const std::wstring command = arguments[1];
  const auto options = ParseOptions(argument_count, arguments, 2);
  if (command != L"resume" || options.size() != 1 ||
      options.count(L"--transaction-id") != 1) {
    PrintUsage();
    return 64;
  }
  return helper::RunRecoveryHostResume(options.at(L"--transaction-id"));
}

#include "flynarwhal_install_helper.h"
#include "flynarwhal_updater_endpoint.h"

#include <Windows.h>

#include <iostream>
#include <string>
#include <vector>

namespace helper = flynarwhal::install_helper;

namespace {

bool ForwardCommandToProtectedHelper(const std::filesystem::path& executable,
                                     int argument_count,
                                     wchar_t** arguments,
                                     std::wstring* error_message) {
  std::wstring command_line = helper::QuoteWindowsArgument(executable.wstring());
  for (int index = 1; index < argument_count; ++index) {
    command_line += L' ';
    command_line += helper::QuoteWindowsArgument(arguments[index]);
  }
  STARTUPINFOW startup_info{};
  startup_info.cb = sizeof(startup_info);
  startup_info.dwFlags = STARTF_USESTDHANDLES;
  startup_info.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
  startup_info.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
  startup_info.hStdError = GetStdHandle(STD_ERROR_HANDLE);
  PROCESS_INFORMATION process_information{};
  if (!CreateProcessW(executable.c_str(), command_line.data(), nullptr, nullptr,
                      TRUE, 0, nullptr, nullptr, &startup_info,
                      &process_information)) {
    *error_message = L"Protected helper could not be started.";
    return false;
  }
  CloseHandle(process_information.hThread);
  WaitForSingleObject(process_information.hProcess, INFINITE);
  DWORD exit_code = 0;
  GetExitCodeProcess(process_information.hProcess, &exit_code);
  CloseHandle(process_information.hProcess);
  ExitProcess(exit_code);
}

void PrintUsage() {
  std::wcerr
      << L"Usage: FlyNarwhalInstallHelper.exe "
      << L"prepare|commit|query|recover|cancel <sealed bindings>\n";
}

}  // namespace

int wmain(int argument_count, wchar_t** arguments) {
  if (argument_count < 2) {
    PrintUsage();
    return 64;
  }
  // Attach a fresh update log so bootstrap failures are visible in release.
  helper::StartUpdateLogSession(helper::CreateUpdateLogPath());
  helper::LogInfo(std::wstring(L"Install helper bootstrap invoked with command: ") +
                  (argument_count > 1 ? arguments[1] : L"<none>"));
  std::wstring error;
  helper::EndpointDescriptor descriptor;
  helper::EndpointPolicy policy;
  if (!helper::ReadRegisteredEndpoint(&descriptor, &error) ||
      !helper::ReadEndpointPolicy(descriptor.policy_path, &policy, &error) ||
      !helper::ValidateEndpointDescriptor(descriptor, policy, &error)) {
    helper::LogError(
        std::wstring(L"Protected endpoint validation failed: ") +
        (error.empty() ? L"Protected endpoint is unavailable." : error));
    std::wcerr << (error.empty() ? L"Protected endpoint is unavailable." : error)
               << L'\n';
    return 2;
  }
  if (helper::GetCurrentExecutablePath().filename() !=
      L"FlyNarwhalInstallHelper.exe") {
    helper::LogError(L"Bootstrap executable identity is invalid.");
    std::wcerr << L"Bootstrap executable identity is invalid.\n";
    return 2;
  }
  if (!ForwardCommandToProtectedHelper(descriptor.protected_helper_path,
                                       argument_count, arguments, &error)) {
    helper::LogError(std::wstring(L"Forwarding to protected helper failed: ") +
                     error);
    std::wcerr << error << L'\n';
    return 2;
  }
  return 0;
}

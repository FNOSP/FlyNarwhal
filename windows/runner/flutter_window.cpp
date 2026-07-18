#include "flutter_window.h"

#include <windows.h>

#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr const char kWindowDisplayFrameChannelName[] =
    "fly_narwhal/window_display_frame";
constexpr const char kGetCurrentDisplayFrameMethod[] =
    "getCurrentDisplayFrame";
constexpr const char kSetWindowBorderlessMethod[] =
    "setWindowBorderless";
constexpr const char kIsWindowBorderlessMethod[] =
    "isWindowBorderless";
constexpr const char kKmpPreferencesChannelName[] =
    "fly_narwhal/kmp_preferences";
constexpr const char kReadJavaPreferencesMethod[] = "readJavaPreferences";
constexpr const wchar_t kJavaPreferencesRegistryPath[] =
    L"Software\\JavaSoft\\Prefs";

flutter::EncodableMap BuildDisplayFrameResponse(HWND window) {
  HMONITOR monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  if (monitor == nullptr) {
    throw std::runtime_error("Failed to resolve current monitor.");
  }

  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(MONITORINFO);
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    throw std::runtime_error("Failed to read monitor info.");
  }

  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale_factor = dpi > 0 ? static_cast<double>(dpi) / 96.0 : 1.0;
  const RECT frame = monitor_info.rcMonitor;

  flutter::EncodableMap response;
  response[flutter::EncodableValue("x")] =
      flutter::EncodableValue(frame.left / scale_factor);
  response[flutter::EncodableValue("y")] =
      flutter::EncodableValue(frame.top / scale_factor);
  response[flutter::EncodableValue("width")] =
      flutter::EncodableValue((frame.right - frame.left) / scale_factor);
  response[flutter::EncodableValue("height")] =
      flutter::EncodableValue((frame.bottom - frame.top) / scale_factor);
  return response;
}

bool IsWindowBorderless(HWND hwnd) {
  const LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
  const LONG_PTR framed_style =
      WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX |
      WS_MAXIMIZEBOX;
  return (style & framed_style) == 0;
}

void SetWindowBorderless(HWND hwnd, bool borderless) {
  LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
  if (borderless) {
    style &= ~(WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX |
               WS_MAXIMIZEBOX);
  } else {
    style |= WS_OVERLAPPEDWINDOW;
  }
  SetWindowLongPtr(hwnd, GWL_STYLE, style);
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOACTIVATE);
}

std::string Utf8FromWideString(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }
  const int required_size = WideCharToMultiByte(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  std::string result(required_size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(),
                      static_cast<int>(value.size()), result.data(),
                      required_size, nullptr, nullptr);
  return result;
}

std::string DecodeJavaPreferenceName(const std::wstring& encoded_name) {
  std::wstring decoded_name;
  bool uppercase_next = false;
  for (const wchar_t character : encoded_name) {
    if (character == L'/') {
      uppercase_next = true;
      continue;
    }
    if (uppercase_next && character >= L'a' && character <= L'z') {
      decoded_name.push_back(character - (L'a' - L'A'));
    } else {
      decoded_name.push_back(character);
    }
    uppercase_next = false;
  }
  return Utf8FromWideString(decoded_name);
}

flutter::EncodableMap ReadJavaPreferences() {
  HKEY preferences_key = nullptr;
  const LSTATUS open_status = RegOpenKeyExW(
      HKEY_CURRENT_USER, kJavaPreferencesRegistryPath, 0, KEY_READ,
      &preferences_key);
  if (open_status == ERROR_FILE_NOT_FOUND) {
    return flutter::EncodableMap();
  }
  if (open_status != ERROR_SUCCESS) {
    throw std::runtime_error("Unable to open Java Preferences Registry root.");
  }

  flutter::EncodableMap preferences;
  DWORD value_index = 0;
  while (true) {
    std::vector<wchar_t> value_name(256);
    DWORD value_name_length = static_cast<DWORD>(value_name.size());
    DWORD value_type = 0;
    DWORD value_size = 0;
    const LSTATUS query_status = RegEnumValueW(
        preferences_key, value_index, value_name.data(), &value_name_length,
        nullptr, &value_type, nullptr, &value_size);
    if (query_status == ERROR_NO_MORE_ITEMS) {
      break;
    }
    if (query_status == ERROR_MORE_DATA) {
      value_name.resize(value_name_length + 1);
      value_name_length = static_cast<DWORD>(value_name.size());
    } else if (query_status != ERROR_SUCCESS) {
      ++value_index;
      continue;
    }

    std::vector<BYTE> value_data(value_size + sizeof(wchar_t));
    const LSTATUS value_status = RegQueryValueExW(
        preferences_key, value_name.data(), nullptr, &value_type,
        value_data.data(), &value_size);
    if (value_status == ERROR_SUCCESS &&
        (value_type == REG_SZ || value_type == REG_EXPAND_SZ)) {
      const auto* value_text =
          reinterpret_cast<const wchar_t*>(value_data.data());
      const size_t value_length = value_size / sizeof(wchar_t);
      std::wstring wide_value(value_text, value_length);
      while (!wide_value.empty() && wide_value.back() == L'\0') {
        wide_value.pop_back();
      }
      const std::wstring wide_name(value_name.data(), value_name_length);
      preferences[flutter::EncodableValue(DecodeJavaPreferenceName(wide_name))] =
          flutter::EncodableValue(Utf8FromWideString(wide_value));
    }
    ++value_index;
  }
  RegCloseKey(preferences_key);
  return preferences;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  flutter::MethodChannel<> channel(
      flutter_controller_->engine()->messenger(),
      kWindowDisplayFrameChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == kGetCurrentDisplayFrameMethod) {
          try {
            result->Success(BuildDisplayFrameResponse(GetHandle()));
          } catch (const std::exception& exception) {
            result->Error("display-frame-error", exception.what());
          }
          return;
        }

        if (call.method_name() == kIsWindowBorderlessMethod) {
          result->Success(IsWindowBorderless(GetHandle()));
          return;
        }

        if (call.method_name() == kSetWindowBorderlessMethod) {
          const auto args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args == nullptr) {
            result->Error("INVALID_ARGS", "Expected a map argument.");
            return;
          }
          const auto it =
              args->find(flutter::EncodableValue("borderless"));
          if (it == args->end()) {
            result->Error("INVALID_ARGS", "Missing 'borderless' key.");
            return;
          }
          const auto value = std::get_if<bool>(&it->second);
          if (value == nullptr) {
            result->Error("INVALID_ARGS", "'borderless' must be a bool.");
            return;
          }

          try {
            SetWindowBorderless(GetHandle(), *value);
            result->Success();
          } catch (const std::exception& exception) {
            result->Error("borderless-error", exception.what());
          }
          return;
        }

        result->NotImplemented();
      });

  flutter::MethodChannel<> preferences_channel(
      flutter_controller_->engine()->messenger(), kKmpPreferencesChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  preferences_channel.SetMethodCallHandler(
      [](const flutter::MethodCall<>& call,
         std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() != kReadJavaPreferencesMethod) {
          result->NotImplemented();
          return;
        }
        try {
          result->Success(ReadJavaPreferences());
        } catch (const std::exception& exception) {
          result->Error("kmp-preferences-error", exception.what());
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
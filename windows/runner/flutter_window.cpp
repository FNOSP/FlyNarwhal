#include "flutter_window.h"

#include <optional>
#include <stdexcept>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr const char kWindowDisplayFrameChannelName[] =
    "fly_narwhal/window_display_frame";
constexpr const char kGetCurrentDisplayFrameMethod[] =
    "getCurrentDisplayFrame";
constexpr const char kSetWindowBorderlessMethod[] =
    "setWindowBorderless";

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

  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController*>(controller);
    auto* registry = flutter_view_controller->engine();
    RegisterPlugins(registry);
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
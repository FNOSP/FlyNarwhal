#include "flutter_window.h"

#include <windows.h>

#include <comdef.h>
#include <knownfolders.h>
#include <shlobj.h>
#include <shobjidl.h>

#include <cstdint>
#include <filesystem>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr const char kWindowDisplayFrameChannelName[] =
    "fly_narwhal/window_display_frame";
constexpr const char kGetCurrentDisplayFrameMethod[] =
    "getCurrentDisplayFrame";
constexpr const char kGetAllDisplaysMethod[] = "getAllDisplays";
constexpr const char kSetWindowBorderlessMethod[] =
    "setWindowBorderless";
constexpr const char kIsWindowBorderlessMethod[] =
    "isWindowBorderless";
constexpr const char kKmpPreferencesChannelName[] =
    "fly_narwhal/kmp_preferences";
constexpr const char kReadJavaPreferencesMethod[] = "readJavaPreferences";
constexpr const char kLocalSubtitlePickerChannelName[] =
    "fly_narwhal/local_subtitle_picker";
constexpr const char kOpenLocalSubtitlesMethod[] = "openLocalSubtitles";
constexpr const UINT kLocalSubtitlePickerResultMessage = WM_APP + 1;
constexpr const wchar_t kJavaPreferencesRegistryPath[] =
    L"Software\\JavaSoft\\Prefs";

std::string Utf8FromWideString(const std::wstring& value);
std::wstring WideStringFromUtf8(const std::string& value);

uint64_t HashUserGuid(const std::string& user_guid, uint64_t seed) {
  uint64_t hash = seed;
  for (const unsigned char character : user_guid) {
    hash ^= character;
    hash *= 1099511628211ULL;
  }
  return hash;
}

GUID BuildPickerClientGuid(const std::string& user_guid) {
  const uint64_t first_hash =
      HashUserGuid(user_guid, 1469598103934665603ULL);
  const uint64_t second_hash =
      HashUserGuid(user_guid, 1099511628211ULL);
  GUID client_guid = {};
  client_guid.Data1 = static_cast<unsigned long>(first_hash >> 32);
  client_guid.Data2 = static_cast<unsigned short>(first_hash >> 16);
  client_guid.Data3 = static_cast<unsigned short>(first_hash);
  for (size_t index = 0; index < 8; ++index) {
    client_guid.Data4[index] =
        static_cast<unsigned char>(second_hash >> ((7 - index) * 8));
  }
  client_guid.Data3 = static_cast<unsigned short>(
      (client_guid.Data3 & 0x0FFF) | 0x5000);
  client_guid.Data4[0] =
      static_cast<unsigned char>((client_guid.Data4[0] & 0x3F) | 0x80);
  return client_guid;
}

std::wstring BuildPickerRegistryPath(const std::string& user_guid) {
  const uint64_t user_hash =
      HashUserGuid(user_guid, 1469598103934665603ULL);
  wchar_t hash_text[17] = {};
  swprintf_s(hash_text, L"%016llX",
             static_cast<unsigned long long>(user_hash));
  return std::wstring(L"Software\\FlyNarwhal\\LocalSubtitlePicker\\") +
         hash_text;
}

std::optional<std::wstring> ReadLastPickerFolder(
    const std::string& user_guid) {
  HKEY user_key = nullptr;
  const std::wstring registry_path = BuildPickerRegistryPath(user_guid);
  if (RegOpenKeyExW(HKEY_CURRENT_USER, registry_path.c_str(), 0, KEY_READ,
                    &user_key) != ERROR_SUCCESS) {
    return std::nullopt;
  }

  DWORD value_type = 0;
  DWORD value_size = 0;
  if (RegQueryValueExW(user_key, L"LastFolder", nullptr, &value_type, nullptr,
                       &value_size) != ERROR_SUCCESS ||
      value_type != REG_SZ || value_size < sizeof(wchar_t)) {
    RegCloseKey(user_key);
    return std::nullopt;
  }

  std::vector<wchar_t> value(value_size / sizeof(wchar_t));
  if (RegQueryValueExW(user_key, L"LastFolder", nullptr, nullptr,
                       reinterpret_cast<BYTE*>(value.data()),
                       &value_size) != ERROR_SUCCESS) {
    RegCloseKey(user_key);
    return std::nullopt;
  }
  RegCloseKey(user_key);
  return std::wstring(value.data());
}

void SaveLastPickerFolder(const std::string& user_guid,
                          const std::wstring& folder_path) {
  HKEY user_key = nullptr;
  DWORD disposition = 0;
  const std::wstring registry_path = BuildPickerRegistryPath(user_guid);
  if (RegCreateKeyExW(HKEY_CURRENT_USER, registry_path.c_str(), 0, nullptr, 0,
                      KEY_WRITE, nullptr, &user_key,
                      &disposition) != ERROR_SUCCESS) {
    return;
  }
  const DWORD value_size = static_cast<DWORD>(
      (folder_path.size() + 1) * sizeof(wchar_t));
  RegSetValueExW(user_key, L"LastFolder", 0, REG_SZ,
                 reinterpret_cast<const BYTE*>(folder_path.c_str()),
                 value_size);
  RegCloseKey(user_key);
}

bool IsExistingDirectory(const std::filesystem::path& path) {
  std::error_code error;
  return std::filesystem::exists(path, error) &&
         std::filesystem::is_directory(path, error);
}

std::filesystem::path ResolveExistingPickerFolder(
    const std::optional<std::wstring>& stored_folder) {
  if (stored_folder.has_value() && !stored_folder->empty()) {
    std::filesystem::path candidate(*stored_folder);
    while (!candidate.empty()) {
      if (IsExistingDirectory(candidate)) {
        return candidate;
      }
      const std::filesystem::path parent = candidate.parent_path();
      if (parent == candidate) {
        break;
      }
      candidate = parent;
    }
  }

  wchar_t* profile_path = nullptr;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_Profile, KF_FLAG_DEFAULT,
                                     nullptr, &profile_path))) {
    const std::filesystem::path result(profile_path);
    CoTaskMemFree(profile_path);
    if (IsExistingDirectory(result)) {
      return result;
    }
  }
  return std::filesystem::current_path();
}

void SetPickerFolder(IFileDialog* dialog,
                     const std::filesystem::path& folder_path) {
  IShellItem* folder_item = nullptr;
  if (SUCCEEDED(SHCreateItemFromParsingName(folder_path.c_str(), nullptr,
                                            IID_PPV_ARGS(&folder_item)))) {
    dialog->SetFolder(folder_item);
    folder_item->Release();
  }
}

void SaveCurrentPickerFolder(IFileDialog* dialog,
                             const std::string& user_guid) {
  IShellItem* folder_item = nullptr;
  if (FAILED(dialog->GetFolder(&folder_item))) {
    return;
  }
  wchar_t* folder_path = nullptr;
  if (SUCCEEDED(folder_item->GetDisplayName(SIGDN_FILESYSPATH,
                                            &folder_path))) {
    SaveLastPickerFolder(user_guid, folder_path);
    CoTaskMemFree(folder_path);
  }
  folder_item->Release();
}

struct LocalSubtitlePickerResult {
  std::unique_ptr<flutter::MethodResult<>> method_result;
  std::vector<std::string> paths;
  std::string error_message;
};

std::vector<std::string> ShowLocalSubtitlePicker(
    HWND owner_window,
    const std::string& user_guid,
    std::string* error_message) {
  const HRESULT initialize_result =
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
  if (FAILED(initialize_result)) {
    *error_message = "Unable to initialize the Windows file picker thread.";
    return {};
  }

  IFileOpenDialog* dialog = nullptr;
  const HRESULT create_result = CoCreateInstance(
      CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER,
      IID_PPV_ARGS(&dialog));
  if (FAILED(create_result)) {
    CoUninitialize();
    *error_message = "Unable to create the Windows file picker.";
    return {};
  }

  const std::wstring subtitle_filter_label =
      L"\u5B57\u5E55\u6587\u4EF6";
  const std::wstring confirmation_label = L"\u9009\u62E9";

  const COMDLG_FILTERSPEC subtitle_filter = {
      subtitle_filter_label.c_str(), L"*.ass;*.srt;*.vtt;*.sub;*.ssa;*.sup"};
  const GUID client_guid = BuildPickerClientGuid(user_guid);
  dialog->SetClientGuid(client_guid);
  const std::filesystem::path initial_folder = ResolveExistingPickerFolder(
      ReadLastPickerFolder(user_guid));
  SetPickerFolder(dialog, initial_folder);
  dialog->SetFileTypes(1, &subtitle_filter);
  dialog->SetOkButtonLabel(confirmation_label.c_str());

  FILEOPENDIALOGOPTIONS options = 0;
  if (SUCCEEDED(dialog->GetOptions(&options))) {
    dialog->SetOptions(options | FOS_ALLOWMULTISELECT | FOS_FORCEFILESYSTEM |
                       FOS_PATHMUSTEXIST | FOS_FILEMUSTEXIST);
  }

  std::vector<std::string> paths;
  const HRESULT show_result = dialog->Show(owner_window);
  SaveCurrentPickerFolder(dialog, user_guid);
  if (SUCCEEDED(show_result)) {
    IShellItemArray* selected_items = nullptr;
    if (SUCCEEDED(dialog->GetResults(&selected_items))) {
      DWORD selected_item_count = 0;
      selected_items->GetCount(&selected_item_count);
      paths.reserve(selected_item_count);
      for (DWORD item_index = 0; item_index < selected_item_count;
           ++item_index) {
        IShellItem* selected_item = nullptr;
        if (FAILED(selected_items->GetItemAt(item_index, &selected_item))) {
          continue;
        }
        wchar_t* wide_path = nullptr;
        if (SUCCEEDED(selected_item->GetDisplayName(SIGDN_FILESYSPATH,
                                                    &wide_path))) {
          paths.push_back(Utf8FromWideString(wide_path));
          CoTaskMemFree(wide_path);
        }
        selected_item->Release();
      }
      selected_items->Release();
    }
  } else if (show_result != HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    *error_message = "The Windows file picker failed to open.";
  }

  dialog->Release();
  CoUninitialize();
  return paths;
}

flutter::EncodableMap BuildRectResponse(const RECT& bounds,
                                        double coordinate_scale_factor) {
  flutter::EncodableMap response;
  response[flutter::EncodableValue("x")] =
      flutter::EncodableValue(bounds.left / coordinate_scale_factor);
  response[flutter::EncodableValue("y")] =
      flutter::EncodableValue(bounds.top / coordinate_scale_factor);
  response[flutter::EncodableValue("width")] = flutter::EncodableValue(
      (bounds.right - bounds.left) / coordinate_scale_factor);
  response[flutter::EncodableValue("height")] = flutter::EncodableValue(
      (bounds.bottom - bounds.top) / coordinate_scale_factor);
  return response;
}

double GetWindowCoordinateScaleFactor(HWND window) {
  const HMONITOR monitor =
      MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  if (monitor == nullptr) {
    return 1.0;
  }
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  return dpi > 0 ? static_cast<double>(dpi) / 96.0 : 1.0;
}

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

  return BuildRectResponse(monitor_info.rcMonitor,
                           GetWindowCoordinateScaleFactor(window));
}

struct DisplayEnumerationContext {
  double coordinate_scale_factor;
  flutter::EncodableList displays;
};

BOOL CALLBACK CollectDisplay(HMONITOR monitor, HDC, LPRECT,
                             LPARAM context_value) {
  auto* context = reinterpret_cast<DisplayEnumerationContext*>(context_value);
  MONITORINFOEXW monitor_info = {};
  monitor_info.cbSize = sizeof(MONITORINFOEXW);
  if (!GetMonitorInfoW(monitor, &monitor_info)) {
    return TRUE;
  }

  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double display_scale_factor =
      dpi > 0 ? static_cast<double>(dpi) / 96.0 : 1.0;
  flutter::EncodableMap display;
  display[flutter::EncodableValue("id")] = flutter::EncodableValue(
      Utf8FromWideString(std::wstring(monitor_info.szDevice)));
  display[flutter::EncodableValue("monitorBounds")] = flutter::EncodableValue(
      BuildRectResponse(monitor_info.rcMonitor,
                        context->coordinate_scale_factor));
  display[flutter::EncodableValue("workArea")] = flutter::EncodableValue(
      BuildRectResponse(monitor_info.rcWork,
                        context->coordinate_scale_factor));
  display[flutter::EncodableValue("isPrimary")] = flutter::EncodableValue(
      (monitor_info.dwFlags & MONITORINFOF_PRIMARY) != 0);
  display[flutter::EncodableValue("scaleFactor")] =
      flutter::EncodableValue(display_scale_factor);
  context->displays.emplace_back(display);
  return TRUE;
}

flutter::EncodableList BuildAllDisplaysResponse(HWND window) {
  DisplayEnumerationContext context = {GetWindowCoordinateScaleFactor(window),
                                       flutter::EncodableList()};
  if (!EnumDisplayMonitors(nullptr, nullptr, CollectDisplay,
                           reinterpret_cast<LPARAM>(&context))) {
    throw std::runtime_error("Failed to enumerate displays.");
  }
  return context.displays;
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

std::wstring WideStringFromUtf8(const std::string& value) {
  if (value.empty()) {
    return L"";
  }
  const int required_size = MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      static_cast<int>(value.size()), nullptr, 0);
  if (required_size <= 0) {
    throw std::runtime_error("Unable to decode UTF-8 process argument.");
  }
  std::wstring result(required_size, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                      static_cast<int>(value.size()), result.data(),
                      required_size);
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

        if (call.method_name() == kGetAllDisplaysMethod) {
          try {
            result->Success(BuildAllDisplaysResponse(GetHandle()));
          } catch (const std::exception& exception) {
            result->Error("display-enumeration-error", exception.what());
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

  flutter::MethodChannel<> local_subtitle_picker_channel(
      flutter_controller_->engine()->messenger(),
      kLocalSubtitlePickerChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  local_subtitle_picker_channel.SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() != kOpenLocalSubtitlesMethod) {
          result->NotImplemented();
          return;
        }

        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (arguments == nullptr) {
          result->Error("INVALID_ARGS", "Expected a map argument.");
          return;
        }
        const auto user_guid_entry =
            arguments->find(flutter::EncodableValue("userGuid"));
        if (user_guid_entry == arguments->end()) {
          result->Error("INVALID_ARGS", "Missing userGuid.");
          return;
        }
        const auto* user_guid =
            std::get_if<std::string>(&user_guid_entry->second);
        if (user_guid == nullptr || user_guid->empty()) {
          result->Error("INVALID_ARGS", "userGuid must be non-empty.");
          return;
        }

        const HWND owner_window = GetHandle();
        std::thread([owner_window, user_guid = *user_guid,
                     method_result = std::move(result)]() mutable {
          auto picker_result = std::make_unique<LocalSubtitlePickerResult>();
          picker_result->method_result = std::move(method_result);
          picker_result->paths = ShowLocalSubtitlePicker(
              owner_window, user_guid, &picker_result->error_message);
          auto* message_payload = picker_result.release();
          if (!PostMessage(owner_window, kLocalSubtitlePickerResultMessage, 0,
                           reinterpret_cast<LPARAM>(message_payload))) {
            delete message_payload;
          }
        }).detach();
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
    case kLocalSubtitlePickerResultMessage: {
      std::unique_ptr<LocalSubtitlePickerResult> picker_result(
          reinterpret_cast<LocalSubtitlePickerResult*>(lparam));
      if (!picker_result->error_message.empty()) {
        picker_result->method_result->Error("local-subtitle-picker-error",
                                            picker_result->error_message);
        return 0;
      }
      flutter::EncodableList encoded_paths;
      encoded_paths.reserve(picker_result->paths.size());
      for (const std::string& path : picker_result->paths) {
        encoded_paths.emplace_back(path);
      }
      picker_result->method_result->Success(encoded_paths);
      return 0;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
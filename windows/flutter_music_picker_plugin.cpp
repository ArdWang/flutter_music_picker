#include "flutter_music_picker_plugin.h"

#include <windows.h>
#include <shlobj.h>
#include <shlwapi.h>
#include <propsys.h>
#include <propvarutil.h>
#include <propkey.h>
#include <mmsystem.h>

// Define PKEY_Media_Duration manually in case the SDK's propkey.h
// does not expose it (observed on some Windows SDK versions).
#ifndef PKEY_Media_Duration
DEFINE_PROPERTYKEY(PKEY_Media_Duration,
    0x64440490, 0x4C8B, 0x11D1, 0x8B, 0x70,
    0x08, 0x00, 0x36, 0xB1, 0x1A, 0x03, 3);
#endif

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <filesystem>
#include <memory>
#include <set>
#include <string>
#include <vector>

#pragma comment(lib, "winmm.lib")
#pragma comment(lib, "propsys.lib")
#pragma comment(lib, "shlwapi.lib")

namespace flutter_music_picker {

namespace fs = std::filesystem;

/// Recognized audio file extensions on Windows.
static const std::set<std::wstring> kAudioExtensions = {
    L"mp3", L"wav", L"aac", L"m4a", L"flac", L"ogg",
    L"wma", L"aiff", L"aif", L"caf", L"opus", L"mid",
    L"midi", L"asf", L"m4r"
};

// ------------------------------------------------------------------
// Duration extraction via Windows Shell Property System
// ------------------------------------------------------------------

/// Reads the audio duration from a file using the Windows property system.
///
/// Windows Explorer already extracts media metadata (including duration)
/// for common audio formats and stores it in the property store. This
/// function uses IShellItem2 to read the PKEY_Media_Duration property,
/// which is in 100-nanosecond units. Returns duration in milliseconds,
/// or 0 if the property is not available (e.g. unsupported format).
static int GetAudioDurationMs(const std::wstring& file_path) {
  // PKEY_Media_Duration is defined in propsys.h / propkey.h.
  // Duration value is in 100ns units (1 ms = 10000 units).
  IShellItem2* shell_item = nullptr;
  HRESULT hr = SHCreateItemFromParsingName(
      file_path.c_str(), nullptr, IID_PPV_ARGS(&shell_item));
  if (FAILED(hr) || shell_item == nullptr) {
    return 0;
  }

  ULONGLONG duration_100ns = 0;
  hr = shell_item->GetUInt64(PKEY_Media_Duration, &duration_100ns);
  shell_item->Release();

  if (FAILED(hr)) {
    return 0;  // Property not available for this file type
  }

  // Convert 100ns → milliseconds
  return static_cast<int>(duration_100ns / 10000ULL);
}

// ------------------------------------------------------------------
// Plugin registration
// ------------------------------------------------------------------

void FlutterMusicPickerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<FlutterMusicPickerPlugin>();

  // Create the method channel using the default StandardMethodCodec.
  // The channel must be stored as a member so the handler remains
  // registered for the plugin's lifetime.
  plugin->channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(),
          "com.rnd.flutter_music_picker/music_picker",
          &flutter::StandardMethodCodec::GetInstance());

  plugin->channel_->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterMusicPickerPlugin::FlutterMusicPickerPlugin()
    : audio_extensions_(kAudioExtensions) {}

FlutterMusicPickerPlugin::~FlutterMusicPickerPlugin() {
  StopRingtone();
}

void FlutterMusicPickerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto &method_name = method_call.method_name();

  if (method_name == "getMusicFiles") {
    auto result_list = flutter::EncodableList();

    // Scan user's Music folder (e.g. C:\Users\Name\Music)
    wchar_t user_music_path[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(
            nullptr, CSIDL_MYMUSIC, nullptr, 0, user_music_path))) {
      auto dir_items = ScanDirectory(user_music_path, false);
      result_list.insert(result_list.end(), dir_items.begin(), dir_items.end());
    }

    // Also scan the Public Music folder
    wchar_t public_path[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(
            nullptr, CSIDL_COMMON_MUSIC, nullptr, 0, public_path))) {
      auto dir_items = ScanDirectory(public_path, false);
      result_list.insert(result_list.end(), dir_items.begin(), dir_items.end());
    }

    result->Success(flutter::EncodableValue(result_list));

  } else if (method_name == "getRingtones") {
    auto result_list = flutter::EncodableList();

    // Windows stores system sounds in C:\Windows\Media
    wchar_t windows_dir[MAX_PATH];
    if (GetWindowsDirectoryW(windows_dir, MAX_PATH)) {
      std::wstring media_dir = std::wstring(windows_dir) + L"\\Media";
      auto dir_items = ScanDirectory(media_dir, true);
      result_list.insert(result_list.end(), dir_items.begin(), dir_items.end());
    }

    result->Success(flutter::EncodableValue(result_list));

  } else if (method_name == "playRingtone") {
    const auto* arguments =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      auto uri_it = arguments->find(flutter::EncodableValue("uri"));
      if (uri_it != arguments->end()) {
        const auto* path_ptr = std::get_if<std::string>(&uri_it->second);
        if (path_ptr) {
          int size = MultiByteToWideChar(CP_UTF8, 0, path_ptr->c_str(),
                                          -1, nullptr, 0);
          std::wstring wide_path(size, 0);
          MultiByteToWideChar(CP_UTF8, 0, path_ptr->c_str(),
                              -1, &wide_path[0], size);
          PlayRingtoneFile(wide_path);
        }
      }
    }
    result->Success(flutter::EncodableValue(true));

  } else if (method_name == "stopRingtone") {
    StopRingtone();
    result->Success(flutter::EncodableValue(true));

  } else {
    result->NotImplemented();
  }
}

std::vector<flutter::EncodableValue>
FlutterMusicPickerPlugin::ScanDirectory(
    const std::wstring& directory_path, bool is_ringtone) {
  std::vector<flutter::EncodableValue> items;

  std::error_code ec;
  if (!fs::exists(directory_path, ec) ||
      !fs::is_directory(directory_path, ec)) {
    return items;
  }

  int max_depth = 4;
  for (auto it = fs::recursive_directory_iterator(directory_path, ec);
       it != fs::recursive_directory_iterator(); ++it) {
    if (ec) break;

    if (it.depth() > max_depth) {
      it.pop();
      if (it == fs::recursive_directory_iterator()) break;
      continue;
    }

    if (!it->is_regular_file(ec)) continue;

    auto ext = it->path().extension().wstring();
    for (auto& c : ext) c = towlower(c);
    if (!ext.empty() && ext[0] == L'.') ext = ext.substr(1);

    if (audio_extensions_.find(ext) == audio_extensions_.end()) continue;

    auto file_size = it->file_size(ec);
    if (ec) file_size = 0;

    auto entry = BuildAudioFileEntry(
        it->path().wstring(), file_size, is_ringtone);
    items.push_back(std::move(entry));
  }

  return items;
}

flutter::EncodableValue FlutterMusicPickerPlugin::BuildAudioFileEntry(
    const std::wstring& file_path,
    uint64_t file_size,
    bool is_ringtone) {
  fs::path path(file_path);
  auto filename = path.stem().wstring();
  auto parent_dir = path.parent_path().filename().wstring();

  // Extract duration via the Windows Shell property system.
  // This reads the PKEY_Media_Duration that Explorer already computed.
  int duration_ms = GetAudioDurationMs(file_path);

  flutter::EncodableMap item;
  item[flutter::EncodableValue("id")] =
      flutter::EncodableValue(WideToUtf8(file_path));
  item[flutter::EncodableValue("title")] =
      flutter::EncodableValue(WideToUtf8(filename));
  item[flutter::EncodableValue("artist")] =
      flutter::EncodableValue(is_ringtone ? "System" : "Unknown");
  item[flutter::EncodableValue("album")] =
      flutter::EncodableValue(WideToUtf8(parent_dir));
  item[flutter::EncodableValue("durationMs")] =
      flutter::EncodableValue(duration_ms);
  item[flutter::EncodableValue("uri")] =
      flutter::EncodableValue(WideToUtf8(file_path));
  item[flutter::EncodableValue("sizeBytes")] =
      flutter::EncodableValue(static_cast<int>(file_size));
  item[flutter::EncodableValue("isRingtone")] =
      flutter::EncodableValue(is_ringtone);

  return flutter::EncodableValue(item);
}

// ------------------------------------------------------------------
// Ringtone Playback  --  Win32 PlaySound
// ------------------------------------------------------------------

void FlutterMusicPickerPlugin::PlayRingtoneFile(
    const std::wstring& file_path) {
  StopRingtone();
  PlaySoundW(file_path.c_str(), nullptr,
             SND_ASYNC | SND_FILENAME | SND_NODEFAULT);
}

void FlutterMusicPickerPlugin::StopRingtone() {
  PlaySoundW(nullptr, nullptr, 0);
}

std::string FlutterMusicPickerPlugin::WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return {};
  int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, wstr.c_str(), static_cast<int>(wstr.size()),
      nullptr, 0, nullptr, nullptr);
  std::string result(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(),
                      static_cast<int>(wstr.size()),
                      &result[0], size_needed, nullptr, nullptr);
  return result;
}

}  // namespace flutter_music_picker

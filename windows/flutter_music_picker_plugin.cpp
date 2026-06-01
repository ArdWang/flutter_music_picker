#include "flutter_music_picker_plugin.h"

#include <windows.h>
#include <shlobj.h>
#include <mmsystem.h>

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

namespace flutter_music_picker {

namespace fs = std::filesystem;

/// Recognized audio file extensions on Windows.
static const std::set<std::wstring> kAudioExtensions = {
    L"mp3", L"wav", L"aac", L"m4a", L"flac", L"ogg",
    L"wma", L"aiff", L"aif", L"caf", L"opus", L"mid",
    L"midi", L"asf", L"m4r"
};

// ------------------------------------------------------------------
// Plugin registration
// ------------------------------------------------------------------

void FlutterMusicPickerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<FlutterMusicPickerPlugin>();

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

    wchar_t user_music_path[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(
            nullptr, CSIDL_MYMUSIC, nullptr, 0, user_music_path))) {
      auto dir_items = ScanDirectory(user_music_path, false);
      result_list.insert(result_list.end(), dir_items.begin(), dir_items.end());
    }

    wchar_t public_path[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(
            nullptr, CSIDL_COMMON_MUSIC, nullptr, 0, public_path))) {
      auto dir_items = ScanDirectory(public_path, false);
      result_list.insert(result_list.end(), dir_items.begin(), dir_items.end());
    }

    result->Success(flutter::EncodableValue(result_list));

  } else if (method_name == "getRingtones") {
    auto result_list = flutter::EncodableList();

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

    // file_size from the directory entry (fast, no file open)
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

  // No Shell Property System call — durationMs = 0 to avoid main-thread blocking.
  // The audio player will provide the actual duration during playback.

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
      flutter::EncodableValue(0);
  item[flutter::EncodableValue("uri")] =
      flutter::EncodableValue(WideToUtf8(file_path));
  item[flutter::EncodableValue("sizeBytes")] =
      flutter::EncodableValue(static_cast<int>(file_size));
  item[flutter::EncodableValue("isRingtone")] =
      flutter::EncodableValue(is_ringtone);

  return flutter::EncodableValue(item);
}

// ------------------------------------------------------------------
// Ringtone Playback  --  Win32 PlaySound (only when user taps play)
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

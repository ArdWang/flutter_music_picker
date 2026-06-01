#include "flutter_music_picker_plugin.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_linux.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <set>
#include <signal.h>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace flutter_music_picker {

namespace fs = std::filesystem;

/// Recognized audio file extensions on Linux.
static const std::set<std::string> kAudioExtensions = {
    "mp3", "wav", "aac", "m4a", "flac", "ogg",
    "opus", "wma", "aiff", "aif", "caf", "mid",
    "midi", "spx", "oga", "m4r"
};

void FlutterMusicPickerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarLinux *registrar) {
  auto plugin = std::make_unique<FlutterMusicPickerPlugin>();

  // Create the method channel with the default StandardMethodCodec.
  // Stored as a member so the handler remains registered.
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

    const char *home_dir = getenv("HOME");
    if (home_dir == nullptr) home_dir = getenv("USERPROFILE");
    std::string home_path = home_dir ? home_dir : "/home";

    // ~/Music  --  the standard XDG music directory
    std::string music_dir = home_path + "/Music";
    auto music_items = ScanDirectory(music_dir, false);
    result_list.insert(
        result_list.end(), music_items.begin(), music_items.end());

    // ~/Downloads  --  commonly contains user audio
    std::string downloads_dir = home_path + "/Downloads";
    auto download_items = ScanDirectory(downloads_dir, false);
    result_list.insert(
        result_list.end(), download_items.begin(), download_items.end());

    result->Success(flutter::EncodableValue(result_list));

  } else if (method_name == "getRingtones") {
    auto result_list = flutter::EncodableList();

    // System sound directories across Linux distributions
    std::vector<std::string> sound_dirs = {
        "/usr/share/sounds",
        "/usr/share/sounds/alsa",
        "/usr/share/sounds/freedesktop/stereo",
        "/usr/share/sounds/freedesktop",
        "/usr/share/sounds/ubuntu/stereo",
        "/usr/share/sounds/freedesktop/stereo/alerts",
    };

    // Also check XDG data directories for sound themes
    const char *xdg_data_dirs = getenv("XDG_DATA_DIRS");
    if (xdg_data_dirs != nullptr) {
      std::string dirs_str(xdg_data_dirs);
      size_t pos = 0;
      while ((pos = dirs_str.find(':')) != std::string::npos) {
        std::string dir = dirs_str.substr(0, pos);
        sound_dirs.push_back(dir + "/sounds");
        dirs_str.erase(0, pos + 1);
      }
      sound_dirs.push_back(dirs_str + "/sounds");
    }

    for (const auto &dir : sound_dirs) {
      auto items = ScanDirectory(dir, true);
      result_list.insert(
          result_list.end(), items.begin(), items.end());
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
          PlayRingtoneFile(*path_ptr);
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
    const std::string& directory_path, bool is_ringtone) {
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

    std::string ext = it->path().extension().string();
    if (!ext.empty() && ext[0] == '.') ext = ext.substr(1);
    std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);

    if (audio_extensions_.find(ext) == audio_extensions_.end()) continue;

    auto file_size = static_cast<uint64_t>(it->file_size(ec));
    if (ec) file_size = 0;

    auto entry = BuildAudioFileEntry(
        it->path().string(), file_size, is_ringtone);
    items.push_back(std::move(entry));
  }

  return items;
}

flutter::EncodableValue FlutterMusicPickerPlugin::BuildAudioFileEntry(
    const std::string& file_path,
    uint64_t file_size,
    bool is_ringtone) {
  fs::path path(file_path);
  std::string filename = path.stem().string();
  std::string parent_dir = path.parent_path().filename().string();

  flutter::EncodableMap item;
  item[flutter::EncodableValue("id")] =
      flutter::EncodableValue(file_path);
  item[flutter::EncodableValue("title")] =
      flutter::EncodableValue(filename);
  item[flutter::EncodableValue("artist")] =
      flutter::EncodableValue(is_ringtone ? "System" : "Unknown");
  item[flutter::EncodableValue("album")] =
      flutter::EncodableValue(parent_dir);
  item[flutter::EncodableValue("durationMs")] =
      flutter::EncodableValue(0);
  item[flutter::EncodableValue("uri")] =
      flutter::EncodableValue(file_path);
  item[flutter::EncodableValue("sizeBytes")] =
      flutter::EncodableValue(static_cast<int>(file_size));
  item[flutter::EncodableValue("isRingtone")] =
      flutter::EncodableValue(is_ringtone);

  return flutter::EncodableValue(item);
}

// ------------------------------------------------------------------
// Ringtone Playback  --  fork + exec system audio player
// ------------------------------------------------------------------

void FlutterMusicPickerPlugin::PlayRingtoneFile(
    const std::string& file_path) {
  StopRingtone();

  if (!fs::exists(file_path)) return;

  pid_t pid = fork();

  if (pid == 0) {
    // Child: redirect output to /dev/null
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);

    // Try PulseAudio  ->  ALSA  ->  ffmpeg
    execlp("paplay", "paplay", file_path.c_str(), nullptr);
    execlp("aplay", "aplay", file_path.c_str(), nullptr);
    execlp("ffplay", "ffplay", "-nodisp", "-autoexit",
           file_path.c_str(), nullptr);
    _exit(0);
  } else if (pid > 0) {
    player_pid_ = pid;
  }
}

void FlutterMusicPickerPlugin::StopRingtone() {
  if (player_pid_ > 0) {
    kill(player_pid_, SIGTERM);
    waitpid(player_pid_, nullptr, WNOHANG);
    player_pid_ = -1;
  }
}

}  // namespace flutter_music_picker

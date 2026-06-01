## 0.0.2

- **Fixed**: web crash "Cannot set the method call handler before the binary messenger has been initialized" — `FlutterMusicPickerWeb.registerWith()` now passes `Registrar` (which implements `BinaryMessenger`) directly to `MethodChannel` constructor instead of relying on the default binary messenger
- **Fixed**: `_Ansi.reset` appearing as literal text in log output — Dart string interpolation `$_Ansi.reset` only captured `_Ansi` as identifier; changed to `${_Ansi.reset}`
- **Fixed**: web permission crash — `permission_handler` throws `UnimplementedError` on web for `Permission.audio`; added `on UnimplementedError` catch in example app
- **Fixed**: Windows `PKEY_Media_Duration` undeclared identifier — added `#include <propkey.h>` with manual `DEFINE_PROPERTYKEY` fallback for SDK compatibility
- **Fixed**: pubspec Flutter constraint upper bound removed (`>=3.32.7` instead of `>=3.32.7 <4.0.0`) per pub.dev requirement
- **Fixed**: homepage and repository URLs corrected to `https://github.com/ArdWang/flutter_music_picker`
- **Added**: `AppLogger` utility class with ANSI color-coded console output for debugging

## 0.0.1 — Initial release

- **Dart API**: `FlutterMusicPicker` class with `getMusicFiles()`, `getRingtones()`, `getAllAudioFiles()`, `playRingtone()`, `stopRingtone()` static methods
- **`MusicItem` data model** with properties: `id`, `title`, `artist`, `album`, `durationMs`, `uri`, `sizeBytes`, `isRingtone`, plus convenience getters `formattedDuration` and `formattedSize`
- **Type-safe parsing**: `MusicItem.fromMap()` handles values arriving as String, int, num, or bool — resilient to platform channel type variations
- **`MusicPickerException`**: typed exception with `message` and optional `code` for error handling

### Android
- Music: queries `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` and `INTERNAL_CONTENT_URI` with `IS_MUSIC = 1` filter
- Alerts: uses `RingtoneManager` (the official Android API) to discover system ringtones (`TYPE_RINGTONE`), notification sounds (`TYPE_NOTIFICATION`), and alarm tones (`TYPE_ALARM`)
- Ringtone URIs constructed correctly via `RingtoneManager.getRingtoneUri(position)` for cross-device compatibility
- Native ringtone playback via `RingtoneManager.getRingtone(context, uri).play()`
- `ApplicationContext`-compatible — no Activity reference needed
- Comprehensive `android.util.Log` debug logging for troubleshooting

### iOS
- Music: queries `MPMediaQuery.songs()` from the device music library with authorization check
- Alerts: scans `/Library/Ringtones` for `.m4r` files with a 45-name known-ringtone fallback list
- Ringtone preview via `AVAudioPlayer` with `AudioServicesPlaySystemSound` fallback
- `os_log` debug logging throughout

### macOS
- Music: scans `~/Music` and `~/Downloads` directories recursively for audio files
- Alerts: scans `/System/Library/Sounds`, `/Library/Sounds`, `~/Library/Sounds`, and `/Library/Ringtones`
- Duration extraction via `AVAsset`
- Ringtone preview via `AVAudioPlayer`
- `os_log` debug logging throughout

### Windows
- Music: scans user Music folder (`CSIDL_MYMUSIC`) and Public Music (`CSIDL_COMMON_MUSIC`)
- Alerts: scans `C:\Windows\Media` for system sound files
- Duration extraction via Windows Shell Property System (`IShellItem2` + `PKEY_Media_Duration`), with manual fallback definition for SDK compatibility
- Ringtone preview via Win32 `PlaySound()` API
- C API registration wrapper (`FlutterMusicPickerPluginCApiRegisterWithRegistrar`) using `extern "C"` linkage and `FLUTTER_PLUGIN_EXPORT` for DLL export
- `PluginRegistrarManager::GetRegistrar<PluginRegistrarWindows>()` bridge from C handle to C++ object
- `/utf-8` compiler flag for MSVC on Chinese Windows (code page 936)

### Linux
- Music: scans `~/Music` and `~/Downloads`
- Alerts: scans `/usr/share/sounds` plus XDG data directory sound themes
- Ringtone preview by forking `paplay` → `aplay` → `ffplay` (auto-fallback), with `SIGTERM` cleanup
- `StandardMethodCodec` (not `StandardCodecSerializer`) for Flutter 3.32+ compatibility

### Web
- Plugin registered via `flutter_web_plugins` with explicit `BinaryMessenger` from `Registrar`
- Returns sample data so the demo UI has content (browsers restrict filesystem access)
- Ringtone playback is a no-op on web

### Example app
- Tabbed UI: Music tab + Alerts tab with item counts
- `just_audio` integration for music playback with progress slider and play/pause/stop controls
- Native ringtone preview with auto-stop timer
- Runtime permission handling via `permission_handler` for Android (`Permission.audio` with `Permission.storage` fallback)
- Material Design 3 with light/dark mode support
- Now-playing bar and ringtone preview bar at the bottom of the screen
- Refresh button to reload music data

### Bug fixes included in this release
- Fixed Android ringtones returning empty: switched from raw MediaStore queries to `RingtoneManager` (the API used by system Settings)
- Fixed type mismatch crash: ringtone maps returned `String` values for `durationMs`/`sizeBytes`/`isRingtone` — now always `Int`/`Boolean`
- Fixed Android music queries: added `INTERNAL_CONTENT_URI` fallback for devices where music is on internal storage only
- Fixed Dart initialization: replaced unused top-level variable (optimized away by compiler) with `_ensureInitialized()` called before every method
- Fixed Windows build: `StandardCodecSerializer` → `StandardMethodCodec` for Flutter 3.32+ compatibility
- Fixed Windows build: removed `FLUTTER_PLUGIN_LIST` override from plugin CMakeLists (was corrupting CMake cache)
- Fixed Windows build: C4819 Unicode error by replacing em dashes/arrows with ASCII in C++ comments and adding `/utf-8` MSVC flag
- Fixed Windows build: added `extern "C"` C API wrapper accepting `FlutterDesktopPluginRegistrarRef`
- Fixed Linux build: same `StandardCodecSerializer` → `StandardMethodCodec` + `FLUTTER_PLUGIN_LIST` cleanup
- Fixed `MusicItem.fromMap` type safety: added `_parseInt()` / `_parseBool()` helpers handling String/int/num/bool inputs

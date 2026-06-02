# flutter_music_picker

A Flutter plugin that discovers and lists music files and alert tones (ringtones, notifications, alarms) on the device — across **Android, iOS, macOS, Windows, Linux, and Web**.

## Features

| Feature | Description |
|---------|------------|
| Music discovery | Lists all music tracks from the device's media library |
| Alert tone discovery | Lists system ringtones, notification sounds, and alarm tones |
| Native playback | Preview ringtones using native platform APIs (RingtoneManager on Android, AVAudioPlayer on iOS/macOS, PlaySound on Windows) |
| Duration extraction | Reads audio duration from file metadata on Windows (via Shell Property System), macOS (via AVAsset), and Android (via MediaStore) |
| Cross-platform | Single Dart API — works on Android, iOS, macOS, Windows, Linux, and Web |

## Platform Support

| Platform | Music Source | Alert Tone Source | Playback |
|----------|-------------|-------------------|----------|
| Android | MediaStore (`IS_MUSIC = 1`) | RingtoneManager (`TYPE_RINGTONE` / `TYPE_NOTIFICATION` / `TYPE_ALARM`) | `RingtoneManager.getRingtone().play()` |
| iOS | MPMediaQuery | `/Library/Ringtones` + known-name fallback | AVAudioPlayer |
| macOS | `~/Music` + `~/Downloads` scan | `/System/Library/Sounds` + `/Library/Ringtones` | AVAudioPlayer |
| Windows | `CSIDL_MYMUSIC` + `CSIDL_COMMON_MUSIC` scan | `C:\Windows\Media` scan | Win32 `PlaySound()` |
| Linux | `~/Music` + `~/Downloads` scan | `/usr/share/sounds` + XDG sound themes | `paplay` / `aplay` / `ffplay` |
| Web | Sample data | Sample data | No-op (browser sandbox) |

## Getting started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_music_picker: ^0.0.7
```

Then run:

```bash
flutter pub get
```

### Platform configuration

#### Android

Add these permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Android 13+ (API 33) -->
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
<!-- Android 12 and below -->
<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

Then request the permission at runtime (e.g. using the `permission_handler` package).

#### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSAppleMusicUsageDescription</key>
<string>This app needs access to your music library.</string>
```

#### macOS

Add to `macos/Runner/Info.plist`:

```xml
<key>NSAppleMusicUsageDescription</key>
<string>This app needs access to your music folder.</string>
```

No additional entitlements are needed — the plugin reads from standard directories.

#### Windows / Linux

No special configuration required. The plugin scans standard music directories.

## Usage

### Basic usage

```dart
import 'package:flutter_music_picker/flutter_music_picker.dart';

// Get all music files from the device
final musicFiles = await FlutterMusicPicker.getMusicFiles();

// Get all alert tones (ringtones + notifications + alarms)
final alerts = await FlutterMusicPicker.getRingtones();

// Get everything combined
final allAudio = await FlutterMusicPicker.getAllAudioFiles();
```

### Working with MusicItem

Each result is a `MusicItem` with the following properties:

```dart
for (final item in musicFiles) {
  print(item.title);            // "Bohemian Rhapsody"
  print(item.artist);           // "Queen"
  print(item.album);            // "A Night at the Opera"
  print(item.formattedDuration); // "5:55"
  print(item.formattedSize);     // "8.2 MB"
  print(item.uri);              // content://... or /path/to/file.mp3
  print(item.isRingtone);       // false
}
```

### Playing a music file

Use any audio player package (e.g. `just_audio`):

```dart
import 'package:just_audio/just_audio.dart';

final player = AudioPlayer();
final music = await FlutterMusicPicker.getMusicFiles();
if (music.isNotEmpty) {
  await player.setAudioSource(AudioSource.uri(Uri.parse(music[0].uri)));
  player.play();
}
```

### Previewing a ringtone / alert tone

Use the plugin's built-in native playback:

```dart
final alerts = await FlutterMusicPicker.getRingtones();

// Preview the first alert tone using native playback
if (alerts.isNotEmpty) {
  await FlutterMusicPicker.playRingtone(alerts[0].uri);
}

// Stop the preview when done
await FlutterMusicPicker.stopRingtone();
```

On Android, this uses `RingtoneManager.getRingtone()` which plays through the system ringtone audio channel. On iOS/macOS, it uses `AVAudioPlayer`. On Windows, `PlaySound`. On Linux, it spawns `paplay`/`aplay`.

### Error handling

```dart
try {
  final music = await FlutterMusicPicker.getMusicFiles();
} on MusicPickerException catch (e) {
  print('Failed: ${e.message} (code: ${e.code})');
}
```

### Runtime permission handling (Android)

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestAudioPermission() async {
  if (await Permission.audio.isGranted) return true;
  final result = await Permission.audio.request();
  if (result.isGranted) return true;
  // Fallback for older Android versions
  final storageResult = await Permission.storage.request();
  return storageResult.isGranted;
}
```

## MusicItem data model

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique identifier — MediaStore ID on Android, persistent ID on iOS, file path on desktop |
| `title` | `String` | Display title of the audio track |
| `artist` | `String` | Artist name ("Unknown" if unavailable) |
| `album` | `String` | Album name or category label |
| `durationMs` | `int` | Duration in milliseconds (0 if unavailable) |
| `uri` | `String` | Platform-specific URI — `content://` on Android, file path on desktop, empty on web |
| `sizeBytes` | `int` | File size in bytes (0 if unavailable) |
| `isRingtone` | `bool` | `true` for system alert tones, `false` for music tracks |
| `formattedDuration` | `String` | "3:42" style string |
| `formattedSize` | `String` | "4.2 MB" style string |

## API reference

### `FlutterMusicPicker`

| Method | Returns | Description |
|--------|---------|-------------|
| `getMusicFiles()` | `Future<List<MusicItem>>` | All music tracks on the device |
| `getRingtones()` | `Future<List<MusicItem>>` | All alert tones (ringtones, notifications, alarms) |
| `getAllAudioFiles()` | `Future<List<MusicItem>>` | Music + alert tones combined |
| `playRingtone(String uri)` | `Future<void>` | Preview a ringtone using native playback |
| `stopRingtone()` | `Future<void>` | Stop the current ringtone preview |
| `isSupported` | `bool` | Always `true` (all platforms supported with fallbacks) |

### `MusicPickerException`

Thrown when a platform query fails (permission denied, database error, etc.).

| Property | Type | Description |
|----------|------|-------------|
| `message` | `String` | Human-readable error description |
| `code` | `String?` | Platform error code |

## Complete example

See the `example/` directory for a fully functional demo app featuring:

- Tabbed UI (Music / Alerts)
- `just_audio` integration for music playback with seek control
- Native ringtone preview with play/stop buttons
- Runtime permission handling for Android
- Material Design 3 theming with light/dark mode support

## License

MIT

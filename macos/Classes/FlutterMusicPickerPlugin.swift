import Cocoa
import FlutterMacOS
import AVFoundation
import os.log

/// The macOS implementation of the flutter_music_picker plugin.
///
/// On macOS, this plugin scans standard music and sound directories to
/// discover audio files. Uses [AVAudioPlayer] for ringtone preview playback.
///
/// No special entitlements are required on macOS beyond standard
/// filesystem read access within the user's home directory.
public class FlutterMusicPickerPlugin: NSObject, FlutterPlugin {

    /// Audio player used for ringtone preview.
    private var audioPlayer: AVAudioPlayer?

    /// Logger for this plugin instance.
    private let log = OSLog(
        subsystem: "com.rnd.flutter_music_picker",
        category: "macOS"
    )

    /// Registers this plugin with the Flutter macOS engine.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.rnd.flutter_music_picker/music_picker",
            binaryMessenger: registrar.messenger
        )
        let instance = FlutterMusicPickerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        os_log("[MusicPicker] Plugin registered on macOS",
               log: instance.log, type: .info)
    }

    /// Handles method calls from Dart.
    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        os_log("[MusicPicker] -> %{public}@", log: log, type: .debug,
               call.method)
        switch call.method {
        case "getMusicFiles":
            let files = scanForMusicFiles()
            os_log("[MusicPicker] getMusicFiles <- %d items",
                   log: log, type: .info, files.count)
            result(files)
        case "getRingtones":
            let files = getSystemRingtones()
            os_log("[MusicPicker] getRingtones <- %d items",
                   log: log, type: .info, files.count)
            result(files)
        case "playRingtone":
            if let args = call.arguments as? [String: Any],
               let uri = args["uri"] as? String, !uri.isEmpty {
                os_log("[MusicPicker] playRingtone(uri: %{public}@)",
                       log: log, type: .debug, uri)
                playRingtone(uri: uri)
                result(true)
            } else {
                os_log("[MusicPicker] ERROR playRingtone: invalid or empty uri",
                       log: log, type: .error)
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Expected non-empty 'uri' argument",
                    details: nil
                ))
            }
        case "stopRingtone":
            os_log("[MusicPicker] stopRingtone", log: log, type: .debug)
            stopRingtone()
            result(true)
        default:
            os_log("[MusicPicker] WARN unimplemented method: %{public}@",
                   log: log, type: .default, call.method)
            result(FlutterMethodNotImplemented)
        }
    }

    // ------------------------------------------------------------------
    // Music Files
    // ------------------------------------------------------------------

    /// Recognized audio file extensions for music scanning.
    private let audioExtensions: Set<String> = [
        "mp3", "wav", "aac", "m4a", "flac", "ogg",
        "wma", "aiff", "aif", "caf", "alac", "opus"
    ]

    // ------------------------------------------------------------------
    // File Scanning
    // ------------------------------------------------------------------

    /// Scans the user's Music and Downloads directories for audio files.
    private func scanForMusicFiles() -> [[String: Any?]] {
        var items: [[String: Any?]] = []
        var searchDirs: [URL] = []

        let fileManager = FileManager.default

        if let musicDir = fileManager.urls(
            for: .musicDirectory, in: .userDomainMask
        ).first {
            searchDirs.append(musicDir)
        }
        if let downloadsDir = fileManager.urls(
            for: .downloadsDirectory, in: .userDomainMask
        ).first {
            searchDirs.append(downloadsDir)
        }

        os_log("[MusicPicker] Scanning %d music directories",
               log: log, type: .debug, searchDirs.count)

        for directory in searchDirs {
            os_log("[MusicPicker] Scanning: %{public}@",
                   log: log, type: .debug, directory.path)
            if let foundItems = scanDirectory(
                directory,
                extensions: audioExtensions,
                fileManager: fileManager
            ) {
                items.append(contentsOf: foundItems)
            } else {
                os_log("[MusicPicker] WARN Cannot enumerate: %{public}@",
                       log: log, type: .error, directory.path)
            }
        }

        return items
    }

    // ------------------------------------------------------------------
    // Ringtones
    // ------------------------------------------------------------------

    /// Directories known to contain ringtone (.m4r) files on macOS.
    private var ringtoneDirs: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Ringtones",
            "/Library/Ringtones",
            "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/Ringtones",
        ]
    }

    /// Enumerates all system ringtones by scanning known ringtone directories.
    ///
    /// Always includes a "None" entry as the first item so callers
    /// can offer a "no ringtone" choice.
    private func getSystemRingtones() -> [[String: Any?]] {
        var items: [[String: Any?]] = [
            [
                "id": "none",
                "title": "None",
                "artist": "",
                "album": "",
                "durationMs": 0,
                "uri": "",
                "sizeBytes": 0,
                "isRingtone": true
            ]
        ]

        let fm = FileManager.default
        var seenURIs = Set<String>()

        for dir in ringtoneDirs {
            guard let files = try? fm.contentsOfDirectory(atPath: dir) else {
                os_log("[MusicPicker] Cannot access ringtone dir: %{public}@",
                       log: log, type: .debug, dir)
                continue
            }
            os_log("[MusicPicker] Scanning ringtone dir: %{public}@ (%d entries)",
                   log: log, type: .debug, dir, files.count)
            for file in files where file.hasSuffix(".m4r") {
                let name = (file as NSString).deletingPathExtension
                let path = "\(dir)/\(file)"
                guard !seenURIs.contains(path) else { continue }
                seenURIs.insert(path)

                let item: [String: Any?] = [
                    "id": path,
                    "title": name,
                    "artist": "System",
                    "album": URL(fileURLWithPath: dir).lastPathComponent,
                    "durationMs": 0,
                    "uri": path,
                    "sizeBytes": 0,
                    "isRingtone": true
                ]
                items.append(item)
            }
        }

        os_log("[MusicPicker] Total ringtones found: %d (including None)",
               log: log, type: .info, items.count)
        return items
    }

    // ------------------------------------------------------------------
    // Directory Scanning
    // ------------------------------------------------------------------

    /// Recursively scans a directory for files with the given extensions.
    private func scanDirectory(
        _ directory: URL,
        extensions: Set<String>,
        fileManager: FileManager
    ) -> [[String: Any?]]? {
        var items: [[String: Any?]] = []

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, error in
                os_log("[MusicPicker] ERROR enumerating %{public}@: %{public}@",
                       log: OSLog(subsystem: "com.rnd.flutter_music_picker",
                                  category: "macOS"),
                       type: .error, url.path, error.localizedDescription)
                return true
            }
        ) else {
            os_log("[MusicPicker] ERROR Failed to create enumerator for: %{public}@",
                   log: log, type: .error, directory.path)
            return nil
        }

        for case let fileURL as URL in enumerator {
            let relativePath = fileURL.path.replacingOccurrences(
                of: directory.path, with: ""
            )
            if relativePath.components(separatedBy: "/").count > 8 {
                enumerator.skipDescendants()
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            guard extensions.contains(ext) else { continue }

            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let fileSize = (try? fileURL.resourceValues(
                forKeys: [.fileSizeKey]
            ))?.fileSize ?? 0

            let item: [String: Any?] = [
                "id": fileURL.path,
                "title": fileName,
                "artist": "Unknown",
                "album": fileURL.deletingLastPathComponent().lastPathComponent,
                "durationMs": 0,
                "uri": fileURL.path,
                "sizeBytes": 0,
                "isRingtone": false
            ]
            items.append(item)
        }

        os_log("[MusicPicker] Found %d audio files in %{public}@",
               log: log, type: .debug, items.count,
               directory.lastPathComponent)
        return items
    }

    // ------------------------------------------------------------------
    // Ringtone Playback
    // ------------------------------------------------------------------

    /// Plays a ringtone file using [AVAudioPlayer] with infinite loop.
    ///
    /// Stops any currently playing ringtone before starting a new one.
    /// Silently ignores empty URIs (the "None" selection).
    private func playRingtone(uri: String) {
        stopRingtone()

        guard !uri.isEmpty else {
            os_log("[MusicPicker] Skipping playback: empty URI (None selected)",
                   log: log, type: .debug)
            return
        }

        let url = URL(fileURLWithPath: uri)
        guard FileManager.default.fileExists(atPath: uri) else {
            os_log("[MusicPicker] ERROR Ringtone file not found: %{public}@",
                   log: log, type: .error, uri)
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
            os_log("[MusicPicker] Playing ringtone (loop): %{public}@",
                   log: log, type: .info, url.lastPathComponent)
        } catch {
            os_log("[MusicPicker] ERROR Cannot play %{public}@: %{public}@",
                   log: log, type: .error, url.lastPathComponent,
                   error.localizedDescription)
        }
    }

    /// Stops the currently playing ringtone preview.
    private func stopRingtone() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            os_log("[MusicPicker] Stopped ringtone playback",
                   log: log, type: .debug)
        }
        audioPlayer = nil
    }
}

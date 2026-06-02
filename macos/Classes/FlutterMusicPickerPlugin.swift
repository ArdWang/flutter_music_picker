import FlutterMacOS
import AVFoundation
import os.log

/// macOS implementation of flutter_music_picker.
///
/// Scans ~/Music and ~/Downloads directories recursively for audio files.
/// Scans /System/Library/Sounds, /Library/Sounds, ~/Library/Sounds,
/// and /Library/Ringtones for system sounds and ringtones.
///
/// No per-file blocking I/O — directory enumeration only.
public class FlutterMusicPickerPlugin: NSObject, FlutterPlugin {

    private var audioPlayer: AVAudioPlayer?

    private let log = OSLog(
        subsystem: "com.rnd.flutter_music_picker",
        category: "macOS"
    )

    private let audioExtensions = Set([
        "mp3", "wav", "aac", "aiff", "aif", "flac", "ogg", "wma",
        "m4a", "m4r", "caf", "alac", "opus"
    ])

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.rnd.flutter_music_picker/music_picker",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterMusicPickerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        os_log("[MusicPicker] Plugin registered on macOS",
               log: instance.log, type: .info)
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        os_log("[MusicPicker] -> %{public}@", log: log, type: .debug, call.method)
        switch call.method {
        case "getMusicFiles":
            let files = getMusicFiles()
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
                playRingtone(uri: uri)
                result(true)
            } else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Expected non-empty 'uri' argument",
                    details: nil
                ))
            }
        case "stopRingtone":
            stopRingtone()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ------------------------------------------------------------------
    // Music Files — file system scan (no per-file blocking I/O)
    // ------------------------------------------------------------------

    private func getMusicFiles() -> [[String: Any?]] {
        var items: [[String: Any?]] = []
        let fm = FileManager.default

        let musicPaths: [String] = [
            ("~/Music" as NSString).expandingTildeInPath,
            ("~/Downloads" as NSString).expandingTildeInPath,
        ]

        for dir in musicPaths {
            guard let enumerator = fm.enumerator(
                atPath: dir
            ) else { continue }

            for case let path as String in enumerator {
                let ext = (path as NSString).pathExtension.lowercased()
                guard audioExtensions.contains(ext) else { continue }

                let fullPath = "\(dir)/\(path)"
                let name = (path as NSString).lastPathComponent
                let title = (name as NSString).deletingPathExtension

                items.append([
                    "id": fullPath,
                    "title": title,
                    "artist": "Unknown",
                    "album": "Music",
                    "durationMs": 0,
                    "uri": fullPath,
                    "sizeBytes": 0,
                    "isRingtone": false
                ])
            }
        }

        return items
    }

    // ------------------------------------------------------------------
    // Ringtones — directory scan
    // ------------------------------------------------------------------

    private func getSystemRingtones() -> [[String: Any?]] {
        var items: [[String: Any?]] = [
            ["id": "none", "title": "None", "artist": "", "album": "",
             "durationMs": 0, "uri": "", "sizeBytes": 0, "isRingtone": true]
        ]

        let fm = FileManager.default

        let soundDirs = [
            "/System/Library/Sounds",
            "/Library/Sounds",
            ("~/Library/Sounds" as NSString).expandingTildeInPath,
            "/Library/Ringtones",
        ]

        let soundExtensions = Set(["aiff", "aif", "wav", "mp3", "m4r", "caf"])

        for dir in soundDirs {
            guard let files = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for file in files {
                let ext = (file as NSString).pathExtension.lowercased()
                guard soundExtensions.contains(ext) else { continue }
                let name = (file as NSString).deletingPathExtension
                let path = "\(dir)/\(file)"
                items.append([
                    "id": path,
                    "title": name,
                    "artist": "System",
                    "album": "Alerts",
                    "durationMs": 0,
                    "uri": path,
                    "sizeBytes": 0,
                    "isRingtone": true
                ])
            }
        }

        os_log("[MusicPicker] Total ringtones: %d (including None)",
               log: log, type: .info, items.count)
        return items
    }

    // ------------------------------------------------------------------
    // Ringtone Playback — AVAudioPlayer (macOS, no audio session)
    // ------------------------------------------------------------------

    private func playRingtone(uri: String) {
        stopRingtone()
        guard !uri.isEmpty else { return }
        let url = URL(fileURLWithPath: uri)
        guard FileManager.default.fileExists(atPath: uri) else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            os_log("[MusicPicker] ERROR Cannot play: %{public}@",
                   log: log, type: .error, error.localizedDescription)
        }
    }

    private func stopRingtone() {
        if audioPlayer?.isPlaying == true { audioPlayer?.stop() }
        audioPlayer = nil
    }
}

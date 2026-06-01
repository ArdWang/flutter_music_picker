import Cocoa
import FlutterMacOS
import AVFoundation

/// The macOS implementation of the flutter_music_picker plugin.
///
/// On macOS, this plugin scans standard music and sound directories to
/// discover audio files. Uses [AVAsset] to estimate audio durations and
/// [AVAudioPlayer] for ringtone preview playback.
///
/// No special entitlements are required on macOS beyond standard
/// filesystem read access within the user's home directory.
public class FlutterMusicPickerPlugin: NSObject, FlutterPlugin {

    /// Audio player used for ringtone preview.
    private var audioPlayer: AVAudioPlayer?

    /// Registers this plugin with the Flutter macOS engine.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.rnd.flutter_music_picker/music_picker",
            binaryMessenger: registrar.messenger
        )
        let instance = FlutterMusicPickerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    /// Handles method calls from Dart.
    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "getMusicFiles":
            result(scanForAudioFiles(includeRingtones: false))
        case "getRingtones":
            result(scanForAudioFiles(includeRingtones: true))
        case "playRingtone":
            if let args = call.arguments as? [String: Any],
               let uri = args["uri"] as? String {
                playRingtone(filePath: uri)
                result(true)
            } else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "Expected 'uri' argument",
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

    /// Recognized audio file extensions.
    private let audioExtensions: Set<String> = [
        "mp3", "wav", "aac", "m4a", "flac", "ogg",
        "wma", "aiff", "aif", "caf", "alac", "opus", "m4r"
    ]

    // ------------------------------------------------------------------
    // File Scanning
    // ------------------------------------------------------------------

    /// Scans known directories for audio files.
    ///
    /// When [includeRingtones] is false, scans the user's Music directory.
    /// When true, scans system sound directories for ringtone-like files.
    private func scanForAudioFiles(includeRingtones: Bool) -> [[String: Any?]] {
        var items: [[String: Any?]] = []
        var searchDirs: [URL] = []

        let fileManager = FileManager.default

        if includeRingtones {
            // System-level sound directories on macOS
            searchDirs.append(URL(fileURLWithPath: "/System/Library/Sounds"))
            searchDirs.append(URL(fileURLWithPath: "/Library/Sounds"))
            searchDirs.append(
                fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Sounds")
            )
            // Also check /Library/Ringtones if it exists
            let ringtonesDir = URL(fileURLWithPath: "/Library/Ringtones")
            if fileManager.fileExists(atPath: ringtonesDir.path) {
                searchDirs.append(ringtonesDir)
            }
        } else {
            // User's Music directory
            if let musicDir = fileManager.urls(
                for: .musicDirectory, in: .userDomainMask
            ).first {
                searchDirs.append(musicDir)
            }
            // Downloads — often contains user audio
            if let downloadsDir = fileManager.urls(
                for: .downloadsDirectory, in: .userDomainMask
            ).first {
                searchDirs.append(downloadsDir)
            }
        }

        for directory in searchDirs {
            if let foundItems = scanDirectory(
                directory,
                isRingtone: includeRingtones,
                fileManager: fileManager
            ) {
                items.append(contentsOf: foundItems)
            }
        }

        return items
    }

    /// Recursively scans a directory for audio files.
    private func scanDirectory(
        _ directory: URL,
        isRingtone: Bool,
        fileManager: FileManager
    ) -> [[String: Any?]]? {
        var items: [[String: Any?]] = []

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .isDirectoryKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            // Limit scan depth to avoid excessive traversal
            let relativePath = fileURL.path.replacingOccurrences(
                of: directory.path, with: ""
            )
            let depth = relativePath.split(separator: "/").count
            if depth > 4 { continue }

            guard let resourceValues = try? fileURL.resourceValues(
                forKeys: [.isDirectoryKey]
            ), resourceValues.isDirectory == false else {
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            guard audioExtensions.contains(ext) else { continue }

            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let fileSize = (try? fileURL.resourceValues(
                forKeys: [.fileSizeKey]
            )).fileSize ?? 0

            let item: [String: Any?] = [
                "id": fileURL.path,
                "title": fileName,
                "artist": isRingtone ? "System" : "Unknown",
                "album": fileURL.deletingLastPathComponent().lastPathComponent,
                "durationMs": estimateDuration(for: fileURL),
                "uri": fileURL.path,
                "sizeBytes": fileSize,
                "isRingtone": isRingtone
            ]
            items.append(item)
        }

        return items
    }

    // ------------------------------------------------------------------
    // Duration Estimation
    // ------------------------------------------------------------------

    /// Estimates the duration of an audio file using AVFoundation.
    private func estimateDuration(for fileURL: URL) -> Int {
        let asset = AVAsset(url: fileURL)
        let duration = asset.duration
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite else { return 0 }
        return Int(seconds * 1000)
    }

    // ------------------------------------------------------------------
    // Ringtone Playback
    // ------------------------------------------------------------------

    /// Plays an audio file at the given path using AVAudioPlayer.
    ///
    /// - Parameter filePath: Absolute path to the audio file.
    private func playRingtone(filePath: String) {
        stopRingtone()

        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            // Playback is best-effort; file may be unplayable
            print("flutter_music_picker: Failed to play \(filePath): \(error)")
        }
    }

    /// Stops the current ringtone preview.
    private func stopRingtone() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

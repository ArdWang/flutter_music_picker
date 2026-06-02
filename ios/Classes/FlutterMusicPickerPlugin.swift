import Flutter
import MediaPlayer
import AVFoundation
import os.log

/// iOS implementation of flutter_music_picker.
///
/// Uses MPMediaQuery to query the device music library (in-memory
/// database query, no disk I/O). Lists ringtones from /Library/Ringtones.
///
/// ## Permissions
///
/// Add to Info.plist:
/// ```
/// <key>NSAppleMusicUsageDescription</key>
/// <string>This app needs access to your music library.</string>
/// ```
public class FlutterMusicPickerPlugin: NSObject, FlutterPlugin {

    private var audioPlayer: AVAudioPlayer?

    private let log = OSLog(
        subsystem: "com.rnd.flutter_music_picker",
        category: "iOS"
    )

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.rnd.flutter_music_picker/music_picker",
            binaryMessenger: registrar.messenger
        )
        let instance = FlutterMusicPickerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        os_log("[MusicPicker] Plugin registered on iOS",
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
    // Music Files — MPMediaQuery (in-memory DB, no disk I/O)
    // ------------------------------------------------------------------

    private func getMusicFiles() -> [[String: Any?]] {
        var items: [[String: Any?]] = []

        let authStatus = MPMediaLibrary.authorizationStatus()
        guard authStatus == .authorized else {
            os_log("[MusicPicker] WARN Media library not authorized (status: %d)",
                   log: log, type: .error, authStatus.rawValue)
            return items
        }

        let query = MPMediaQuery.songs()
        guard let collections = query.items else { return items }

        for mediaItem in collections {
            items.append([
                "id": mediaItem.persistentID.description,
                "title": mediaItem.title ?? "Unknown",
                "artist": mediaItem.artist ?? "Unknown",
                "album": mediaItem.albumTitle ?? "Unknown",
                "durationMs": Int(mediaItem.playbackDuration * 1000),
                "uri": mediaItem.assetURL?.absoluteString ?? "",
                "sizeBytes": 0,
                "isRingtone": false
            ])
        }

        return items
    }

    // ------------------------------------------------------------------
    // Ringtones
    // ------------------------------------------------------------------

    private let ringtoneDir = "/Library/Ringtones"

    private let knownRingtones = [
        "Opening", "Marimba", "Ascending", "Bark", "Bell Tower",
        "Blues", "Boing", "Bulletin", "By The Seaside", "Chimes",
        "Circuit", "Constellation", "Cosmic", "Crystals", "Daybreak",
        "Departure", "Duck", "Electronic", "Explore", "Glockenspiel",
        "Harp", "Hillside", "Illuminate", "Night Owl", "Old Phone",
        "Pinball", "Playtime", "Presto", "Radar", "Radiate",
        "Ripples", "Sencha", "Signal", "Silk", "Slow Rise",
        "Stargaze", "Storytime", "Summit", "Tease", "Time Passing",
        "Trill", "Tweet", "Uplift", "Waves", "Xylophone",
    ]

    private func getSystemRingtones() -> [[String: Any?]] {
        var items: [[String: Any?]] = [
            ["id": "none", "title": "None", "artist": "", "album": "",
             "durationMs": 0, "uri": "", "sizeBytes": 0, "isRingtone": true]
        ]

        let fm = FileManager.default
        var seen = Set<String>()

        if let files = try? fm.contentsOfDirectory(atPath: ringtoneDir) {
            for file in files where file.hasSuffix(".m4r") {
                let name = (file as NSString).deletingPathExtension
                let path = "\(ringtoneDir)/\(file)"
                guard !seen.contains(path) else { continue }
                seen.insert(path)
                items.append([
                    "id": path, "title": name, "artist": "System",
                    "album": "Alerts", "durationMs": 0, "uri": path,
                    "sizeBytes": 0, "isRingtone": true
                ])
            }
        }

        if items.count <= 1 {
            for name in knownRingtones {
                let path = "\(ringtoneDir)/\(name).m4r"
                guard !seen.contains(path) else { continue }
                seen.insert(path)
                items.append([
                    "id": path, "title": name, "artist": "System",
                    "album": "Alerts", "durationMs": 0, "uri": path,
                    "sizeBytes": 0, "isRingtone": true
                ])
            }
        }

        os_log("[MusicPicker] Total ringtones: %d (including None)",
               log: log, type: .info, items.count)
        return items
    }

    // ------------------------------------------------------------------
    // Ringtone Playback — AVAudioPlayer
    // ------------------------------------------------------------------

    private func playRingtone(uri: String) {
        stopRingtone()
        guard !uri.isEmpty else { return }
        let url = URL(fileURLWithPath: uri)
        guard FileManager.default.fileExists(atPath: uri) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
        } catch {
            os_log("[MusicPicker] ERROR Cannot play: %{public}@",
                   log: log, type: .error, error.localizedDescription)
        }
    }

    private func stopRingtone() {
        if audioPlayer?.isPlaying == true { audioPlayer?.stop() }
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation)
    }
}

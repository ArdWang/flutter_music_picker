import Flutter
import MediaPlayer
import AVFoundation
import os.log

/// The iOS implementation of the flutter_music_picker plugin.
///
/// Uses [MPMediaQuery] to query the device's music library and scans
/// the system ringtones directory for available ringtone files.
///
/// ## Permissions
///
/// Add to Info.plist:
/// ```
/// <key>NSAppleMusicUsageDescription</key>
/// <string>This app needs access to your music library.</string>
/// ```
public class FlutterMusicPickerPlugin: NSObject, FlutterPlugin {

    /// The current audio player used for ringtone preview playback.
    private var audioPlayer: AVAudioPlayer?

    /// Logger for this plugin instance.
    private let log = OSLog(
        subsystem: "com.rnd.flutter_music_picker",
        category: "iOS"
    )

    /// Registers this plugin with the Flutter engine.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.rnd.flutter_music_picker/music_picker",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterMusicPickerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        os_log("[MusicPicker] Plugin registered on iOS",
               log: instance.log, type: .info)
    }

    /// Dispatches method calls from Dart to the appropriate handler.
    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        os_log("[MusicPicker] → %{public}@", log: log, type: .debug,
               call.method)
        switch call.method {
        case "getMusicFiles":
            let files = getMusicFiles()
            os_log("[MusicPicker] getMusicFiles ← %d items",
                   log: log, type: .info, files.count)
            result(files)
        case "getRingtones":
            let files = getSystemRingtones()
            os_log("[MusicPicker] getRingtones ← %d items",
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
    // Music Files — MPMediaQuery
    // ------------------------------------------------------------------

    /// Queries the device's music library for all songs.
    ///
    /// Uses [MPMediaQuery.songs] to list all tracks. The authorization
    /// status is checked; if denied, an empty list is returned.
    private func getMusicFiles() -> [[String: Any?]] {
        var items: [[String: Any?]] = []

        let authStatus = MPMediaLibrary.authorizationStatus()
        guard authStatus == .authorized else {
            os_log("[MusicPicker] WARN Media library not authorized (status: %d). Add NSAppleMusicUsageDescription to Info.plist",
                   log: log, type: .error, authStatus.rawValue)
            return items
        }

        let query = MPMediaQuery.songs()
        guard let collections = query.items else {
            os_log("[MusicPicker] WARN No songs found in media library",
                   log: log, type: .default)
            return items
        }

        os_log("[MusicPicker] Processing %d songs from media library...",
               log: log, type: .debug, collections.count)

        for mediaItem in collections {
            let item: [String: Any?] = [
                "id": mediaItem.persistentID.description,
                "title": mediaItem.title ?? "Unknown",
                "artist": mediaItem.artist ?? "Unknown",
                "album": mediaItem.albumTitle ?? "Unknown",
                "durationMs": Int(mediaItem.playbackDuration * 1000),
                "uri": mediaItem.assetURL?.absoluteString ?? "",
                "sizeBytes": 0,
                "isRingtone": false
            ]
            items.append(item)
        }

        os_log("[MusicPicker] Collected %d music items from library",
               log: log, type: .info, items.count)
        return items
    }

    // ------------------------------------------------------------------
    // Ringtones — File-system scan with known-name fallback
    // ------------------------------------------------------------------

    /// The system ringtones directory on iOS.
    private let ringtoneDir = "/Library/Ringtones"

    /// Well-known iOS system ringtone names.
    /// Used as a fallback when the ringtone directory cannot be listed.
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

    /// Enumerates all system ringtones using a 3-tier strategy:
    ///
    /// 1. Try to list the contents of `/Library/Ringtones` directly.
    /// 2. If listing fails (sandbox), check each known name with `fileExists`.
    /// 3. If even that fails, return placeholder URIs so the UI still works.
    ///
    /// Always includes a "None" entry as the first item.
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

        // Tier 1 — try to list the directory
        if let files = try? fm.contentsOfDirectory(atPath: ringtoneDir) {
            os_log("[MusicPicker] Listing %{public}@: %d entries",
                   log: log, type: .debug, ringtoneDir, files.count)
            for file in files where file.hasSuffix(".m4r") {
                let name = (file as NSString).deletingPathExtension
                let path = "\(ringtoneDir)/\(file)"
                guard !seenURIs.contains(path) else { continue }
                seenURIs.insert(path)
                items.append(makeRingtoneItem(name: name, path: path))
            }
        }

        // Tier 2 — file-exists check for known names
        if items.count <= 1 {
            os_log("[MusicPicker] Directory listing returned empty, checking known names...",
                   log: log, type: .debug)
            for name in knownRingtones {
                let path = "\(ringtoneDir)/\(name).m4r"
                guard !seenURIs.contains(path) else { continue }
                if fm.fileExists(atPath: path) {
                    seenURIs.insert(path)
                    items.append(makeRingtoneItem(name: name, path: path))
                }
            }
        }

        // Tier 3 — placeholder URIs (file may not be readable, but UI needs entries)
        if items.count <= 1 {
            os_log("[MusicPicker] Still no ringtones found, returning placeholders for %d known names",
                   log: log, type: .debug, knownRingtones.count)
            for name in knownRingtones {
                let path = "\(ringtoneDir)/\(name).m4r"
                guard !seenURIs.contains(path) else { continue }
                seenURIs.insert(path)
                items.append(makeRingtoneItem(name: name, path: path))
            }
        }

        os_log("[MusicPicker] Total ringtones: %d (including None)",
               log: log, type: .info, items.count)
        return items
    }

    /// Builds a single ringtone map entry.
    private func makeRingtoneItem(name: String, path: String) -> [String: Any?] {
        let fileSize: Int
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
            fileSize = (attrs[.size] as? Int) ?? 0
        } else {
            fileSize = 0
        }
        let url = URL(fileURLWithPath: path)
        return [
            "id": path,
            "title": name,
            "artist": "System",
            "album": "Ringtones",
            "durationMs": estimateDuration(for: url),
            "uri": path,
            "sizeBytes": fileSize,
            "isRingtone": true
        ]
    }

    /// Estimates the duration of an audio file using AVAsset.
    private func estimateDuration(for fileURL: URL) -> Int {
        let asset = AVAsset(url: fileURL)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else {
            return 0
        }
        return Int(seconds * 1000)
    }

    // ------------------------------------------------------------------
    // Ringtone Playback — AVAudioPlayer with AVAudioSession
    // ------------------------------------------------------------------

    /// Plays a system ringtone sound using [AVAudioPlayer].
    ///
    /// Configures the [AVAudioSession] for playback and loops the
    /// ringtone indefinitely (matching the alarm preview behavior
    /// of the system ringtone picker).
    ///
    /// - Parameter uri: Full path to the .m4r ringtone file.
    private func playRingtone(uri: String) {
        stopRingtone()

        guard !uri.isEmpty else {
            os_log("[MusicPicker] Skipping playback: empty URI",
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
            try AVAudioSession.sharedInstance().setCategory(
                .playback, options: []
            )
            try AVAudioSession.sharedInstance().setActive(true)

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

    /// Stops the currently playing ringtone preview and deactivates
    /// the audio session.
    private func stopRingtone() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            os_log("[MusicPicker] Stopped ringtone playback",
                   log: log, type: .debug)
        }
        audioPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }
}

import Flutter
import MediaPlayer
import AVFoundation
import UIKit

/// The iOS implementation of the flutter_music_picker plugin.
///
/// Uses [MPMediaQuery] to query the device's music library and provides
/// ringtone identifiers. On iOS, ringtone access is restricted; we return
/// known system ringtone identifiers.
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

    /// Registers this plugin with the Flutter engine.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.rnd.flutter_music_picker/music_picker",
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterMusicPickerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    /// Dispatches method calls from Dart to the appropriate handler.
    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "getMusicFiles":
            result(getMusicFiles())
        case "getRingtones":
            result(getRingtones())
        case "playRingtone":
            if let args = call.arguments as? [String: Any],
               let uri = args["uri"] as? String {
                playRingtone(uri: uri)
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

    // ------------------------------------------------------------------
    // Music Files — MPMediaQuery
    // ------------------------------------------------------------------

    /// Queries the device's music library for all songs.
    ///
    /// Uses [MPMediaQuery.songs] to list all tracks. The authorization
    /// status is checked implicitly; if the user denied access, an empty
    /// list is returned.
    ///
    /// - Returns: Array of dictionaries, each representing one music track.
    private func getMusicFiles() -> [[String: Any?]] {
        var items: [[String: Any?]] = []

        // Check authorization status before querying
        let authStatus = MPMediaLibrary.authorizationStatus()
        guard authStatus == .authorized else {
            // If not authorized, return empty list; the example app
            // should request authorization via Info.plist
            return items
        }

        let query = MPMediaQuery.songs()
        guard let collections = query.items else {
            return items
        }

        for mediaItem in collections {
            let item: [String: Any?] = [
                "id": mediaItem.persistentID.description,
                "title": mediaItem.title ?? "Unknown",
                "artist": mediaItem.artist ?? "Unknown",
                "album": mediaItem.albumTitle ?? "Unknown",
                "durationMs": Int(mediaItem.playbackDuration * 1000),
                "uri": mediaItem.assetURL?.absoluteString ?? "",
                "sizeBytes": 0, // iOS does not expose file size via MPMediaItem
                "isRingtone": false
            ]
            items.append(item)
        }

        return items
    }

    // ------------------------------------------------------------------
    // Ringtones — System ringtone identifiers (iOS sandbox limited)
    // ------------------------------------------------------------------

    /// Returns known system ringtone identifiers.
    ///
    /// iOS does not provide a public API to enumerate all system ringtones.
    /// This method returns a curated list of well-known ringtone names.
    /// Apps intending to let users pick ringtones should use the system
    /// ringtone picker or include custom ringtone bundles.
    ///
    /// - Returns: Array of dictionaries for known system ringtones.
    private func getRingtones() -> [[String: Any?]] {
        // Known iOS system ringtone identifiers.
        // In production, consider bundling custom ringtones or using
        // a server-hosted catalog.
        let knownRingtones: [(id: String, title: String, category: String)] = [
            // Classic ringtones
            ("Opening", "Opening", "Classic"),
            ("Marimba", "Marimba", "Classic"),
            ("Xylophone", "Xylophone", "Classic"),
            ("Tri-tone", "Tri-tone", "Classic"),
            ("Stroll", "Stroll", "Classic"),
            ("Presto", "Presto", "Classic"),
            // Modern ringtones
            ("Apex", "Apex", "Modern"),
            ("Beacon", "Beacon", "Modern"),
            ("Bulletin", "Bulletin", "Modern"),
            ("By The Seaside", "By The Seaside", "Modern"),
            ("Chimes", "Chimes", "Modern"),
            ("Circuit", "Circuit", "Modern"),
            ("Constellation", "Constellation", "Modern"),
            ("Cosmic", "Cosmic", "Modern"),
            ("Crystals", "Crystals", "Modern"),
            ("Hillside", "Hillside", "Modern"),
            ("Illuminate", "Illuminate", "Modern"),
            ("Night Owl", "Night Owl", "Modern"),
            ("Playtime", "Playtime", "Modern"),
            ("Radar", "Radar", "Modern"),
            ("Radiate", "Radiate", "Modern"),
            ("Sencha", "Sencha", "Modern"),
            ("Signal", "Signal", "Modern"),
            ("Silk", "Silk", "Modern"),
            ("Slow Rise", "Slow Rise", "Modern"),
            ("Stargaze", "Stargaze", "Modern"),
            ("Summit", "Summit", "Modern"),
            ("Twinkle", "Twinkle", "Modern"),
            ("Uplift", "Uplift", "Modern"),
            ("Waves", "Waves", "Modern"),
        ]

        return knownRingtones.map { ringtone in
            [
                "id": ringtone.id,
                "title": ringtone.title,
                "artist": "System",
                "album": ringtone.category,
                "durationMs": 0,
                "uri": ringtone.id,
                "sizeBytes": 0,
                "isRingtone": true
            ] as [String: Any?]
        }
    }

    // ------------------------------------------------------------------
    // Ringtone Playback — AVAudioPlayer for local ringtone preview
    // ------------------------------------------------------------------

    /// Plays a system ringtone sound by its identifier.
    ///
    /// On iOS, we play the ringtone using AVAudioPlayer if the sound
    /// file is accessible, or fall back to AudioServicesPlaySystemSound
    /// for system sound IDs.
    ///
    /// - Parameter uri: The ringtone identifier (sound file name).
    private func playRingtone(uri: String) {
        stopRingtone()

        // Attempt to play as a bundled system sound
        // On a real device, ringtone files are at:
        // /Library/Ringtones/ or as UISounds
        let soundPath = "/Library/Ringtones/\(uri).m4r"
        let fileURL = URL(fileURLWithPath: soundPath)

        if FileManager.default.fileExists(atPath: soundPath) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                return
            } catch {
                // Fall through to AudioServices approach
            }
        }

        // Fallback: Try to extract the system sound ID from the ringtone
        // name and play it via AudioServices (vibrate-only for some IDs)
        if let soundURL = URL(string: "file:///System/Library/Audio/UISounds/\(uri).caf") {
            var soundID: SystemSoundID = 0
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
            if soundID != 0 {
                AudioServicesPlaySystemSound(soundID)
            }
        }
    }

    /// Stops the currently playing ringtone preview.
    private func stopRingtone() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

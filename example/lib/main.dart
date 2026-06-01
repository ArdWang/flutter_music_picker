import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_music_picker/flutter_music_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

/// The entry point of the flutter_music_picker example application.
///
/// This example demonstrates:
/// 1. Loading music files and ringtones using [FlutterMusicPicker].
/// 2. Playing music tracks using the `just_audio` package.
/// 3. Previewing ringtones using the plugin's native [playRingtone] /
///    [stopRingtone] methods (Android uses RingtoneManager, iOS/macOS
///    uses AVAudioPlayer, Windows uses PlaySound, Linux uses paplay).
/// 4. Cross-platform permission handling.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MusicPickerExampleApp());
}

/// Root widget for the music picker example application.
class MusicPickerExampleApp extends StatelessWidget {
  /// Creates a [MusicPickerExampleApp] instance.
  const MusicPickerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Music Picker Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      themeMode: ThemeMode.system,
      home: const MusicPickerPage(),
    );
  }
}

/// The main page — a tabbed music picker with playback controls.
class MusicPickerPage extends StatefulWidget {
  /// Creates a [MusicPickerPage] instance.
  const MusicPickerPage({super.key});

  @override
  State<MusicPickerPage> createState() => _MusicPickerPageState();
}

/// Manages music data loading, tab switching, music playback (just_audio),
/// and ringtone preview (native platform APIs).
class _MusicPickerPageState extends State<MusicPickerPage>
    with SingleTickerProviderStateMixin {
  static const _log = AppLogger('Example');

  // ---- tabs ----
  late final TabController _tabController;

  // ---- audio player for music files ----
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ---- data ----
  List<MusicItem> _musicFiles = [];
  List<MusicItem> _ringtones = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ---- music playback state ----
  MusicItem? _selectedMusicItem;
  bool _isMusicPlaying = false;
  Duration _musicPosition = Duration.zero;
  Duration _musicDuration = Duration.zero;

  // ---- ringtone preview state ----
  MusicItem? _previewingRingtone;
  bool _isRingtonePreviewing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Subscribe to audio player state changes
    _audioPlayer.playerStateStream.listen(_onMusicPlayerStateChanged);
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _musicPosition = p);
    });
    _audioPlayer.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _musicDuration = d);
    });

    _log.info('Example app started');
    // Load data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAudioFiles());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    // Ensure native ringtone playback is stopped when leaving the page
    FlutterMusicPicker.stopRingtone();
    super.dispose();
  }

  // --------------- Music player state ---------------

  void _onMusicPlayerStateChanged(PlayerState state) {
    if (mounted) {
      setState(() {
        _isMusicPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isMusicPlaying = false;
        }
      });
    }
  }

  // --------------- Permission & data loading ---------------

  /// Requests audio permissions and loads music + ringtone data
  /// from the device.
  Future<void> _loadAudioFiles() async {
    _log.info('Loading audio files...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final granted = await _requestPermissions();
      if (!granted) {
        _log.warn('Permission denied');
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Audio permission is required. Please grant it in app settings.';
        });
        return;
      }

      final results = await Future.wait([
        FlutterMusicPicker.getMusicFiles(),
        FlutterMusicPicker.getRingtones(),
      ]);

      if (mounted) {
        _log.info('Loaded: ${results[0].length} music files, '
            '${results[1].length} ringtones');
        setState(() {
          _musicFiles = results[0];
          _ringtones = results[1];
          _isLoading = false;
        });
      }
    } on MusicPickerException catch (e) {
      _log.error('MusicPickerException: ${e.message}');
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.message; });
    } catch (e) {
      _log.error('Unexpected error', e);
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Error: $e'; });
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      final audioStatus = await Permission.audio.status;
      if (audioStatus.isDenied || audioStatus.isLimited) {
        final result = await Permission.audio.request();
        if (!result.isGranted) {
          final storageResult = await Permission.storage.request();
          return storageResult.isGranted;
        }
      }
      return true;
    } on MissingPluginException {
      // permission_handler is not registered on this platform (e.g. desktop).
      _log.warn('permission_handler not available — skipping runtime check');
      return true;
    } on UnimplementedError {
      // Some permissions are not implemented on web (e.g. Permission.audio).
      // No runtime permission is needed on web anyway.
      _log.warn('Permission.audio not available on this platform — skipping');
      return true;
    }
  }

  // --------------- Music playback (just_audio) ---------------

  /// Plays a music file using just_audio. Toggles play/pause if the
  /// same item is already selected.
  Future<void> _toggleMusicPlayback(MusicItem item) async {
    try {
      if (_selectedMusicItem?.id == item.id) {
        if (_isMusicPlaying) {
          _log.debug('Pause music: ${item.title}');
          await _audioPlayer.pause();
        } else {
          _log.debug('Resume music: ${item.title}');
          await _audioPlayer.play();
        }
      } else {
        // Stop any ringtone preview before starting music
        await _stopRingtonePreview();

        _log.info('Play music: ${item.title} (${item.uri})');
        setState(() {
          _selectedMusicItem = item;
          _musicPosition = Duration.zero;
          _musicDuration = Duration(milliseconds: item.durationMs);
        });
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.parse(item.uri)),
        );
        await _audioPlayer.play();
      }
    } catch (e) {
      _log.error('Failed to play music: $e');
      if (mounted) _showError('Failed to play: $e');
    }
  }

  Future<void> _stopMusic() async {
    await _audioPlayer.stop();
    setState(() {
      _selectedMusicItem = null;
      _musicPosition = Duration.zero;
      _isMusicPlaying = false;
    });
  }

  // --------------- Ringtone preview (native APIs) ---------------

  /// Plays a ringtone using the platform's native ringtone playback:
  /// - Android: RingtoneManager.getRingtone(context, uri).play()
  /// - iOS/macOS: AVAudioPlayer
  /// - Windows: PlaySound()
  /// - Linux: paplay / aplay via fork
  Future<void> _toggleRingtonePreview(MusicItem item) async {
    // Stop any music that's currently playing
    await _stopMusic();

    try {
      if (_previewingRingtone?.id == item.id && _isRingtonePreviewing) {
        // Already previewing this ringtone → stop it
        _log.debug('Stop ringtone preview: ${item.title}');
        await _stopRingtonePreview();
      } else {
        // Stop any previous ringtone preview
        await _stopRingtonePreview();

        _log.info('Preview ringtone: ${item.title} (${item.uri})');
        setState(() {
          _previewingRingtone = item;
          _isRingtonePreviewing = true;
        });

        await FlutterMusicPicker.playRingtone(item.uri);

        // Ringtone previews are typically short; auto-reset after
        // a reasonable preview duration (3 seconds or the track duration)
        final autoStopDuration =
            item.durationMs > 0 ? item.durationMs : 3000;
        Future.delayed(Duration(milliseconds: autoStopDuration + 500), () {
          if (mounted &&
              _previewingRingtone?.id == item.id &&
              _isRingtonePreviewing) {
            _stopRingtonePreview();
          }
        });
      }
    } catch (e) {
      _log.error('Failed to preview ringtone: $e');
      if (mounted) _showError('Failed to preview: $e');
      setState(() => _isRingtonePreviewing = false);
    }
  }

  Future<void> _stopRingtonePreview() async {
    await FlutterMusicPicker.stopRingtone();
    if (mounted) {
      setState(() {
        _previewingRingtone = null;
        _isRingtonePreviewing = false;
      });
    }
  }

  void _showError(String message) {
    _log.error('Showing error snackbar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // --------------- UI ---------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Picker'),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadAudioFiles,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Alerts (${_musicFiles.length})',
              icon: const Icon(Icons.add_alert),
            ),
            Tab(
              text: 'ringtones (${_ringtones.length})',
              icon: const Icon(Icons.ring_volume),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(theme)),
          // Now-playing bar for music or ringtone
          if (_selectedMusicItem != null) _buildMusicNowPlayingBar(theme),
          if (_previewingRingtone != null) _buildRingtonePreviewBar(theme),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading audio files...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64,
                  color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadAudioFiles,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildMusicList(_musicFiles, theme),
        _buildRingtoneList(_ringtones, theme),
      ],
    );
  }

  // ---- Music list ----

  Widget _buildMusicList(List<MusicItem> items, ThemeData theme) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off, size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No music files found.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                )),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedMusicItem?.id == item.id;
        final isThisPlaying = isSelected && _isMusicPlaying;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondaryContainer,
              child: Icon(
                isThisPlaying ? Icons.pause : Icons.music_note,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(item.title, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text(
              '${item.artist} · ${item.album}  |  ${item.formattedDuration} · ${item.formattedSize}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            trailing: IconButton(
              icon: Icon(
                isThisPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle,
                size: 36,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              tooltip: isThisPlaying ? 'Pause' : 'Play',
              onPressed: () => _toggleMusicPlayback(item),
            ),
            onTap: () => _toggleMusicPlayback(item),
          ),
        );
      },
    );
  }

  // ---- Ringtone list ----

  Widget _buildRingtoneList(List<MusicItem> items, ThemeData theme) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ring_volume, size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No alerts found.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                )),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isPreviewing = _previewingRingtone?.id == item.id;
        final isActive = isPreviewing && _isRingtonePreviewing;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isPreviewing
              ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5)
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPreviewing
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.secondaryContainer,
              child: Icon(
                Icons.ring_volume,
                size: 20,
                color: isPreviewing
                    ? theme.colorScheme.onTertiary
                    : theme.colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(item.title, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight:
                    isPreviewing ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text(
              '${item.album}${item.durationMs > 0 ? " · ${item.formattedDuration}" : ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Preview button — uses native ringtone playback
                IconButton(
                  icon: Icon(
                    isActive ? Icons.stop_circle : Icons.volume_up,
                    size: 28,
                    color: isPreviewing
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  tooltip: isActive ? 'Stop preview' : 'Preview',
                  onPressed: () => _toggleRingtonePreview(item),
                ),
              ],
            ),
            onTap: () => _toggleRingtonePreview(item),
          ),
        );
      },
    );
  }

  // ---- Now-playing bar: music ----

  Widget _buildMusicNowPlayingBar(ThemeData theme) {
    final track = _selectedMusicItem!;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(track.title, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${track.artist} · ${track.formattedDuration}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.music_note,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isMusicPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                    size: 40, color: theme.colorScheme.primary),
                  tooltip: _isMusicPlaying ? 'Pause' : 'Play',
                  onPressed: () => _toggleMusicPlayback(track),
                ),
                IconButton(
                  icon: Icon(Icons.stop_circle_outlined, size: 40,
                      color: theme.colorScheme.error),
                  tooltip: 'Stop', onPressed: _stopMusic,
                ),
              ],
            ),
            if (_musicDuration.inMilliseconds > 0)
              Row(
                children: [
                  Text(_formatDuration(_musicPosition),
                      style: theme.textTheme.labelSmall),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: _musicPosition.inMilliseconds
                            .clamp(0, _musicDuration.inMilliseconds)
                            .toDouble(),
                        max: _musicDuration.inMilliseconds
                            .toDouble()
                            .clamp(1.0, double.infinity),
                        onChanged: (v) =>
                            _audioPlayer.seek(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                  ),
                  Text(_formatDuration(_musicDuration),
                      style: theme.textTheme.labelSmall),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ---- Ringtone preview bar ----

  Widget _buildRingtonePreviewBar(ThemeData theme) {
    final ringtone = _previewingRingtone!;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.ring_volume, color: theme.colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ringtone.title, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Alert preview · ${ringtone.album}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.stop_circle, size: 40,
                  color: theme.colorScheme.error),
              tooltip: 'Stop preview',
              onPressed: _stopRingtonePreview,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';

/// Manages video playback volume state with SharedPreferences persistence
/// and system volume observation.
///
/// The service bridges the hardware volume buttons to the app's video
/// playback volume: when the user sets the device volume to zero, the
/// video feed is muted; when the device volume rises above zero and the
/// feed was previously unmuted by the user, volume is restored.
///
/// Usage:
/// ```dart
/// await VideoVolumeService.instance.init();
///
/// VideoFeedController(
///   initialVolume: VideoVolumeService.instance.volume,
///   onVolumeChanged: VideoVolumeService.instance.onPlaybackVolumeChanged,
///   ...
/// );
///
/// VideoVolumeService.instance.addListener(() {
///   feedController.setVolume(VideoVolumeService.instance.volume);
/// });
/// ```
class VideoVolumeService extends ChangeNotifier {
  static const _prefsKey = 'video_playback_volume';

  static final VideoVolumeService _instance = VideoVolumeService._();
  static VideoVolumeService get instance => _instance;

  VideoVolumeService._();

  /// Creates a fresh instance for unit testing without touching the global
  /// singleton or platform plugins.
  @visibleForTesting
  VideoVolumeService.forTesting({double initialVolume = 1.0})
    : _volume = initialVolume;

  double _volume = 1.0;
  StreamSubscription<double>? _systemVolumeSubscription;

  /// Current desired playback volume (0.0 = muted, 1.0 = full).
  double get volume => _volume;

  /// Whether playback is currently muted.
  bool get isMuted => _volume == 0;

  /// Loads persisted volume and starts listening to system volume changes.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = prefs.getDouble(_prefsKey) ?? 1.0;
    if (_volume != loaded) {
      _volume = loaded;
      notifyListeners();
    }

    // Disable the system volume UI overlay — the feed has its own mute
    // indicator and showing both is confusing.
    // volume_controller has no web platform — skip to avoid
    // MissingPluginException in crash reporting.
    if (!kIsWeb) {
      VolumeController.instance.showSystemUI = false;

      _systemVolumeSubscription = VolumeController.instance.addListener(
        _onSystemVolumeChanged,
        fetchInitialVolume: false,
      );
    }
  }

  /// Called by [VideoFeedController.onVolumeChanged] when the user toggles
  /// mute or adjusts volume via the in-app UI.
  void onPlaybackVolumeChanged(double newVolume) {
    if (_volume == newVolume) return;
    _volume = newVolume;
    unawaited(_persist());
    // Do NOT call notifyListeners here — the controller already applied the
    // change. We only persist so the next controller picks it up.
  }

  void _onSystemVolumeChanged(double systemVolume) {
    if (systemVolume == 0 && _volume > 0) {
      // Device muted → mute video
      _volume = 0;
      unawaited(_persist());
      notifyListeners();
    } else if (systemVolume > 0 && _volume == 0) {
      // Device unmuted → unmute video
      _volume = 1.0;
      unawaited(_persist());
      notifyListeners();
    }
  }

  /// Simulates a hardware volume change for testing the system-volume bridge.
  @visibleForTesting
  void simulateSystemVolumeChange(double systemVolume) =>
      _onSystemVolumeChanged(systemVolume);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, _volume);
  }

  @override
  void dispose() {
    unawaited(_systemVolumeSubscription?.cancel());
    super.dispose();
  }
}

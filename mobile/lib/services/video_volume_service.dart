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
/// final service = VideoVolumeService();
/// await service.init();
///
/// VideoFeedController(
///   initialVolume: service.volume,
///   onVolumeChanged: service.onPlaybackVolumeChanged,
///   ...
/// );
///
/// service.addListener(() {
///   feedController.setVolume(service.volume);
/// });
/// ```
class VideoVolumeService extends ChangeNotifier {
  static const _prefsKey = 'video_playback_volume';

  static final VideoVolumeService _instance = VideoVolumeService._();
  static VideoVolumeService get instance => _instance;

  VideoVolumeService._();

  double _volume = 1.0;
  StreamSubscription<double>? _systemVolumeSubscription;

  /// Current desired playback volume (0.0 = muted, 1.0 = full).
  double get volume => _volume;

  /// Whether playback is currently muted.
  bool get isMuted => _volume == 0;

  /// Loads persisted volume and starts listening to system volume changes.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble(_prefsKey) ?? 1.0;

    // Disable the system volume UI overlay — the feed has its own mute
    // indicator and showing both is confusing.
    VolumeController.instance.showSystemUI = false;

    _systemVolumeSubscription = VolumeController.instance.addListener(
      _onSystemVolumeChanged,
      fetchInitialVolume: false,
    );
  }

  /// Called by [VideoFeedController.onVolumeChanged] when the user toggles
  /// mute or adjusts volume via the in-app UI.
  void onPlaybackVolumeChanged(double newVolume) {
    if (_volume == newVolume) return;
    _volume = newVolume;
    _persist();
    // Do NOT call notifyListeners here — the controller already applied the
    // change. We only persist so the next controller picks it up.
  }

  void _onSystemVolumeChanged(double systemVolume) {
    if (systemVolume == 0 && _volume > 0) {
      // Device muted → mute video
      _volume = 0;
      _persist();
      notifyListeners();
    } else if (systemVolume > 0 && _volume == 0) {
      // Device unmuted → unmute video
      _volume = 1.0;
      _persist();
      notifyListeners();
    }
  }

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

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';

part 'video_volume_state.dart';

/// Manages video playback volume state with [SharedPreferences] persistence
/// and system volume observation.
///
/// The cubit bridges the hardware volume buttons to the app's video
/// playback volume: when the user sets the device volume to zero, the
/// video feed is muted; when the device volume rises above zero, volume
/// is restored.
///
/// Volume is binary: `1.0` (unmuted) or `0.0` (muted). The actual loudness
/// is controlled by the device's hardware volume.
class VideoVolumeCubit extends Cubit<VideoVolumeState> {
  /// Creates a [VideoVolumeCubit] that reads the persisted volume from
  /// [sharedPreferences] synchronously — no async init needed.
  VideoVolumeCubit({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences,
      super(
        VideoVolumeState(
          volume: sharedPreferences.getDouble(_prefsKey) ?? 1.0,
        ),
      ) {
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

  static const _prefsKey = 'video_playback_volume';

  final SharedPreferences _prefs;
  StreamSubscription<double>? _systemVolumeSubscription;

  /// Called by [VideoFeedController.onVolumeChanged] when the user toggles
  /// mute or adjusts volume via the in-app UI.
  void onPlaybackVolumeChanged(double newVolume) {
    if (state.volume == newVolume) return;
    emit(VideoVolumeState(volume: newVolume));
    unawaited(_persist());
  }

  void _onSystemVolumeChanged(double systemVolume) {
    if (systemVolume == 0 && state.volume > 0) {
      // Device muted → mute video
      emit(const VideoVolumeState(volume: 0));
      unawaited(_persist());
    } else if (systemVolume > 0 && state.volume == 0) {
      // Device unmuted → unmute video
      emit(const VideoVolumeState());
      unawaited(_persist());
    }
  }

  /// Simulates a hardware volume change for testing the system-volume bridge.
  @visibleForTesting
  void simulateSystemVolumeChange(double systemVolume) =>
      _onSystemVolumeChanged(systemVolume);

  Future<void> _persist() async {
    await _prefs.setDouble(_prefsKey, state.volume);
  }

  @override
  Future<void> close() {
    unawaited(_systemVolumeSubscription?.cancel());
    return super.close();
  }
}

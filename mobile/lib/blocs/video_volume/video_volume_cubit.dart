import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';

part 'video_volume_state.dart';

/// Abstraction over the platform volume listener so tests can inject a fake
/// stream instead of stubbing EventChannels.
abstract class SystemVolumeListener {
  /// Subscribes to system volume changes. Returns a cancellable subscription.
  StreamSubscription<double> listen(void Function(double volume) onData);

  /// Hides the native OS volume HUD.
  void hideSystemUI();
}

/// Default implementation backed by the `volume_controller` plugin.
class _PluginVolumeListener implements SystemVolumeListener {
  @override
  StreamSubscription<double> listen(void Function(double volume) onData) {
    return VolumeController.instance.addListener(
      onData,
      fetchInitialVolume: false,
    );
  }

  @override
  void hideSystemUI() {
    VolumeController.instance.showSystemUI = false;
  }
}

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
///
/// **App-wide side effect:** The constructor sets
/// `VolumeController.instance.showSystemUI = false` to hide the native OS
/// volume HUD across the entire app. This is intentional — Divine is a
/// video-first app and the overlay conflicts with the in-app mute UI.
/// Do not re-enable `showSystemUI` elsewhere without coordinating here.
class VideoVolumeCubit extends Cubit<VideoVolumeState> {
  /// Creates a [VideoVolumeCubit] that reads the persisted volume from
  /// [sharedPreferences] synchronously — no async init needed.
  ///
  /// An optional [systemVolumeListener] can be injected for testing.
  /// When omitted on non-web platforms, the default plugin-backed
  /// listener is used.
  VideoVolumeCubit({
    required SharedPreferences sharedPreferences,
    SystemVolumeListener? systemVolumeListener,
  }) : _prefs = sharedPreferences,
       super(
         VideoVolumeState(
           volume: sharedPreferences.getDouble(_prefsKey) ?? 1.0,
         ),
       ) {
    // volume_controller has no web platform — skip to avoid
    // MissingPluginException in crash reporting.
    if (!kIsWeb || systemVolumeListener != null) {
      final listener = systemVolumeListener ?? _PluginVolumeListener();
      listener.hideSystemUI();
      _systemVolumeSubscription = listener.listen(_onSystemVolumeChanged);
    }
  }

  static const _prefsKey = 'video_playback_volume';

  final SharedPreferences _prefs;
  StreamSubscription<double>? _systemVolumeSubscription;

  /// Called by [VideoFeedController.onVolumeChanged] when the user toggles
  /// mute or adjusts volume via the in-app UI.
  ///
  /// Values are clamped to the binary set `{0.0, 1.0}`: any positive
  /// [newVolume] is treated as unmuted (`1.0`).
  void onPlaybackVolumeChanged(double newVolume) {
    final clamped = newVolume > 0 ? 1.0 : 0.0;
    if (state.volume == clamped) return;
    emit(VideoVolumeState(volume: clamped));
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

  Future<void> _persist() async {
    await _prefs.setDouble(_prefsKey, state.volume);
  }

  @override
  Future<void> close() {
    unawaited(_systemVolumeSubscription?.cancel());
    return super.close();
  }
}

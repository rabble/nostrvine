import 'dart:async';

import 'package:divine_video_player/src/audio_track.dart' as divine;
import 'package:divine_video_player/src/linux/linux_video_player_backend.dart';
import 'package:divine_video_player/src/video_clip.dart';
import 'package:divine_video_player/src/video_player_state.dart';
import 'package:flutter/widgets.dart';

/// Creates a Web video backend implementation.
typedef WebVideoPlayerBackendFactory = WebVideoPlayerBackend Function();

/// Web-specific playback backend used by the public controller.
///
/// Mirrors [LinuxVideoPlayerBackend] but is driven by an `HTMLVideoElement`
/// rendered via `HtmlElementView`. Multi-clip timelines and overlay audio
/// tracks are not supported — when the controller passes more than one
/// clip only the first is played and overlay-audio calls become no-ops.
abstract interface class WebVideoPlayerBackend {
  /// Initializes the backend and starts emitting state changes.
  Future<void> initialize({
    required void Function(DivineVideoPlayerState state) onStateChanged,
    required void Function(Object error) onError,
  });

  /// Loads one or more clips into the backend player.
  Future<void> setClips(List<VideoClip> clips, {Duration? startPosition});

  /// Starts or resumes playback.
  Future<void> play();

  /// Pauses playback.
  Future<void> pause();

  /// Stops playback and unloads media.
  Future<void> stop();

  /// Seeks to a position on the global timeline.
  Future<void> seekTo(Duration position);

  /// Sets the player volume.
  Future<void> setVolume(double volume);

  /// Sets the playback speed multiplier.
  Future<void> setPlaybackSpeed(double speed);

  /// Enables or disables looping.
  Future<void> setLooping({required bool looping});

  /// Jumps to a clip index within the current timeline.
  Future<void> jumpToClip(int index);

  /// Replaces the active overlay audio tracks. No-op on web.
  Future<void> setAudioTracks(List<divine.AudioTrack> tracks);

  /// Removes all overlay audio tracks. No-op on web.
  Future<void> removeAllAudioTracks();

  /// Sets the volume of a single overlay audio track. No-op on web.
  Future<void> setAudioTrackVolume(int index, double volume);

  /// Builds the platform-specific render widget.
  Widget buildView();

  /// Disposes the backend and releases native resources.
  Future<void> dispose();
}

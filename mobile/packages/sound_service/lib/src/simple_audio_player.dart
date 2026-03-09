// ABOUTME: Minimal audio player interface for simple playback use-cases.
// ABOUTME: Wraps just_audio's AudioPlayer behind a narrow contract so
// ABOUTME: consumers (e.g. CountdownSoundService) don't depend on just_audio.

import 'package:just_audio/just_audio.dart';
import 'package:sound_service/src/countdown_sound_service.dart';

/// Minimal audio player contract for fire-and-forget sound playback.
///
/// Only the methods needed by [CountdownSoundService] are exposed.
/// This keeps `just_audio` types out of the public API surface.
abstract interface class SimpleAudioPlayer {
  /// Loads an asset at [assetPath] and returns the audio duration.
  Future<Duration?> setAsset(String assetPath);

  /// Seeks to the given [position].
  Future<void> seek(Duration position);

  /// Starts or resumes playback.
  Future<void> play();

  /// Releases all resources held by the player.
  Future<void> dispose();
}

/// Default [SimpleAudioPlayer] backed by `just_audio`'s [AudioPlayer].
// coverage:ignore-start
class JustAudioSimplePlayer implements SimpleAudioPlayer {
  /// Creates a [JustAudioSimplePlayer].
  ///
  /// An optional [audioPlayer] can be injected for internal
  /// package-level tests that need to mock the underlying player.
  JustAudioSimplePlayer({AudioPlayer? audioPlayer})
    : _player = audioPlayer ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<Duration?> setAsset(String assetPath) => _player.setAsset(assetPath);

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> dispose() => _player.dispose();
}

// coverage:ignore-end

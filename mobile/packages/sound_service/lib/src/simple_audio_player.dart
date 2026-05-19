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
///
/// The constructor wiring (including the `handleAudioSessionActivation`
/// pass-through) sits inside a `coverage:ignore` block because it is a
/// thin forward to `just_audio`'s [AudioPlayer], whose behaviour is
/// contract-guaranteed by that package. The regression risk of dropping
/// `handleAudioSessionActivation: false` is covered indirectly by
/// `VideoRecorderNotifier`'s default factories
/// (`defaultCountdownSoundServiceFactory`,
/// `defaultAudioPlaybackServiceFactory`) and the associated tests \u2014 see
/// #4539 for the underlying iOS AVAudioSession issue.
// coverage:ignore-start
class JustAudioSimplePlayer implements SimpleAudioPlayer {
  /// Creates a [JustAudioSimplePlayer].
  ///
  /// An optional [audioPlayer] can be injected for internal
  /// package-level tests that need to mock the underlying player.
  ///
  /// Set [handleAudioSessionActivation] to `false` when another component
  /// (e.g. a camera capture pipeline) already owns the platform audio
  /// session and just_audio must not reconfigure it. Default `true`
  /// matches just_audio's own default.
  JustAudioSimplePlayer({
    AudioPlayer? audioPlayer,
    bool handleAudioSessionActivation = true,
  }) : _player =
           audioPlayer ??
           AudioPlayer(
             handleAudioSessionActivation: handleAudioSessionActivation,
           );

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

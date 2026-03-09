import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'package:sound_service/src/simple_audio_player.dart';

/// Factory function that creates a [SimpleAudioPlayer] instance.
///
/// Defaults to [JustAudioSimplePlayer.new]. Override in tests to
/// inject mocks.
typedef AudioPlayerFactory = SimpleAudioPlayer Function();

/// Service for playing countdown beep sounds before recording starts.
///
/// Plays a short beep on each countdown tick and a longer "go" beep
/// after the countdown reaches zero to signal recording start.
///
/// The service pre-loads both sound assets for instant playback and
/// ensures the final long beep fully plays before returning.
///
/// Example usage:
/// ```dart
/// final service = CountdownSoundService();
/// await service.preload();
///
/// for (var i = 3; i > 0; i--) {
///   await service.playShortBeep();
///   await Future.delayed(Duration(seconds: 1));
/// }
///
/// await service.playLongBeepAndWait();
/// await service.dispose();
/// ```
class CountdownSoundService {
  /// Creates a [CountdownSoundService].
  ///
  /// An optional [audioPlayerFactory] can be provided for testing.
  CountdownSoundService({AudioPlayerFactory? audioPlayerFactory})
    : _audioPlayerFactory = audioPlayerFactory ?? JustAudioSimplePlayer.new;

  /// Duration of the short countdown tick beep.
  static const shortBeepDuration = Duration(milliseconds: 15);

  /// Duration of the long "go" beep played after countdown reaches zero.
  static const longBeepDuration = Duration(milliseconds: 60);

  /// Buffer added after long beep playback to ensure audio fully completes.
  ///
  /// On iOS, [SimpleAudioPlayer.play] may return slightly before the audio
  /// hardware finishes output, which can cause the beep to bleed into recorded
  /// video.
  static const postPlaybackBuffer = Duration(milliseconds: 150);

  /// Default asset path for the short countdown beep.
  @visibleForTesting
  static const shortBeepAsset = 'assets/sounds/countdown_beep_short.wav';

  /// Default asset path for the long countdown beep.
  @visibleForTesting
  static const longBeepAsset = 'assets/sounds/countdown_beep_long.wav';

  final AudioPlayerFactory _audioPlayerFactory;
  SimpleAudioPlayer? _shortBeepPlayer;
  SimpleAudioPlayer? _longBeepPlayer;
  bool _isDisposed = false;

  /// Pre-loads both countdown sound assets for instant playback.
  ///
  /// Call this once before the countdown loop begins.
  ///
  /// Throws [Exception] if assets fail to load (caller should handle
  /// gracefully — countdown sounds are best-effort).
  Future<void> preload() async {
    try {
      _shortBeepPlayer = _audioPlayerFactory();
      _longBeepPlayer = _audioPlayerFactory();

      await Future.wait([
        _shortBeepPlayer!.setAsset(shortBeepAsset),
        _longBeepPlayer!.setAsset(longBeepAsset),
      ]);

      log(
        'Countdown sounds preloaded',
        name: 'CountdownSoundService',
      );
    } on Exception catch (e) {
      log(
        'Failed to preload countdown sounds: $e',
        name: 'CountdownSoundService',
        level: 900,
      );
      // Clean up on failure
      await dispose();
      rethrow;
    }
  }

  /// Plays the short beep for each countdown tick.
  ///
  /// Resets playback position to the start before playing so the same
  /// player instance can be reused across ticks.
  Future<void> playShortBeep() async {
    if (_isDisposed || _shortBeepPlayer == null) return;

    try {
      await _shortBeepPlayer!.seek(Duration.zero);
      await _shortBeepPlayer!.play();
    } on Exception catch (e) {
      log(
        'Failed to play short countdown beep: $e',
        name: 'CountdownSoundService',
        level: 900,
      );
    }
  }

  /// Plays the long "go" beep after the countdown reaches zero and
  /// waits for it to finish before returning.
  ///
  /// This ensures the sound fully plays out before recording begins.
  Future<void> playLongBeepAndWait() async {
    if (_isDisposed || _longBeepPlayer == null) return;

    try {
      await _longBeepPlayer!.seek(Duration.zero);
      await _longBeepPlayer!.play();
      // Extra buffer to ensure audio fully completes before recording starts.
      // On iOS, play() may return slightly before audio hardware finishes,
      // which can cause the beep to bleed into the recorded video audio.
      await Future<void>.delayed(postPlaybackBuffer);
    } on Exception catch (e) {
      log(
        'Failed to play long countdown beep: $e',
        name: 'CountdownSoundService',
        level: 900,
      );
    }
  }

  /// Releases audio player resources.
  Future<void> dispose() async {
    _isDisposed = true;
    await _shortBeepPlayer?.dispose();
    await _longBeepPlayer?.dispose();
    _shortBeepPlayer = null;
    _longBeepPlayer = null;
  }
}

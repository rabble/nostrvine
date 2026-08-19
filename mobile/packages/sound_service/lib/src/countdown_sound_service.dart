import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:sound_service/src/simple_audio_player.dart';
import 'package:unified_logger/unified_logger.dart';

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
///   await Future.delayed(
///     i > 1 ? const Duration(seconds: 1) : service.finalTickLeadIn,
///   );
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

  /// Playback volume applied to both countdown beeps.
  ///
  /// The beeps leave the speaker while the camera microphone is already
  /// capturing, and on iPhone the bottom speaker sits centimetres from the
  /// bottom mic. Both assets peak at -7.4 dBFS, so at full level the "go"
  /// beep drives the input near clipping and the automatic gain control
  /// that `AVAudioSessionMode.videoRecording` leaves enabled clamps the mic
  /// gain moments before capture starts. Its release curve runs for
  /// seconds — that is the progressive volume ramp reported in #4539.
  /// Attenuating by ~10 dB puts the beep peak near -18 dBFS while keeping
  /// it clearly audible.
  static const beepVolume = 0.3;

  /// Play-out duration assumed for the long "go" beep before [preload] has
  /// measured the asset.
  ///
  /// Matches `countdown_beep_long.wav`; [longBeepDuration] reports the real
  /// value once the player has loaded it.
  static const longBeepFallbackDuration = Duration(milliseconds: 600);

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
  Duration _longBeepDuration = longBeepFallbackDuration;
  bool _isDisposed = false;

  /// Play-out duration of the long "go" beep, as reported by the player
  /// during [preload].
  Duration get longBeepDuration => _longBeepDuration;

  /// How long to hold the final countdown tick before starting the "go"
  /// beep, so that beep plus [postPlaybackBuffer] lands exactly one second
  /// after the tick appeared.
  ///
  /// Clamped at [Duration.zero] for assets longer than that second.
  Duration get finalTickLeadIn {
    final leadIn =
        const Duration(seconds: 1) - _longBeepDuration - postPlaybackBuffer;
    return leadIn.isNegative ? Duration.zero : leadIn;
  }

  /// Pre-loads both countdown sound assets for instant playback.
  ///
  /// Call this once before the countdown loop begins. Players left over
  /// from an earlier countdown are released first.
  ///
  /// Throws [Exception] if assets fail to load (caller should handle
  /// gracefully — countdown sounds are best-effort).
  Future<void> preload() async {
    await _disposePlayers();

    try {
      _shortBeepPlayer = _audioPlayerFactory();
      _longBeepPlayer = _audioPlayerFactory();

      final durations = await Future.wait([
        _shortBeepPlayer!.setAsset(shortBeepAsset),
        _longBeepPlayer!.setAsset(longBeepAsset),
      ]);

      await Future.wait([
        _shortBeepPlayer!.setVolume(beepVolume),
        _longBeepPlayer!.setVolume(beepVolume),
      ]);

      _longBeepDuration = durations.last ?? longBeepFallbackDuration;

      Log.debug(
        'Countdown sounds preloaded '
        '(long beep ${_longBeepDuration.inMilliseconds}ms)',
        name: 'CountdownSoundService',
        category: LogCategory.video,
      );
    } on Exception catch (e) {
      Log.warning(
        'Failed to preload countdown sounds: $e',
        name: 'CountdownSoundService',
        category: LogCategory.video,
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
      Log.warning(
        'Failed to play short countdown beep: $e',
        name: 'CountdownSoundService',
        category: LogCategory.video,
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
      Log.warning(
        'Failed to play long countdown beep: $e',
        name: 'CountdownSoundService',
        category: LogCategory.video,
      );
    }
  }

  /// Releases audio player resources.
  Future<void> dispose() async {
    _isDisposed = true;
    await _disposePlayers();
  }

  Future<void> _disposePlayers() async {
    await _shortBeepPlayer?.dispose();
    await _longBeepPlayer?.dispose();
    _shortBeepPlayer = null;
    _longBeepPlayer = null;
  }
}

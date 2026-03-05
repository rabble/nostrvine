// ABOUTME: Wrapper around just_audio for clipped audio playback.
// ABOUTME: Encapsulates AudioPlayer, ClippingAudioSource, and player state
// ABOUTME: so consumers never depend on just_audio types directly.

import 'dart:async';
import 'dart:developer';

import 'package:just_audio/just_audio.dart';

/// A player that plays a clipped portion of an audio source.
///
/// Wraps `just_audio`'s [AudioPlayer] and [ClippingAudioSource] behind a
/// focused API so that consumers do not depend on `just_audio` types
/// directly. If the underlying audio library is replaced, only this class
/// needs to change.
// coverage:ignore-start
class AudioClipPlayer {
  /// Creates an [AudioClipPlayer].
  ///
  /// An optional [audioPlayer] can be injected for testing within the
  /// `sound_service` package.
  AudioClipPlayer({AudioPlayer? audioPlayer})
    : _audioPlayer = audioPlayer ?? AudioPlayer();

  final AudioPlayer _audioPlayer;

  /// Stream that emits an event each time the current clip finishes
  /// playing (i.e. reaches the end without being stopped manually).
  ///
  /// Consumers can use this to implement looping or transition logic
  /// without needing to know about `just_audio`'s [PlayerState] or
  /// [ProcessingState].
  Stream<void> get completionStream => _audioPlayer.playerStateStream
      .where((s) => s.processingState == ProcessingState.completed)
      .map((_) {});

  /// Whether audio is currently playing.
  bool get isPlaying => _audioPlayer.playing;

  /// Sets a clipped audio source.
  ///
  /// [uri] is the audio location — either a network URL or a local
  /// asset path (when [isAsset] is `true`).
  /// [start] and [end] define the clip boundaries within the full track.
  Future<void> setClip({
    required String uri,
    required bool isAsset,
    required Duration start,
    required Duration end,
  }) async {
    final child = isAsset
        ? AudioSource.asset(uri)
        : AudioSource.uri(Uri.parse(uri));

    final source = ClippingAudioSource(
      child: child,
      start: start,
      end: end,
    );

    await _audioPlayer.setAudioSource(source);
  }

  /// Starts or resumes playback.
  Future<void> play() async {
    await _audioPlayer.play();
  }

  /// Pauses playback, keeping the current position.
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Stops playback and resets to the beginning.
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Seeks to the given [position] within the current clip.
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Releases all resources held by the underlying player.
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } on Exception catch (e) {
      log(
        'Error disposing AudioClipPlayer: $e',
        name: 'AudioClipPlayer',
        level: 900,
      );
    }
  }
}

// coverage:ignore-end

// ABOUTME: Wrapper around just_audio for clipped audio playback.
// ABOUTME: Encapsulates AudioPlayer, ClippingAudioSource, and player state
// ABOUTME: so consumers never depend on just_audio types directly.

import 'dart:async';
import 'dart:developer';

import 'package:just_audio/just_audio.dart';
import 'package:sound_service/src/audio_source_config.dart';

/// A player that plays a clipped portion of an audio source.
///
/// Wraps `just_audio`'s [AudioPlayer] and [ClippingAudioSource] behind a
/// focused API so that consumers do not depend on `just_audio` types
/// directly. If the underlying audio library is replaced, only this class
/// needs to change.
class AudioClipPlayer {
  /// Creates an [AudioClipPlayer].
  ///
  /// An optional [audioPlayer] can be injected for testing within the
  /// `sound_service` package.
  // coverage:ignore-start
  AudioClipPlayer({AudioPlayer? audioPlayer})
    : _audioPlayer = audioPlayer ?? AudioPlayer();
  // coverage:ignore-end

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

  /// Sets a clipped audio source from an [AudioSourceConfig].
  ///
  /// The config's [AudioSourceConfig.start] and [AudioSourceConfig.end]
  /// define the clip boundaries within the full track.
  Future<void> setClip(AudioSourceConfig config) async {
    final UriAudioSource child;
    if (config.isAsset) {
      child = AudioSource.asset(config.uri);
    } else if (config.isFile) {
      child = AudioSource.file(config.uri);
    } else {
      child = AudioSource.uri(Uri.parse(config.uri));
    }

    final source = ClippingAudioSource(
      child: child,
      start: config.start,
      end: config.end,
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

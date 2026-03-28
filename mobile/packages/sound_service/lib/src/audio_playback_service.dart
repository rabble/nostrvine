// ABOUTME: Service for audio playback during recording with headphone detection
// ABOUTME: Manages audio session configuration and exposes playback streams

// No non-experimental alternative exists. Tracked upstream:
// https://github.com/ryanheise/audio_session/issues
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_service/src/audio_session_wrapper.dart';
import 'package:sound_service/src/audio_source_config.dart';

/// Service for managing audio playback during lip sync recording mode.
///
/// This service handles:
/// - Playing selected audio tracks during recording
/// - Detecting headphone connection state
/// - Managing audio session configuration for recording scenarios
class AudioPlaybackService {
  /// Creates an AudioPlaybackService with an optional custom AudioPlayer.
  ///
  /// The [audioPlayer] parameter allows for dependency injection in tests.
  /// The [audioSessionWrapper] parameter allows for mocking audio session.
  // coverage:ignore-start
  AudioPlaybackService({
    AudioPlayer? audioPlayer,
    AudioSessionWrapper? audioSessionWrapper,
    bool handleAudioSessionActivation = true,
  }) : _audioPlayer =
           audioPlayer ??
           AudioPlayer(
             handleAudioSessionActivation: handleAudioSessionActivation,
           ),
       _audioSessionWrapper =
           audioSessionWrapper ?? DefaultAudioSessionWrapper() {
    unawaited(_initializeHeadphoneDetection());
  }
  // coverage:ignore-end

  final AudioPlayer _audioPlayer;
  final AudioSessionWrapper _audioSessionWrapper;

  /// BehaviorSubject for headphone connection state.
  /// Starts with false (no headphones) until actual state is determined.
  final BehaviorSubject<bool> _headphonesConnectedSubject =
      BehaviorSubject<bool>.seeded(false);

  StreamSubscription<dynamic>? _deviceChangeSubscription;
  bool _isDisposed = false;

  /// Completer that gates operations while audio is loading.
  /// When non-null, a load operation is in progress. [seek] and [play]
  /// will await this completer before forwarding to the player.
  Completer<void>? _loadCompleter;

  /// The last successfully loaded audio source identifier.
  /// Used to reload the source when a "Loading interrupted" error occurs.
  ({_SourceType type, Object value})? _lastSource;

  /// Monotonic counter to discard stale `getDevices` results.
  /// Incremented before every device query; only the response whose
  /// captured epoch still equals [_deviceCheckEpoch] may update the subject.
  int _deviceCheckEpoch = 0;

  /// Stream of playback position updates.
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Stream of duration updates (null if not loaded).
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;

  /// Stream of playing state updates.
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  /// Current duration of loaded audio (null if not loaded).
  Duration? get duration => _audioPlayer.duration;

  /// Whether audio is currently playing.
  bool get isPlaying => _audioPlayer.playing;

  /// Stream of headphone connection state changes.
  Stream<bool> get headphonesConnectedStream =>
      _headphonesConnectedSubject.stream;

  /// Current headphone connection state.
  bool get areHeadphonesConnected => _headphonesConnectedSubject.value;

  /// Initializes headphone detection using audio_session.
  Future<void> _initializeHeadphoneDetection() async {
    if (_isDisposed) return;

    try {
      // Check initial headphone state
      final devices = await _audioSessionWrapper.getDevices();
      final hasHeadphones = _checkForHeadphones(devices);
      if (_isDisposed) return;
      _headphonesConnectedSubject.add(hasHeadphones);

      // Listen for device changes
      _deviceChangeSubscription = _audioSessionWrapper.devicesChangedEventStream
          .listen(
            (event) {
              if (_isDisposed) return;

              // Bump epoch so any in-flight getDevices() call becomes stale.
              final epoch = ++_deviceCheckEpoch;

              unawaited(
                _audioSessionWrapper.getDevices().then((allDevices) {
                  // Discard if a newer event arrived while we were waiting.
                  if (_isDisposed || epoch != _deviceCheckEpoch) return;
                  final hasHeadphones = _checkForHeadphones(allDevices);
                  _headphonesConnectedSubject.add(hasHeadphones);
                }),
              );
            },
            onError: (Object error) {
              log(
                'Error in device change stream: $error',
                name: 'AudioPlaybackService',
                level: 900,
              );
            },
          );

      log(
        'Headphone detection initialized. Connected: $hasHeadphones',
        name: 'AudioPlaybackService',
      );
    } on Exception catch (e) {
      log(
        'Failed to initialize headphone detection: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      // Default to false if detection fails
      if (!_isDisposed) {
        _headphonesConnectedSubject.add(false);
      }
    }
  }

  /// Checks if any of the given devices are headphones or external audio.
  bool _checkForHeadphones(Set<audio_session.AudioDevice> devices) {
    for (final device in devices) {
      // Check for wired headphones
      if (device.type == audio_session.AudioDeviceType.wiredHeadphones ||
          device.type == audio_session.AudioDeviceType.wiredHeadset) {
        return true;
      }

      // Check for Bluetooth audio devices
      if (device.type == audio_session.AudioDeviceType.bluetoothA2dp ||
          device.type == audio_session.AudioDeviceType.bluetoothSco) {
        return true;
      }

      // iOS-specific: Check for Bluetooth HFP
      // coverage:ignore-start
      if (!kIsWeb &&
          Platform.isIOS &&
          device.type == audio_session.AudioDeviceType.bluetoothLe) {
        return true;
      }
      // coverage:ignore-end
    }
    return false;
  }

  /// Loads audio from a URL or asset path.
  ///
  /// Supports:
  /// - HTTP/HTTPS URLs for remote audio
  /// - `asset://` URLs for bundled sounds (e.g., "asset://assets/sounds/bruh.mp3")
  ///
  /// Returns the duration of the loaded audio.
  Future<Duration?> loadAudio(String url) async {
    if (_isDisposed) return null;
    _loadCompleter = Completer<void>();
    try {
      Duration? loadedDuration;

      // Check if this is a bundled asset URL
      if (url.startsWith('asset://')) {
        final assetPath = url.substring('asset://'.length);
        loadedDuration = await _audioPlayer.setAsset(assetPath);
        log(
          'Loaded audio from asset: $assetPath',
          name: 'AudioPlaybackService',
        );
      } else {
        loadedDuration = await _audioPlayer.setUrl(url);
        log(
          'Loaded audio from URL: $url',
          name: 'AudioPlaybackService',
        );
      }

      _lastSource = (type: _SourceType.url, value: url);
      return loadedDuration;
    } catch (e) {
      log(
        'Failed to load audio from $url: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    } finally {
      _loadCompleter?.complete();
      _loadCompleter = null;
    }
  }

  /// Loads audio from a local file path.
  ///
  /// Returns the duration of the loaded audio.
  Future<Duration?> loadAudioFromFile(String filePath) async {
    if (_isDisposed) return null;
    _loadCompleter = Completer<void>();
    try {
      final loadedDuration = await _audioPlayer.setFilePath(filePath);
      log(
        'Loaded audio from file: $filePath',
        name: 'AudioPlaybackService',
      );
      _lastSource = (type: _SourceType.file, value: filePath);
      return loadedDuration;
    } catch (e) {
      log(
        'Failed to load audio from file $filePath: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    } finally {
      _loadCompleter?.complete();
      _loadCompleter = null;
    }
  }

  /// Sets an audio source from a library-agnostic [AudioSourceConfig].
  ///
  /// Converts the config into the appropriate player-specific source type.
  /// If [AudioSourceConfig.isClipped], wraps the source in a
  /// [ClippingAudioSource].
  Future<Duration?> setAudioSource(AudioSourceConfig config) async {
    if (_isDisposed) return null;
    _loadCompleter = Completer<void>();
    try {
      final UriAudioSource child;
      if (config.isAsset) {
        child = AudioSource.asset(config.uri);
      } else if (config.isFile) {
        child = AudioSource.file(config.uri);
      } else {
        child = AudioSource.uri(Uri.parse(config.uri));
      }

      final AudioSource source;
      if (config.isClipped) {
        source = ClippingAudioSource(
          child: child,
          start: config.start,
          end: config.end,
        );
      } else {
        source = child;
      }

      final loadedDuration = await _audioPlayer.setAudioSource(source);
      log(
        'Set audio source: ${source.runtimeType}',
        name: 'AudioPlaybackService',
      );
      _lastSource = (type: _SourceType.audioSource, value: config);
      return loadedDuration;
    } catch (e) {
      log(
        'Failed to set audio source: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    } finally {
      _loadCompleter?.complete();
      _loadCompleter = null;
    }
  }

  /// Starts audio playback.
  ///
  /// If audio is currently loading, waits for the load to complete first.
  /// On transient "Loading interrupted" errors, reloads the source and
  /// retries once.
  Future<void> play() async {
    if (_isDisposed) return;
    await _loadCompleter?.future;
    if (_isDisposed) return;
    try {
      await _audioPlayer.play();
      log('Started audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      if (_isLoadingInterrupted(e)) {
        log(
          'Play interrupted, reloading source and retrying',
          name: 'AudioPlaybackService',
          level: 800,
        );
        if (await _reloadLastSource()) {
          if (_isDisposed) return;
          await _audioPlayer.play();
          return;
        }
      }
      log(
        'Failed to start playback: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Pauses audio playback.
  Future<void> pause() async {
    if (_isDisposed) return;
    try {
      await _audioPlayer.pause();
      log('Paused audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      log(
        'Failed to pause playback: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Stops audio playback and resets position to the beginning.
  Future<void> stop() async {
    if (_isDisposed) return;
    try {
      await _audioPlayer.stop();
      log('Stopped audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      log(
        'Failed to stop playback: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Seeks to a specific position in the audio.
  ///
  /// If audio is currently loading, waits for the load to complete first.
  /// On transient "Loading interrupted" errors, reloads the source and
  /// retries once.
  Future<void> seek(Duration position) async {
    if (_isDisposed) return;
    await _loadCompleter?.future;
    if (_isDisposed) return;
    try {
      await _audioPlayer.seek(position);
      log(
        'Seeked to position: ${position.inSeconds}s',
        name: 'AudioPlaybackService',
      );
    } catch (e) {
      if (_isLoadingInterrupted(e)) {
        log(
          'Seek interrupted, reloading source and retrying',
          name: 'AudioPlaybackService',
        );
        if (await _reloadLastSource()) {
          if (_isDisposed) return;
          await _audioPlayer.seek(position);
          return;
        }
      }
      rethrow;
    }
  }

  /// Sets the playback volume.
  ///
  /// [volume] should be between 0.0 (muted) and 1.0 (full volume).
  Future<void> setVolume(double volume) async {
    if (_isDisposed) return;
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
      log(
        'Set volume to: ${(volume * 100).toInt()}%',
        name: 'AudioPlaybackService',
      );
    } catch (e) {
      log(
        'Failed to set volume: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Configures the audio session for recording mode.
  ///
  /// This sets up the audio session to:
  /// - Allow audio playback during recording via A2DP to Bluetooth headphones
  /// - Use built-in microphone for recording (NOT Bluetooth mic)
  /// - Route to speaker when no headphones connected
  ///
  /// IMPORTANT: Only uses allowBluetoothA2dp, NOT allowBluetooth.
  /// allowBluetooth enables HFP (phone call mode) which causes
  /// "call started/ended" sounds on Bluetooth headsets.
  Future<void> configureForRecording() async {
    if (_isDisposed) return;
    try {
      await _audioSessionWrapper.configure(
        audio_session.AudioSessionConfiguration(
          avAudioSessionCategory:
              audio_session.AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              audio_session.AVAudioSessionCategoryOptions.defaultToSpeaker |
              audio_session.AVAudioSessionCategoryOptions.allowBluetoothA2dp,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              audio_session.AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );

      log(
        'Configured audio session for recording mode',
        name: 'AudioPlaybackService',
      );
    } on Exception catch (e) {
      log(
        'Failed to configure audio session for recording: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      // Don't rethrow - allow playback to continue even if session config fails
    }
  }

  /// Configures the audio session for mixed playback.
  ///
  /// This allows audio to play simultaneously with other audio sources
  /// (e.g., video player). Use this in the video editor to prevent
  /// the audio from pausing the video.
  Future<void> configureForMixedPlayback() async {
    if (_isDisposed) return;
    try {
      await _audioSessionWrapper.configure(
        const audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              audio_session.AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              audio_session.AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );

      log(
        'Configured audio session for mixed playback',
        name: 'AudioPlaybackService',
      );
    } on Exception catch (e) {
      log(
        'Failed to configure audio session for mixed playback: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      // Don't rethrow - allow playback to continue even if session config fails
    }
  }

  /// Resets the audio session to default configuration.
  ///
  /// Call this when exiting recording mode.
  Future<void> resetAudioSession() async {
    if (_isDisposed) return;
    try {
      await _audioSessionWrapper.configure(
        const audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              audio_session.AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              audio_session.AVAudioSessionRouteSharingPolicy.defaultPolicy,
          androidAudioFocusGainType:
              audio_session.AndroidAudioFocusGainType.gainTransientMayDuck,
          avAudioSessionSetActiveOptions:
              audio_session.AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.media,
          ),
          androidWillPauseWhenDucked: true,
        ),
      );

      log(
        'Reset audio session to default',
        name: 'AudioPlaybackService',
      );
    } on Exception catch (e) {
      log(
        'Failed to reset audio session: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      // Don't rethrow - allow continued operation even if reset fails
    }
  }

  /// Disposes of all resources used by this service.
  ///
  /// Must be called when the service is no longer needed.
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;
    await _deviceChangeSubscription?.cancel();
    await _headphonesConnectedSubject.close();
    await _audioPlayer.dispose();

    log(
      'AudioPlaybackService disposed',
      name: 'AudioPlaybackService',
    );
  }

  /// Returns `true` if the error is a transient "Loading interrupted" error
  /// from just_audio that can be recovered by reloading the source.
  bool _isLoadingInterrupted(Object error) =>
      error.toString().contains('Loading interrupted');

  /// Reloads the last audio source that was successfully set.
  ///
  /// Returns `true` if the reload succeeded, `false` otherwise.
  Future<bool> _reloadLastSource() async {
    final source = _lastSource;
    if (source == null || _isDisposed) return false;

    try {
      switch (source.type) {
        case _SourceType.url:
          await loadAudio(source.value as String);
        case _SourceType.file:
          await loadAudioFromFile(source.value as String);
        case _SourceType.audioSource:
          await setAudioSource(source.value as AudioSourceConfig);
      }
      log(
        'Reloaded audio source after interruption',
        name: 'AudioPlaybackService',
      );
      return true;
    } on Exception catch (e) {
      log(
        'Failed to reload audio source: $e',
        name: 'AudioPlaybackService',
        level: 900,
      );
      return false;
    }
  }
}

/// The type of audio source last loaded into the player.
enum _SourceType { url, file, audioSource }

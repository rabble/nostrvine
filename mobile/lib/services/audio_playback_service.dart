// ABOUTME: Service for audio playback during recording with headphone detection
// ABOUTME: Manages audio session configuration and exposes playback streams

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:rxdart/rxdart.dart';

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
  AudioPlaybackService({AudioPlayer? audioPlayer})
    : _audioPlayer = audioPlayer ?? AudioPlayer() {
    _initializeHeadphoneDetection();
  }

  final AudioPlayer _audioPlayer;

  /// BehaviorSubject for headphone connection state.
  /// Starts with false (no headphones) until actual state is determined.
  final BehaviorSubject<bool> _headphonesConnectedSubject =
      BehaviorSubject<bool>.seeded(false);

  StreamSubscription<dynamic>? _deviceChangeSubscription;
  bool _isDisposed = false;

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
      final session = await AudioSession.instance;

      // Check initial headphone state
      final devices = await session.getDevices();
      final hasHeadphones = _checkForHeadphones(devices);
      if (!_isDisposed) {
        _headphonesConnectedSubject.add(hasHeadphones);
      }

      // Listen for device changes
      _deviceChangeSubscription = session.devicesChangedEventStream.listen(
        (event) {
          if (_isDisposed) return;

          // Re-check all connected devices for accuracy when any device changes
          session.getDevices().then((allDevices) {
            if (!_isDisposed) {
              _headphonesConnectedSubject.add(_checkForHeadphones(allDevices));
            }
          });
        },
        onError: (error) {
          Log.error(
            'Error in device change stream: $error',
            name: 'AudioPlaybackService',
          );
        },
      );

      Log.info(
        'Headphone detection initialized. Connected: $hasHeadphones',
        name: 'AudioPlaybackService',
      );
    } catch (e) {
      Log.error(
        'Failed to initialize headphone detection: $e',
        name: 'AudioPlaybackService',
      );
      // Default to false if detection fails
      if (!_isDisposed) {
        _headphonesConnectedSubject.add(false);
      }
    }
  }

  /// Checks if any of the given devices are headphones or external audio.
  bool _checkForHeadphones(Set<AudioDevice> devices) {
    for (final device in devices) {
      // Check for wired headphones
      if (device.type == AudioDeviceType.wiredHeadphones ||
          device.type == AudioDeviceType.wiredHeadset) {
        return true;
      }

      // Check for Bluetooth audio devices
      if (device.type == AudioDeviceType.bluetoothA2dp ||
          device.type == AudioDeviceType.bluetoothSco) {
        return true;
      }

      // iOS-specific: Check for Bluetooth HFP
      if (Platform.isIOS && device.type == AudioDeviceType.bluetoothLe) {
        return true;
      }
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
    try {
      Duration? duration;

      // Check if this is a bundled asset URL
      if (url.startsWith('asset://')) {
        final assetPath = url.substring('asset://'.length);
        duration = await _audioPlayer.setAsset(assetPath);
        Log.info(
          'Loaded audio from asset: $assetPath (duration: ${duration?.inSeconds}s)',
          name: 'AudioPlaybackService',
        );
      } else {
        duration = await _audioPlayer.setUrl(url);
        Log.info(
          'Loaded audio from URL: $url (duration: ${duration?.inSeconds}s)',
          name: 'AudioPlaybackService',
        );
      }

      return duration;
    } catch (e) {
      Log.error(
        'Failed to load audio from $url: $e',
        name: 'AudioPlaybackService',
      );
      rethrow;
    }
  }

  /// Loads audio from a local file path.
  ///
  /// Returns the duration of the loaded audio.
  Future<Duration?> loadAudioFromFile(String filePath) async {
    try {
      final duration = await _audioPlayer.setFilePath(filePath);
      Log.info(
        'Loaded audio from file: $filePath (duration: ${duration?.inSeconds}s)',
        name: 'AudioPlaybackService',
      );
      return duration;
    } catch (e) {
      Log.error(
        'Failed to load audio from file $filePath: $e',
        name: 'AudioPlaybackService',
      );
      rethrow;
    }
  }

  /// Starts audio playback.
  Future<void> play() async {
    try {
      await _audioPlayer.play();
      Log.info('Started audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      Log.error('Failed to start playback: $e', name: 'AudioPlaybackService');
      rethrow;
    }
  }

  /// Pauses audio playback.
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      Log.info('Paused audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      Log.error('Failed to pause playback: $e', name: 'AudioPlaybackService');
      rethrow;
    }
  }

  /// Stops audio playback and resets position to the beginning.
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      Log.info('Stopped audio playback', name: 'AudioPlaybackService');
    } catch (e) {
      Log.error('Failed to stop playback: $e', name: 'AudioPlaybackService');
      rethrow;
    }
  }

  /// Seeks to a specific position in the audio.
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      Log.info(
        'Seeked to position: ${position.inSeconds}s',
        name: 'AudioPlaybackService',
      );
    } catch (e) {
      Log.error('Failed to seek: $e', name: 'AudioPlaybackService');
      rethrow;
    }
  }

  /// Sets the playback volume.
  ///
  /// [volume] should be between 0.0 (muted) and 1.0 (full volume).
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
      Log.info(
        'Set volume to: ${(volume * 100).toInt()}%',
        name: 'AudioPlaybackService',
      );
    } catch (e) {
      Log.error('Failed to set volume: $e', name: 'AudioPlaybackService');
      rethrow;
    }
  }

  /// Configures the audio session for recording mode.
  ///
  /// This sets up the audio session to:
  /// - Allow audio playback during recording
  /// - Mix with other audio when appropriate
  /// - Handle interruptions properly
  Future<void> configureForRecording() async {
    try {
      final session = await AudioSession.instance;

      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.allowBluetoothA2dp,
          avAudioSessionMode: AVAudioSessionMode.videoRecording,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: false,
        ),
      );

      Log.info(
        'Configured audio session for recording mode',
        name: 'AudioPlaybackService',
      );
    } catch (e) {
      Log.error(
        'Failed to configure audio session for recording: $e',
        name: 'AudioPlaybackService',
      );
      // Don't rethrow - allow playback to continue even if session config fails
    }
  }

  /// Resets the audio session to default configuration.
  ///
  /// Call this when exiting recording mode.
  Future<void> resetAudioSession() async {
    try {
      final session = await AudioSession.instance;

      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );

      Log.info('Reset audio session to default', name: 'AudioPlaybackService');
    } catch (e) {
      Log.error(
        'Failed to reset audio session: $e',
        name: 'AudioPlaybackService',
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

    Log.info('AudioPlaybackService disposed', name: 'AudioPlaybackService');
  }
}

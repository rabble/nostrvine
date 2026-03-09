import 'dart:async';

import 'package:audio_session/audio_session.dart' as audio_session;

/// Abstract interface for audio session operations.
///
/// This abstraction allows for dependency injection and mocking
/// of audio session functionality in tests.
abstract class AudioSessionWrapper {
  /// Gets the set of currently connected audio devices.
  Future<Set<audio_session.AudioDevice>> getDevices();

  /// Stream of device change events.
  Stream<audio_session.AudioDevicesChangedEvent> get devicesChangedEventStream;

  /// Configures the audio session with the given configuration.
  Future<void> configure(audio_session.AudioSessionConfiguration config);
}

// coverage:ignore-start
/// Default implementation that wraps the real AudioSession.
class DefaultAudioSessionWrapper implements AudioSessionWrapper {
  /// Creates a new DefaultAudioSessionWrapper.
  DefaultAudioSessionWrapper();

  audio_session.AudioSession? _session;

  Future<audio_session.AudioSession> _getSession() async {
    return _session ??= await audio_session.AudioSession.instance;
  }

  @override
  Future<Set<audio_session.AudioDevice>> getDevices() async {
    final session = await _getSession();
    return session.getDevices();
  }

  @override
  Stream<audio_session.AudioDevicesChangedEvent>
  get devicesChangedEventStream async* {
    final session = await _getSession();
    yield* session.devicesChangedEventStream;
  }

  @override
  Future<void> configure(audio_session.AudioSessionConfiguration config) async {
    final session = await _getSession();
    await session.configure(config);
  }
}

// coverage:ignore-end

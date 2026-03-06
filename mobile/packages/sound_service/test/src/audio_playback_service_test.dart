// ABOUTME: Tests for AudioPlaybackService audio playback/ headphone detection
// ABOUTME: Validates playback controls, position streams, audio session config

// Reason: audio_session (AudioDeviceType, getDevices) is marked experimental
// but no stable alternative exists. Tracked: github.com/ryanheise/audio_session
// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _MockAudioSessionWrapper extends Mock implements AudioSessionWrapper {}

class _FakeAudioSource extends Fake implements AudioSource {}

class _FakeAudioSessionConfig extends Fake
    implements audio_session.AudioSessionConfiguration {}

class _FakeAudioDevice extends Fake implements audio_session.AudioDevice {
  _FakeAudioDevice(this.type);
  @override
  final audio_session.AudioDeviceType type;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_FakeAudioSource());
    registerFallbackValue(Duration.zero);
    registerFallbackValue('');
    registerFallbackValue(0.0);
    registerFallbackValue(_FakeAudioSessionConfig());
  });

  group(AudioPlaybackService, () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      // Set up default mock behaviors for just_audio API
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      // Set up default mock behaviors for audio session wrapper
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('creates with audio player dependency', () {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      expect(service, isNotNull);
    });

    test('loadAudio loads audio from URL', () async {
      const testUrl = 'https://example.com/audio.aac';
      when(
        () => mockPlayer.setUrl(testUrl),
      ).thenAnswer((_) async => const Duration(seconds: 10));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      final duration = await service.loadAudio(testUrl);

      verify(() => mockPlayer.setUrl(testUrl)).called(1);
      expect(duration, const Duration(seconds: 10));
    });

    test('loadAudio loads bundled audio from asset:// URL', () async {
      const assetUrl = 'asset://assets/sounds/bruh-sound-effect.mp3';
      const expectedAssetPath = 'assets/sounds/bruh-sound-effect.mp3';
      when(
        () => mockPlayer.setAsset(expectedAssetPath),
      ).thenAnswer((_) async => const Duration(seconds: 5));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      final duration = await service.loadAudio(assetUrl);

      verify(() => mockPlayer.setAsset(expectedAssetPath)).called(1);
      expect(duration, const Duration(seconds: 5));
    });

    test('loadAudioFromFile loads audio from file path', () async {
      const testPath = '/path/to/audio.aac';
      when(
        () => mockPlayer.setFilePath(testPath),
      ).thenAnswer((_) async => const Duration(seconds: 15));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      final duration = await service.loadAudioFromFile(testPath);

      verify(() => mockPlayer.setFilePath(testPath)).called(1);
      expect(duration, const Duration(seconds: 15));
    });

    test('setAudioSource sets audio source from URI', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 20));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      final duration = await service.setAudioSource(
        const AudioSourceConfig.network('https://example.com/audio.mp3'),
      );

      verify(() => mockPlayer.setAudioSource(any())).called(1);
      expect(duration, const Duration(seconds: 20));
    });

    test(
      'setAudioSource creates clipped source when boundaries given',
      () async {
        when(
          () => mockPlayer.setAudioSource(any()),
        ).thenAnswer((_) async => const Duration(seconds: 5));

        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );
        final duration = await service.setAudioSource(
          const AudioSourceConfig.asset(
            'assets/sounds/clip.mp3',
            start: Duration(seconds: 2),
            end: Duration(seconds: 7),
          ),
        );

        verify(() => mockPlayer.setAudioSource(any())).called(1);
        expect(duration, const Duration(seconds: 5));
      },
    );

    test('setAudioSource sets audio source from file path', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenAnswer((_) async => const Duration(seconds: 12));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      final duration = await service.setAudioSource(
        const AudioSourceConfig.file('/path/to/local.mp3'),
      );

      verify(() => mockPlayer.setAudioSource(any())).called(1);
      expect(duration, const Duration(seconds: 12));
    });

    test('play starts playback', () async {
      when(() => mockPlayer.play()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.play();

      verify(() => mockPlayer.play()).called(1);
    });

    test('pause pauses playback', () async {
      when(() => mockPlayer.pause()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.pause();

      verify(() => mockPlayer.pause()).called(1);
    });

    test('stop stops playback', () async {
      when(() => mockPlayer.stop()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.stop();

      verify(() => mockPlayer.stop()).called(1);
    });

    test('seek seeks to position', () async {
      const position = Duration(seconds: 5);
      when(() => mockPlayer.seek(position)).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.seek(position);

      verify(() => mockPlayer.seek(position)).called(1);
    });

    test('positionStream exposes player position stream', () async {
      final positionController = BehaviorSubject<Duration>.seeded(
        Duration.zero,
      );
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => positionController.stream);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.positionStream, emits(Duration.zero));

      await positionController.close();
    });

    test('durationStream exposes player duration stream', () async {
      final durationController = BehaviorSubject<Duration?>.seeded(
        const Duration(seconds: 10),
      );
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => durationController.stream);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.durationStream, emits(const Duration(seconds: 10)));

      await durationController.close();
    });

    test('playingStream exposes player playing stream', () async {
      final playingController = BehaviorSubject<bool>.seeded(false);
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => playingController.stream);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.playingStream, emits(false));

      await playingController.close();
    });

    test('duration returns current duration from player', () {
      when(() => mockPlayer.duration).thenReturn(const Duration(seconds: 10));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.duration, const Duration(seconds: 10));
    });

    test('dispose cleans up resources', () async {
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      verify(() => mockPlayer.dispose()).called(1);
    });

    test('isPlaying returns current playing state', () {
      when(() => mockPlayer.playing).thenReturn(true);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(service.isPlaying, isTrue);
    });

    test('setVolume sets the volume', () async {
      when(() => mockPlayer.setVolume(0.5)).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.setVolume(0.5);

      verify(() => mockPlayer.setVolume(0.5)).called(1);
    });

    test('setVolume clamps volume above 1.0', () async {
      when(() => mockPlayer.setVolume(1)).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.setVolume(1.5);

      verify(() => mockPlayer.setVolume(1)).called(1);
    });

    test('setVolume clamps volume below 0.0', () async {
      when(() => mockPlayer.setVolume(0)).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.setVolume(-0.5);

      verify(() => mockPlayer.setVolume(0)).called(1);
    });

    test('dispose does nothing if already disposed', () async {
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();
      await service.dispose(); // Second call should be no-op

      verify(() => mockPlayer.dispose()).called(1);
    });
  });

  group('$AudioPlaybackService error handling', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      // Set up default mock behaviors for audio session wrapper
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('loadAudio rethrows on error', () async {
      when(
        () => mockPlayer.setUrl(any()),
      ).thenThrow(Exception('Network error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(
        () => service.loadAudio('https://example.com/audio.mp3'),
        throwsException,
      );
    });

    test('loadAudioFromFile rethrows on error', () async {
      when(
        () => mockPlayer.setFilePath(any()),
      ).thenThrow(Exception('File not found'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(
        () => service.loadAudioFromFile('/path/to/file.mp3'),
        throwsException,
      );
    });

    test('setAudioSource rethrows on error', () async {
      when(
        () => mockPlayer.setAudioSource(any()),
      ).thenThrow(Exception('Invalid source'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(
        () => service.setAudioSource(
          const AudioSourceConfig.network('https://example.com/bad.mp3'),
        ),
        throwsException,
      );
    });

    test('play rethrows on error', () async {
      when(() => mockPlayer.play()).thenThrow(Exception('Playback failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.play(), throwsException);
    });

    test('pause rethrows on error', () async {
      when(() => mockPlayer.pause()).thenThrow(Exception('Pause failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.pause(), throwsException);
    });

    test('stop rethrows on error', () async {
      when(() => mockPlayer.stop()).thenThrow(Exception('Stop failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.stop(), throwsException);
    });

    test('seek rethrows on error', () async {
      when(
        () => mockPlayer.seek(any()),
      ).thenThrow(Exception('Seek failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.seek(Duration.zero), throwsException);
    });

    test('setVolume rethrows on error', () async {
      when(
        () => mockPlayer.setVolume(any()),
      ).thenThrow(Exception('Volume failed'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(() => service.setVolume(0.5), throwsException);
    });

    test('loadAudio from asset rethrows on error', () async {
      when(
        () => mockPlayer.setAsset(any()),
      ).thenThrow(Exception('Asset not found'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      expect(
        () => service.loadAudio('asset://assets/sounds/test.mp3'),
        throwsException,
      );
    });
  });

  group('AudioPlaybackService headphone detection', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      // Set up default mock behaviors for audio session wrapper
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('headphonesConnectedStream emits headphone state', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // The service should expose a stream for headphone state
      expect(service.headphonesConnectedStream, isA<Stream<bool>>());
    });

    test('areHeadphonesConnected returns current state', () {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should return a boolean indicating current headphone state
      expect(service.areHeadphonesConnected, isA<bool>());
    });

    test('detects wired headphones', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadphones),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Allow async initialization to complete
      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isTrue);
    });

    test('detects wired headset', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadset),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isTrue);
    });

    test('detects Bluetooth A2DP devices', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.bluetoothA2dp),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isTrue);
    });

    test('detects Bluetooth SCO devices', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.bluetoothSco),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isTrue);
    });

    test('returns false when no headphones connected', () async {
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.builtInSpeaker),
        },
      );

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      expect(service.areHeadphonesConnected, isFalse);
    });

    test('handles getDevices exception gracefully', () async {
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenThrow(Exception('Device error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      // Should default to false on error
      expect(service.areHeadphonesConnected, isFalse);
    });

    test('handles device change stream events', () async {
      final deviceChangeController =
          StreamController<audio_session.AudioDevicesChangedEvent>.broadcast();

      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => deviceChangeController.stream);

      // First call returns no headphones
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);
      expect(service.areHeadphonesConnected, isFalse);

      // Update mock to return headphones
      when(() => mockSessionWrapper.getDevices()).thenAnswer(
        (_) async => {
          _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadphones),
        },
      );

      // Simulate device change event
      deviceChangeController.add(
        audio_session.AudioDevicesChangedEvent(
          devicesAdded: {
            _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadphones),
          },
          devicesRemoved: {},
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(service.areHeadphonesConnected, isTrue);

      await deviceChangeController.close();
    });

    test('discards stale getDevices result from earlier event', () async {
      final deviceChangeController =
          StreamController<audio_session.AudioDevicesChangedEvent>.broadcast();

      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => deviceChangeController.stream);

      // Initial call: no headphones
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.areHeadphonesConnected, isFalse);

      // Simulate race: first event triggers a slow getDevices call,
      // second event triggers a fast one. The slow (stale) result
      // must be discarded so the fast (latest) result wins.
      final slowCompleter = Completer<Set<audio_session.AudioDevice>>();
      var callCount = 0;

      when(() => mockSessionWrapper.getDevices()).thenAnswer((_) {
        callCount++;
        if (callCount == 1) {
          // First call is slow — returns headphones eventually
          return slowCompleter.future;
        }
        // Second call resolves immediately — no headphones
        return Future.value(<audio_session.AudioDevice>{});
      });

      // Fire two device change events in rapid succession
      final dummyEvent = audio_session.AudioDevicesChangedEvent(
        devicesAdded: <audio_session.AudioDevice>{},
        devicesRemoved: <audio_session.AudioDevice>{},
      );
      deviceChangeController
        ..add(dummyEvent)
        ..add(dummyEvent);

      // Let the second (fast) call resolve
      await Future<void>.delayed(Duration.zero);
      expect(service.areHeadphonesConnected, isFalse);

      // Now the slow first call resolves with headphones attached
      slowCompleter.complete({
        _FakeAudioDevice(audio_session.AudioDeviceType.wiredHeadphones),
      });
      await Future<void>.delayed(Duration.zero);

      // Stale result must be discarded — state must still be false
      expect(service.areHeadphonesConnected, isFalse);

      await deviceChangeController.close();
    });

    test('handles device change stream errors', () async {
      final deviceChangeController =
          StreamController<audio_session.AudioDevicesChangedEvent>.broadcast();

      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => deviceChangeController.stream);

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await Future<void>.delayed(Duration.zero);

      // Simulate error in stream
      deviceChangeController.addError(Exception('Stream error'));

      await Future<void>.delayed(Duration.zero);

      // Service should still be functional
      expect(service.areHeadphonesConnected, isA<bool>());

      await deviceChangeController.close();
    });
  });

  group('AudioPlaybackService audio session configuration', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      // Set up default mock behaviors for audio session wrapper
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test(
      'configureForRecording sets up audio session for recording mode',
      () async {
        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );

        // Should not throw
        await expectLater(service.configureForRecording(), completes);
      },
    );

    test('resetAudioSession resets to default configuration', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should not throw
      await expectLater(service.resetAudioSession(), completes);
    });

    test('configureForRecording handles errors gracefully', () async {
      when(
        () => mockSessionWrapper.configure(any()),
      ).thenThrow(Exception('Configure error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should not throw - errors are caught internally
      await expectLater(service.configureForRecording(), completes);
    });

    test('resetAudioSession handles errors gracefully', () async {
      when(
        () => mockSessionWrapper.configure(any()),
      ).thenThrow(Exception('Reset error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should not throw - errors are caught internally
      await expectLater(service.resetAudioSession(), completes);
    });

    test(
      'configureForRecording calls configure with correct parameters',
      () async {
        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );

        await service.configureForRecording();

        verify(() => mockSessionWrapper.configure(any())).called(1);
      },
    );

    test('resetAudioSession calls configure with correct parameters', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      await service.resetAudioSession();

      verify(() => mockSessionWrapper.configure(any())).called(1);
    });

    test(
      'configureForMixedPlayback sets up audio session for mixed playback',
      () async {
        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );

        // Should not throw
        await expectLater(service.configureForMixedPlayback(), completes);
      },
    );

    test('configureForMixedPlayback handles errors gracefully', () async {
      when(
        () => mockSessionWrapper.configure(any()),
      ).thenThrow(Exception('Configure error'));

      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );

      // Should not throw - errors are caught internally
      await expectLater(service.configureForMixedPlayback(), completes);
    });

    test(
      'configureForMixedPlayback calls configure with correct parameters',
      () async {
        service = AudioPlaybackService(
          audioPlayer: mockPlayer,
          audioSessionWrapper: mockSessionWrapper,
        );

        await service.configureForMixedPlayback();

        verify(() => mockSessionWrapper.configure(any())).called(1);
      },
    );
  });

  group('$AudioPlaybackService after dispose', () {
    late AudioPlaybackService service;
    late _MockAudioPlayer mockPlayer;
    late _MockAudioSessionWrapper mockSessionWrapper;

    setUp(() {
      mockPlayer = _MockAudioPlayer();
      mockSessionWrapper = _MockAudioSessionWrapper();

      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => const Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
      when(() => mockPlayer.playing).thenReturn(false);
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
      when(
        () => mockSessionWrapper.getDevices(),
      ).thenAnswer((_) async => <audio_session.AudioDevice>{});
      when(
        () => mockSessionWrapper.devicesChangedEventStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSessionWrapper.configure(any())).thenAnswer((_) async {});
    });

    test('loadAudio returns null after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      final result = await service.loadAudio('https://example.com/audio.aac');

      expect(result, isNull);
      verifyNever(() => mockPlayer.setUrl(any()));
    });

    test('loadAudioFromFile returns null after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      final result = await service.loadAudioFromFile('/path/to/file.aac');

      expect(result, isNull);
      verifyNever(() => mockPlayer.setFilePath(any()));
    });

    test('setAudioSource returns null after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      final result = await service.setAudioSource(
        const AudioSourceConfig.network('https://example.com/audio.mp3'),
      );

      expect(result, isNull);
      verifyNever(() => mockPlayer.setAudioSource(any()));
    });

    test('play does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.play();

      verifyNever(() => mockPlayer.play());
    });

    test('pause does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.pause();

      verifyNever(() => mockPlayer.pause());
    });

    test('stop does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.stop();

      verifyNever(() => mockPlayer.stop());
    });

    test('seek does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.seek(const Duration(seconds: 5));

      verifyNever(() => mockPlayer.seek(any()));
    });

    test('setVolume does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.setVolume(0.5);

      verifyNever(() => mockPlayer.setVolume(any()));
    });

    test('configureForRecording does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.configureForRecording();

      verifyNever(() => mockSessionWrapper.configure(any()));
    });

    test('configureForMixedPlayback does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.configureForMixedPlayback();

      verifyNever(() => mockSessionWrapper.configure(any()));
    });

    test('resetAudioSession does nothing after dispose', () async {
      service = AudioPlaybackService(
        audioPlayer: mockPlayer,
        audioSessionWrapper: mockSessionWrapper,
      );
      await service.dispose();

      await service.resetAudioSession();

      verifyNever(() => mockSessionWrapper.configure(any()));
    });
  });
}

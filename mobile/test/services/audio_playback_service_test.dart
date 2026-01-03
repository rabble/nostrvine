// ABOUTME: Tests for AudioPlaybackService audio playback and headphone detection
// ABOUTME: Validates playback controls, position streams, and audio session config

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/audio_playback_service.dart';
import 'package:rxdart/rxdart.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  group('AudioPlaybackService', () {
    late AudioPlaybackService service;
    late MockAudioPlayer mockPlayer;

    setUp(() {
      mockPlayer = MockAudioPlayer();

      // Set up default mock behaviors
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => Stream<bool>.empty());
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('creates with audio player dependency', () {
      service = AudioPlaybackService(audioPlayer: mockPlayer);
      expect(service, isNotNull);
    });

    test('loadAudio loads audio from URL', () async {
      const testUrl = 'https://example.com/audio.aac';
      when(
        () => mockPlayer.setUrl(testUrl),
      ).thenAnswer((_) async => const Duration(seconds: 10));

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.loadAudio(testUrl);

      verify(() => mockPlayer.setUrl(testUrl)).called(1);
    });

    test('loadAudio loads bundled audio from asset:// URL', () async {
      const assetUrl = 'asset://assets/sounds/bruh-sound-effect.mp3';
      const expectedAssetPath = 'assets/sounds/bruh-sound-effect.mp3';
      when(
        () => mockPlayer.setAsset(expectedAssetPath),
      ).thenAnswer((_) async => const Duration(seconds: 1));

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.loadAudio(assetUrl);

      verify(() => mockPlayer.setAsset(expectedAssetPath)).called(1);
      verifyNever(() => mockPlayer.setUrl(any()));
    });

    test('loadAudio from file path', () async {
      const testPath = '/path/to/audio.aac';
      when(
        () => mockPlayer.setFilePath(testPath),
      ).thenAnswer((_) async => const Duration(seconds: 5));

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.loadAudioFromFile(testPath);

      verify(() => mockPlayer.setFilePath(testPath)).called(1);
    });

    test('play starts playback', () async {
      when(() => mockPlayer.play()).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.play();

      verify(() => mockPlayer.play()).called(1);
    });

    test('pause pauses playback', () async {
      when(() => mockPlayer.pause()).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.pause();

      verify(() => mockPlayer.pause()).called(1);
    });

    test('stop stops playback', () async {
      when(() => mockPlayer.stop()).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.stop();

      verify(() => mockPlayer.stop()).called(1);
    });

    test('seek seeks to position', () async {
      const position = Duration(seconds: 5);
      when(() => mockPlayer.seek(position)).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
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

      service = AudioPlaybackService(audioPlayer: mockPlayer);

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

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(service.durationStream, emits(const Duration(seconds: 10)));

      await durationController.close();
    });

    test('playingStream exposes player playing stream', () async {
      final playingController = BehaviorSubject<bool>.seeded(false);
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => playingController.stream);

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(service.playingStream, emits(false));

      await playingController.close();
    });

    test('duration returns current duration', () {
      when(() => mockPlayer.duration).thenReturn(const Duration(seconds: 10));

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(service.duration, const Duration(seconds: 10));
    });

    test('dispose cleans up resources', () async {
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.dispose();

      verify(() => mockPlayer.dispose()).called(1);
    });

    test('isPlaying returns current playing state', () {
      when(() => mockPlayer.playing).thenReturn(true);

      service = AudioPlaybackService(audioPlayer: mockPlayer);

      expect(service.isPlaying, isTrue);
    });

    test('setVolume sets the volume', () async {
      when(() => mockPlayer.setVolume(0.5)).thenAnswer((_) async {});

      service = AudioPlaybackService(audioPlayer: mockPlayer);
      await service.setVolume(0.5);

      verify(() => mockPlayer.setVolume(0.5)).called(1);
    });
  });

  group('AudioPlaybackService headphone detection', () {
    late AudioPlaybackService service;
    late MockAudioPlayer mockPlayer;

    setUp(() {
      mockPlayer = MockAudioPlayer();
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => Stream<bool>.empty());
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test('headphonesConnectedStream emits headphone state', () async {
      service = AudioPlaybackService(audioPlayer: mockPlayer);

      // The service should expose a stream for headphone state
      expect(service.headphonesConnectedStream, isA<Stream<bool>>());
    });

    test('areHeadphonesConnected returns current state', () {
      service = AudioPlaybackService(audioPlayer: mockPlayer);

      // Should return a boolean indicating current headphone state
      expect(service.areHeadphonesConnected, isA<bool>());
    });
  });

  group('AudioPlaybackService audio session configuration', () {
    late AudioPlaybackService service;
    late MockAudioPlayer mockPlayer;

    setUp(() {
      mockPlayer = MockAudioPlayer();
      when(
        () => mockPlayer.positionStream,
      ).thenAnswer((_) => Stream<Duration>.empty());
      when(
        () => mockPlayer.durationStream,
      ).thenAnswer((_) => Stream<Duration?>.empty());
      when(
        () => mockPlayer.playingStream,
      ).thenAnswer((_) => Stream<bool>.empty());
      when(() => mockPlayer.duration).thenReturn(null);
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await service.dispose();
    });

    test(
      'configureForRecording sets up audio session for recording mode',
      () async {
        service = AudioPlaybackService(audioPlayer: mockPlayer);

        // Should not throw
        await expectLater(service.configureForRecording(), completes);
      },
    );

    test('resetAudioSession resets to default configuration', () async {
      service = AudioPlaybackService(audioPlayer: mockPlayer);

      // Should not throw
      await expectLater(service.resetAudioSession(), completes);
    });
  });
}

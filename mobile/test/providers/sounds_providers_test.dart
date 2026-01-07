// ABOUTME: Tests for sounds_providers.dart Riverpod state management
// ABOUTME: Verifies SoundsRepository provider, trending sounds, and selected sound state

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/repositories/sounds_repository.dart';

// Mock classes
class MockNostrClient extends Mock implements NostrClient {}

class MockSoundsRepository extends Mock implements SoundsRepository {}

/// Helper to create test AudioEvent instances
AudioEvent createTestAudioEvent({
  required String id,
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title ?? 'Test Sound $id',
    duration: duration ?? 5.0,
    mimeType: 'audio/mpeg',
  );
}

void main() {
  group('SoundsProviders', () {
    late MockNostrClient mockNostrClient;
    late MockSoundsRepository mockRepository;

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockRepository = MockSoundsRepository();

      // Default stubs for NostrClient
      when(() => mockNostrClient.hasKeys).thenReturn(false);
    });

    group('soundsRepositoryProvider', () {
      test('creates SoundsRepository with nostrClient', () {
        final container = ProviderContainer(
          overrides: [nostrServiceProvider.overrideWithValue(mockNostrClient)],
        );
        addTearDown(container.dispose);

        final repository = container.read(soundsRepositoryProvider);

        expect(repository, isA<SoundsRepository>());
      });

      test('repository is kept alive (not auto-disposed)', () async {
        final container = ProviderContainer(
          overrides: [nostrServiceProvider.overrideWithValue(mockNostrClient)],
        );
        addTearDown(container.dispose);

        final repo1 = container.read(soundsRepositoryProvider);

        // Force garbage collection by creating pressure
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final repo2 = container.read(soundsRepositoryProvider);

        // Same instance should be returned (keepAlive: true)
        expect(identical(repo1, repo2), isTrue);
      });
    });

    group('selectedSoundProvider', () {
      test('initial state is null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final selectedSound = container.read(selectedSoundProvider);

        expect(selectedSound, isNull);
      });

      test('select() updates state to the selected sound', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final testSound = createTestAudioEvent(id: 'sound-1');

        container.read(selectedSoundProvider.notifier).select(testSound);

        final selectedSound = container.read(selectedSoundProvider);
        expect(selectedSound, equals(testSound));
        expect(selectedSound?.id, equals('sound-1'));
      });

      test('clear() sets state back to null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final testSound = createTestAudioEvent(id: 'sound-1');
        final notifier = container.read(selectedSoundProvider.notifier);

        notifier.select(testSound);
        expect(container.read(selectedSoundProvider), isNotNull);

        notifier.clear();
        expect(container.read(selectedSoundProvider), isNull);
      });

      test('selecting different sound replaces previous', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final sound1 = createTestAudioEvent(id: 'sound-1');
        final sound2 = createTestAudioEvent(id: 'sound-2');
        final notifier = container.read(selectedSoundProvider.notifier);

        notifier.select(sound1);
        expect(container.read(selectedSoundProvider)?.id, equals('sound-1'));

        notifier.select(sound2);
        expect(container.read(selectedSoundProvider)?.id, equals('sound-2'));
      });
    });

    group('trendingSoundsProvider', () {
      test('fetches trending sounds from repository', () async {
        final testSounds = [
          createTestAudioEvent(id: 'trend-1', createdAt: 1704067300),
          createTestAudioEvent(id: 'trend-2', createdAt: 1704067200),
        ];

        when(
          () => mockRepository.fetchTrendingSounds(),
        ).thenAnswer((_) async => testSounds);
        when(() => mockRepository.cachedSounds).thenReturn(testSounds);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        // Wait for the async provider to complete
        final result = await container.read(trendingSoundsProvider.future);

        expect(result.length, equals(2));
        expect(result[0].id, equals('trend-1'));
        expect(result[1].id, equals('trend-2'));
        verify(() => mockRepository.fetchTrendingSounds()).called(1);
      });

      test('refresh() clears cache and fetches fresh data', () async {
        final initialSounds = [createTestAudioEvent(id: 'old-1')];
        final refreshedSounds = [
          createTestAudioEvent(id: 'new-1'),
          createTestAudioEvent(id: 'new-2'),
        ];

        var fetchCount = 0;
        when(() => mockRepository.fetchTrendingSounds()).thenAnswer((_) async {
          fetchCount++;
          return fetchCount == 1 ? initialSounds : refreshedSounds;
        });
        when(() => mockRepository.refresh()).thenAnswer((_) async {});
        when(() => mockRepository.cachedSounds).thenReturn(refreshedSounds);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        // Initial fetch
        await container.read(trendingSoundsProvider.future);

        // Refresh
        await container.read(trendingSoundsProvider.notifier).refresh();

        verify(() => mockRepository.refresh()).called(1);
      });
    });

    group('soundByIdProvider', () {
      test('returns sound from repository when found', () async {
        final testSound = createTestAudioEvent(id: 'specific-sound');

        when(
          () => mockRepository.fetchSoundById('specific-sound'),
        ).thenAnswer((_) async => testSound);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundByIdProvider('specific-sound').future,
        );

        expect(result, equals(testSound));
        expect(result?.id, equals('specific-sound'));
      });

      test('returns null for empty eventId', () async {
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(soundByIdProvider('').future);

        expect(result, isNull);
        verifyNever(() => mockRepository.fetchSoundById(any()));
      });

      test('returns null when sound not found', () async {
        when(
          () => mockRepository.fetchSoundById('nonexistent'),
        ).thenAnswer((_) async => null);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundByIdProvider('nonexistent').future,
        );

        expect(result, isNull);
      });
    });

    group('soundsByCreatorProvider', () {
      test('returns sounds by creator pubkey', () async {
        final creatorPubkey = 'creator-pubkey-123';
        final creatorSounds = [
          createTestAudioEvent(id: 'creator-sound-1', pubkey: creatorPubkey),
          createTestAudioEvent(id: 'creator-sound-2', pubkey: creatorPubkey),
        ];

        when(
          () => mockRepository.fetchSoundsByCreator(creatorPubkey),
        ).thenAnswer((_) async => creatorSounds);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundsByCreatorProvider(creatorPubkey).future,
        );

        expect(result.length, equals(2));
        expect(result.every((s) => s.pubkey == creatorPubkey), isTrue);
      });

      test('returns empty list for empty pubkey', () async {
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(soundsByCreatorProvider('').future);

        expect(result, isEmpty);
        verifyNever(() => mockRepository.fetchSoundsByCreator(any()));
      });
    });

    group('soundUsageCountProvider', () {
      test('returns usage count from repository', () async {
        when(
          () => mockRepository.fetchVideosUsingSoundCount('audio-123'),
        ).thenAnswer((_) async => 42);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final count = await container.read(
          soundUsageCountProvider('audio-123').future,
        );

        expect(count, equals(42));
      });

      test('returns 0 for empty audioEventId', () async {
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final count = await container.read(soundUsageCountProvider('').future);

        expect(count, equals(0));
        verifyNever(() => mockRepository.fetchVideosUsingSoundCount(any()));
      });
    });

    group('soundsStreamProvider', () {
      test('provides stream from repository', () async {
        final streamController = StreamController<List<AudioEvent>>.broadcast();
        final testSounds = [createTestAudioEvent(id: 'stream-sound-1')];

        when(
          () => mockRepository.soundsStream,
        ).thenAnswer((_) => streamController.stream);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(() {
          container.dispose();
          streamController.close();
        });

        // Start listening to provider
        final subscription = container.listen(soundsStreamProvider, (_, __) {});

        // Emit data through stream
        streamController.add(testSounds);

        // Allow stream to propagate
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(soundsStreamProvider);
        expect(state.hasValue, isTrue);
        expect(state.value?.length, equals(1));
        expect(state.value?.first.id, equals('stream-sound-1'));

        subscription.close();
      });
    });
  });
}

// ABOUTME: Tests for external sound-library composition on SoundsRepository.
// ABOUTME: Verifies provider listing and search delegation through API client.

import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSoundLibraryApiClient extends Mock
    implements SoundLibraryApiClient {}

void main() {
  group('SoundsRepository external sound library', () {
    late _MockNostrClient mockNostrClient;
    late _MockSoundLibraryApiClient mockApiClient;

    setUpAll(() {
      registerFallbackValue(
        const SoundLibrarySearchRequest(query: 'fallback'),
      );
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockApiClient = _MockSoundLibraryApiClient();
    });

    test('fetchExternalProviders delegates to the API client', () async {
      const providers = [
        SoundLibraryProviderInfo(
          id: 'divine',
          label: 'Divine',
          enabled: true,
        ),
        SoundLibraryProviderInfo(
          id: 'nostr',
          label: 'Community',
          enabled: true,
        ),
      ];
      when(mockApiClient.fetchProviders).thenAnswer((_) async => providers);

      final repository = SoundsRepository(
        nostrClient: mockNostrClient,
        soundLibraryApiClient: mockApiClient,
      );

      final result = await repository.fetchExternalProviders();

      expect(result, equals(providers));
      verify(mockApiClient.fetchProviders).called(1);
    });

    test(
      'searchExternalLibrary routes the request through to the API client',
      () async {
        const externalSound = AudioEvent(
          id: 'freesound_1',
          pubkey: AudioEvent.externalProviderMarker,
          createdAt: 0,
          url: 'https://cdn.example.com/p.mp3',
          mimeType: 'audio/mpeg',
        );
        const response = SoundLibrarySearchResponse(
          sounds: [externalSound],
          count: 1,
          nextPage: 2,
        );
        when(
          () => mockApiClient.search(
            query: 'crowd',
            provider: 'freesound',
            licenseType: 'cc0',
          ),
        ).thenAnswer((_) async => response);

        final repository = SoundsRepository(
          nostrClient: mockNostrClient,
          soundLibraryApiClient: mockApiClient,
        );

        final result = await repository.searchExternalLibrary(
          const SoundLibrarySearchRequest(
            query: 'crowd',
            provider: 'freesound',
            licenseType: 'cc0',
          ),
        );

        expect(result, equals(response));
        verify(
          () => mockApiClient.search(
            query: 'crowd',
            provider: 'freesound',
            licenseType: 'cc0',
          ),
        ).called(1);
      },
    );

    test(
      'searchExternalLibrary forwards each provider name verbatim',
      () async {
        const response = SoundLibrarySearchResponse(
          sounds: [],
          count: 0,
        );
        for (final provider in [
          'divine',
          'nostr',
          'freesound',
          'openverse',
        ]) {
          when(
            () => mockApiClient.search(query: 'q', provider: provider),
          ).thenAnswer((_) async => response);
        }

        final repository = SoundsRepository(
          nostrClient: mockNostrClient,
          soundLibraryApiClient: mockApiClient,
        );

        for (final provider in [
          'divine',
          'nostr',
          'freesound',
          'openverse',
        ]) {
          await repository.searchExternalLibrary(
            SoundLibrarySearchRequest(query: 'q', provider: provider),
          );
          verify(
            () => mockApiClient.search(query: 'q', provider: provider),
          ).called(1);
        }
      },
    );

    test(
      'fetchExternalProviders throws StateError when client absent',
      () async {
        final repository = SoundsRepository(nostrClient: mockNostrClient);

        expect(
          repository.fetchExternalProviders,
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'searchExternalLibrary throws StateError when client absent',
      () async {
        final repository = SoundsRepository(nostrClient: mockNostrClient);

        expect(
          () => repository.searchExternalLibrary(
            const SoundLibrarySearchRequest(query: 'q'),
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}

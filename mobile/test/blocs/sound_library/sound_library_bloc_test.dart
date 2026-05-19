// ABOUTME: Tests for SoundLibraryBloc covering provider load, search, paging.
// ABOUTME: Asserts status-enum transitions and absence of error strings in state.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/sound_library/sound_library_bloc.dart';
import 'package:sounds_repository/sounds_repository.dart';

class _MockSoundsRepository extends Mock implements SoundsRepository {}

AudioEvent _externalSound(String id) => AudioEvent(
  id: id,
  pubkey: AudioEvent.externalProviderMarker,
  createdAt: 0,
  url: 'https://cdn.example.com/$id.mp3',
  mimeType: 'audio/mpeg',
);

void main() {
  group(SoundLibraryBloc, () {
    late _MockSoundsRepository repository;

    setUpAll(() {
      registerFallbackValue(
        const SoundLibrarySearchRequest(query: 'fallback'),
      );
    });

    setUp(() {
      repository = _MockSoundsRepository();
    });

    test('initial state is empty defaults', () {
      final bloc = SoundLibraryBloc(soundsRepository: repository);
      expect(
        bloc.state,
        equals(const SoundLibraryState()),
      );
      expect(bloc.state.providersStatus, SoundLibraryProvidersStatus.initial);
      expect(bloc.state.searchStatus, SoundLibrarySearchStatus.initial);
      expect(bloc.state.selectedProvider, equals('divine'));
    });

    group('SoundLibraryProvidersRequested', () {
      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'emits loading then loaded with providers on success',
        setUp: () {
          when(repository.fetchExternalProviders).thenAnswer(
            (_) async => const [
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
            ],
          );
        },
        build: () => SoundLibraryBloc(soundsRepository: repository),
        act: (bloc) => bloc.add(const SoundLibraryProvidersRequested()),
        expect: () => const [
          SoundLibraryState(
            providersStatus: SoundLibraryProvidersStatus.loading,
          ),
          SoundLibraryState(
            providersStatus: SoundLibraryProvidersStatus.loaded,
            providers: [
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
            ],
          ),
        ],
      );

      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'emits failure status (no error string) when repository throws',
        setUp: () {
          when(repository.fetchExternalProviders).thenThrow(
            const SoundLibraryApiException('offline'),
          );
        },
        build: () => SoundLibraryBloc(soundsRepository: repository),
        act: (bloc) => bloc.add(const SoundLibraryProvidersRequested()),
        errors: () => [isA<SoundLibraryApiException>()],
        expect: () => const [
          SoundLibraryState(
            providersStatus: SoundLibraryProvidersStatus.loading,
          ),
          SoundLibraryState(
            providersStatus: SoundLibraryProvidersStatus.failure,
          ),
        ],
      );
    });

    group('SoundLibraryQueryChanged', () {
      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'emits loading then loaded with results',
        setUp: () {
          when(() => repository.searchExternalLibrary(any())).thenAnswer(
            (_) async => SoundLibrarySearchResponse(
              sounds: [_externalSound('a'), _externalSound('b')],
              count: 2,
              nextPage: 2,
            ),
          );
        },
        build: () => SoundLibraryBloc(soundsRepository: repository),
        act: (bloc) => bloc.add(const SoundLibraryQueryChanged('crowd')),
        verify: (bloc) {
          expect(bloc.state.searchStatus, SoundLibrarySearchStatus.loaded);
          expect(bloc.state.query, equals('crowd'));
          expect(bloc.state.sounds, hasLength(2));
          expect(bloc.state.nextPage, equals(2));
          expect(bloc.state.hasMore, isTrue);
        },
      );

      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'empty / whitespace query resets to initial without calling repository',
        build: () => SoundLibraryBloc(soundsRepository: repository),
        seed: () => SoundLibraryState(
          searchStatus: SoundLibrarySearchStatus.loaded,
          query: 'old',
          sounds: [_externalSound('old')],
        ),
        act: (bloc) => bloc.add(const SoundLibraryQueryChanged('   ')),
        expect: () => const [SoundLibraryState()],
        verify: (_) => verifyNever(
          () => repository.searchExternalLibrary(any()),
        ),
      );

      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'emits failure status (no error string) when repository throws',
        setUp: () {
          when(() => repository.searchExternalLibrary(any())).thenThrow(
            const SoundLibraryApiException('boom'),
          );
        },
        build: () => SoundLibraryBloc(soundsRepository: repository),
        act: (bloc) => bloc.add(const SoundLibraryQueryChanged('crowd')),
        errors: () => [isA<SoundLibraryApiException>()],
        verify: (bloc) {
          expect(bloc.state.searchStatus, SoundLibrarySearchStatus.failure);
          // No error string field on state — using addError + status enum.
        },
      );
    });

    group('SoundLibraryProviderSelected', () {
      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'switching provider resets sounds and search status',
        build: () => SoundLibraryBloc(soundsRepository: repository),
        seed: () => SoundLibraryState(
          searchStatus: SoundLibrarySearchStatus.loaded,
          query: 'crowd',
          sounds: [_externalSound('a')],
          nextPage: 2,
        ),
        act: (bloc) =>
            bloc.add(const SoundLibraryProviderSelected('freesound')),
        expect: () => const [
          SoundLibraryState(
            selectedProvider: 'freesound',
            query: 'crowd',
          ),
        ],
      );

      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'no-op when selecting the already-selected provider',
        build: () => SoundLibraryBloc(soundsRepository: repository),
        seed: () => SoundLibraryState(
          searchStatus: SoundLibrarySearchStatus.loaded,
          sounds: [_externalSound('a')],
        ),
        act: (bloc) => bloc.add(const SoundLibraryProviderSelected('divine')),
        expect: () => const [],
      );
    });

    group('SoundLibraryPageRequested', () {
      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'appends next page of results',
        setUp: () {
          when(() => repository.searchExternalLibrary(any())).thenAnswer(
            (_) async => SoundLibrarySearchResponse(
              sounds: [_externalSound('b')],
              count: 2,
            ),
          );
        },
        build: () => SoundLibraryBloc(soundsRepository: repository),
        seed: () => SoundLibraryState(
          searchStatus: SoundLibrarySearchStatus.loaded,
          query: 'crowd',
          sounds: [_externalSound('a')],
          nextPage: 2,
        ),
        act: (bloc) => bloc.add(const SoundLibraryPageRequested()),
        verify: (bloc) {
          expect(bloc.state.searchStatus, SoundLibrarySearchStatus.loaded);
          expect(bloc.state.sounds.map((s) => s.id), equals(['a', 'b']));
          expect(bloc.state.page, equals(2));
          expect(bloc.state.nextPage, isNull);
        },
      );

      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'no-op when nextPage is null',
        build: () => SoundLibraryBloc(soundsRepository: repository),
        seed: () => SoundLibraryState(
          searchStatus: SoundLibrarySearchStatus.loaded,
          query: 'crowd',
          sounds: [_externalSound('a')],
        ),
        act: (bloc) => bloc.add(const SoundLibraryPageRequested()),
        expect: () => const [],
      );
    });

    group('SoundLibrarySearchCleared', () {
      blocTest<SoundLibraryBloc, SoundLibraryState>(
        'clears query and results',
        build: () => SoundLibraryBloc(soundsRepository: repository),
        seed: () => SoundLibraryState(
          searchStatus: SoundLibrarySearchStatus.loaded,
          query: 'crowd',
          sounds: [_externalSound('a')],
          nextPage: 2,
        ),
        act: (bloc) => bloc.add(const SoundLibrarySearchCleared()),
        expect: () => const [
          SoundLibraryState(),
        ],
      );
    });
  });
}

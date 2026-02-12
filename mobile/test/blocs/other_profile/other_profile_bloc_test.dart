// ABOUTME: Unit tests for OtherProfileBloc
// ABOUTME: Tests cache+fresh pattern for viewing another user's profile

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('OtherProfileBloc', () {
    late _MockProfileRepository mockProfileRepository;

    // Test data constants - using full 64-character hex pubkey as required
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testDisplayName = 'Test User';
    const testAbout = 'Test bio';
    const testPicture = 'https://example.com/avatar.png';

    /// Helper to create a test UserProfile
    UserProfile createTestProfile({
      String pubkey = testPubkey,
      String? displayName = testDisplayName,
      String eventId =
          'event123456789012345678901234567890123456789012345678901234567890',
    }) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        about: testAbout,
        picture: testPicture,
        rawData: const {},
        createdAt: DateTime(2024),
        eventId: eventId,
      );
    }

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
    });

    OtherProfileBloc createBloc({String pubkey = testPubkey}) =>
        OtherProfileBloc(
          profileRepository: mockProfileRepository,
          pubkey: pubkey,
        );

    test('initial state is OtherProfileInitial', () {
      final bloc = createBloc();
      expect(bloc.state, isA<OtherProfileInitial>());
      expect(bloc.pubkey, equals(testPubkey));
      bloc.close();
    });

    group('OtherProfileLoadRequested', () {
      group('with cached profile available', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with cache, loaded fresh] when fresh fetch succeeds',
          setUp: () {
            final cachedProfile = createTestProfile(
              eventId:
                  'cached12345678901234567890123456789012345678901234567890123456',
            );
            final freshProfile = createTestProfile(
              eventId:
                  'fresh123456789012345678901234567890123456789012345678901234567',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => cachedProfile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile?.eventId,
              'profile.eventId',
              'cached12345678901234567890123456789012345678901234567890123456',
            ),
            isA<OtherProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true),
          ],
          verify: (_) {
            verify(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).called(1);
            verify(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).called(1);
          },
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with cache, loaded stale] when fresh fetch returns null',
          setUp: () {
            final cachedProfile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => cachedProfile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with cache, loaded stale] when fresh fetch throws',
          setUp: () {
            final cachedProfile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => cachedProfile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );
      });

      group('without cached profile', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, loaded fresh] when fresh fetch succeeds',
          setUp: () {
            final freshProfile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, error notFound] when fresh fetch returns null',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileError>().having(
              (s) => s.errorType,
              'errorType',
              OtherProfileErrorType.notFound,
            ),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, error networkError] when fresh fetch throws',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileLoadRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileError>().having(
              (s) => s.errorType,
              'errorType',
              OtherProfileErrorType.networkError,
            ),
          ],
        );
      });
    });

    group('OtherProfileRefreshRequested', () {
      group('from initial state', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, loaded fresh] when refresh succeeds',
          setUp: () {
            final freshProfile = createTestProfile();
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, error notFound] when refresh returns null',
          setUp: () {
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileError>()
                .having(
                  (s) => s.errorType,
                  'errorType',
                  OtherProfileErrorType.notFound,
                )
                .having((s) => s.profile, 'profile', isNull),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading null, error networkError] when refresh throws',
          setUp: () {
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileError>()
                .having(
                  (s) => s.errorType,
                  'errorType',
                  OtherProfileErrorType.networkError,
                )
                .having((s) => s.profile, 'profile', isNull),
          ],
        );
      });

      group('from loaded state', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with current, loaded fresh] when refresh succeeds',
          setUp: () {
            final cachedProfile = createTestProfile(
              eventId:
                  'cached12345678901234567890123456789012345678901234567890123456',
            );
            final freshProfile = createTestProfile(
              eventId:
                  'fresh123456789012345678901234567890123456789012345678901234567',
            );
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => cachedProfile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          seed: () => OtherProfileLoaded(
            profile: createTestProfile(
              eventId:
                  'seed1234567890123456789012345678901234567890123456789012345678',
            ),
            isFresh: true,
          ),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile?.eventId,
              'profile.eventId',
              'seed1234567890123456789012345678901234567890123456789012345678',
            ),
            isA<OtherProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with current, error with current] when refresh '
          'returns null',
          setUp: () {
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          seed: () =>
              OtherProfileLoaded(profile: createTestProfile(), isFresh: true),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<OtherProfileError>()
                .having(
                  (s) => s.errorType,
                  'errorType',
                  OtherProfileErrorType.notFound,
                )
                .having((s) => s.profile, 'profile', isNotNull),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits [loading with current, loaded stale] when refresh throws',
          setUp: () {
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          seed: () =>
              OtherProfileLoaded(profile: createTestProfile(), isFresh: true),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );
      });

      group('from loading state', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'emits loaded fresh when refresh succeeds',
          setUp: () {
            final freshProfile = createTestProfile(
              eventId:
                  'fresh123456789012345678901234567890123456789012345678901234567',
            );
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          seed: () => OtherProfileLoading(
            profile: createTestProfile(
              eventId:
                  'loading12345678901234567890123456789012345678901234567890123456',
            ),
          ),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );
      });

      group('from error state', () {
        blocTest<OtherProfileBloc, OtherProfileState>(
          'preserves profile from error state during refresh',
          setUp: () {
            final freshProfile = createTestProfile(
              eventId:
                  'fresh123456789012345678901234567890123456789012345678901234567',
            );
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          seed: () => OtherProfileError(
            errorType: OtherProfileErrorType.networkError,
            profile: createTestProfile(
              eventId:
                  'error123456789012345678901234567890123456789012345678901234567',
            ),
          ),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile?.eventId,
              'profile.eventId',
              'error123456789012345678901234567890123456789012345678901234567',
            ),
            isA<OtherProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<OtherProfileBloc, OtherProfileState>(
          'recovers from error state without profile when refresh succeeds',
          setUp: () {
            final freshProfile = createTestProfile();
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => freshProfile);
          },
          build: createBloc,
          seed: () => const OtherProfileError(
            errorType: OtherProfileErrorType.networkError,
          ),
          act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
          expect: () => [
            isA<OtherProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNull,
            ),
            isA<OtherProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );
      });
    });

    group('OtherProfileState', () {
      test('OtherProfileInitial instances are equal', () {
        const state1 = OtherProfileInitial();
        const state2 = OtherProfileInitial();
        expect(state1, equals(state2));
      });

      test('OtherProfileLoading instances are equal with same profile', () {
        final profile = createTestProfile();
        final state1 = OtherProfileLoading(profile: profile);
        final state2 = OtherProfileLoading(profile: profile);
        expect(state1, equals(state2));
      });

      test('OtherProfileLoading instances differ with different profiles', () {
        final profile1 = createTestProfile(
          eventId:
              'event1234567890123456789012345678901234567890123456789012345678',
        );
        final profile2 = createTestProfile(
          eventId:
              'event2345678901234567890123456789012345678901234567890123456789',
        );
        final state1 = OtherProfileLoading(profile: profile1);
        final state2 = OtherProfileLoading(profile: profile2);
        expect(state1, isNot(equals(state2)));
      });

      test(
        'OtherProfileLoaded instances are equal with same profile and flag',
        () {
          final profile = createTestProfile();
          final state1 = OtherProfileLoaded(profile: profile, isFresh: true);
          final state2 = OtherProfileLoaded(profile: profile, isFresh: true);
          expect(state1, equals(state2));
        },
      );

      test('OtherProfileLoaded instances differ with different isFresh', () {
        final profile = createTestProfile();
        final state1 = OtherProfileLoaded(profile: profile, isFresh: true);
        final state2 = OtherProfileLoaded(profile: profile, isFresh: false);
        expect(state1, isNot(equals(state2)));
      });

      test('OtherProfileError instances are equal with same errorType', () {
        const state1 = OtherProfileError(
          errorType: OtherProfileErrorType.notFound,
        );
        const state2 = OtherProfileError(
          errorType: OtherProfileErrorType.notFound,
        );
        expect(state1, equals(state2));
      });

      test('OtherProfileError instances differ with different errorType', () {
        const state1 = OtherProfileError(
          errorType: OtherProfileErrorType.notFound,
        );
        const state2 = OtherProfileError(
          errorType: OtherProfileErrorType.networkError,
        );
        expect(state1, isNot(equals(state2)));
      });
    });

    group('OtherProfileEvent', () {
      test('OtherProfileLoadRequested instances are equal', () {
        const event1 = OtherProfileLoadRequested();
        const event2 = OtherProfileLoadRequested();
        expect(event1, equals(event2));
      });

      test('OtherProfileRefreshRequested instances are equal', () {
        const event1 = OtherProfileRefreshRequested();
        const event2 = OtherProfileRefreshRequested();
        expect(event1, equals(event2));
      });
    });
  });
}

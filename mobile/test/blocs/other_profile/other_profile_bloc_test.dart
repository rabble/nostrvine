// ABOUTME: Unit tests for OtherProfileBloc
// ABOUTME: Tests cache+fresh pattern for viewing another user's profile

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

/// Captures errors routed through [Bloc.onError] so a test can assert that a
/// bloc closed mid-flight records no error when its awaited work completes.
class _ErrorCapturingObserver extends BlocObserver {
  final List<Object> errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  group('OtherProfileBloc', () {
    late _MockProfileRepository mockProfileRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockFollowRepository mockFollowRepository;

    // Test data constants - using full 64-character hex pubkey as required
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testCurrentUserPubkey =
        'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b200';
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
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockFollowRepository = _MockFollowRepository();

      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
      when(
        () => mockFollowRepository.toggleFollow(any()),
      ).thenAnswer((_) async {});
    });

    OtherProfileBloc createBloc({String pubkey = testPubkey}) =>
        OtherProfileBloc(
          profileRepository: mockProfileRepository,
          pubkey: pubkey,
          contentBlocklistRepository: mockBlocklistRepository,
          currentUserPubkey: testCurrentUserPubkey,
          followRepository: mockFollowRepository,
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

    group('OtherProfileBlockRequested', () {
      setUp(() {
        when(
          () => mockBlocklistRepository.blockUser(
            any(),
            ourPubkey: any(named: 'ourPubkey'),
          ),
        ).thenAnswer((_) async {});
      });

      blocTest<OtherProfileBloc, OtherProfileState>(
        'calls blockUser with correct arguments',
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileBlockRequested()),
        verify: (_) {
          verify(
            () => mockBlocklistRepository.blockUser(
              testPubkey,
              ourPubkey: testCurrentUserPubkey,
            ),
          ).called(1);
        },
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'calls toggleFollow when currently following the user',
        setUp: () {
          when(
            () => mockFollowRepository.isFollowing(testPubkey),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileBlockRequested()),
        verify: (_) {
          verify(() => mockFollowRepository.toggleFollow(testPubkey)).called(1);
        },
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'does not call toggleFollow when not following the user',
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileBlockRequested()),
        verify: (_) {
          verifyNever(() => mockFollowRepository.toggleFollow(any()));
        },
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'still blocks user when toggleFollow throws',
        setUp: () {
          when(
            () => mockFollowRepository.isFollowing(testPubkey),
          ).thenReturn(true);
          when(
            () => mockFollowRepository.toggleFollow(testPubkey),
          ).thenThrow(Exception('network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileBlockRequested()),
        verify: (_) {
          verify(
            () => mockBlocklistRepository.blockUser(
              testPubkey,
              ourPubkey: testCurrentUserPubkey,
            ),
          ).called(1);
        },
      );
    });

    group('OtherProfileUnblockRequested', () {
      setUp(() {
        when(
          () => mockBlocklistRepository.unblockUser(any()),
        ).thenAnswer((_) async {});
      });

      blocTest<OtherProfileBloc, OtherProfileState>(
        'calls unblockUser with correct pubkey',
        build: createBloc,
        act: (bloc) => bloc.add(const OtherProfileUnblockRequested()),
        verify: (_) {
          verify(
            () => mockBlocklistRepository.unblockUser(testPubkey),
          ).called(1);
        },
      );
    });

    group('after close (lifecycle, regression for #4393)', () {
      // Installs an observer that records every error routed through
      // [Bloc.onError] for the running test, restoring the previous observer
      // on teardown. A closed bloc that resumes an awaited handler must not
      // surface any error.
      _ErrorCapturingObserver captureBlocErrors() {
        final observer = _ErrorCapturingObserver();
        final previousObserver = Bloc.observer;
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = previousObserver);
        return observer;
      }

      test(
        'records no error when closed before the fresh profile resolves '
        'on load',
        () async {
          final observer = captureBlocErrors();
          final freshCompleter = Completer<UserProfile?>();
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) => freshCompleter.future);

          final bloc = createBloc()..add(const OtherProfileLoadRequested());

          // Let the handler emit loading and park on fetchFreshProfile.
          await pumpEventQueue();
          // The profile screen is disposed while the fetch is in flight.
          await bloc.close();
          // The awaited fetch now resolves after close.
          freshCompleter.complete(createTestProfile());
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );

      test(
        'records no error when closed before the fresh fetch throws on load',
        () async {
          final observer = captureBlocErrors();
          final freshCompleter = Completer<UserProfile?>();
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) => freshCompleter.future);

          final bloc = createBloc()..add(const OtherProfileLoadRequested());

          await pumpEventQueue();
          await bloc.close();
          // The fetch fails after close: the catch block must not add
          // VerifiedClaimsRequested to the now-closed bloc.
          freshCompleter.completeError(Exception('network error'));
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );

      test(
        'records no error when closed before the fresh profile resolves '
        'on refresh',
        () async {
          final observer = captureBlocErrors();
          final freshCompleter = Completer<UserProfile?>();
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) => freshCompleter.future);

          final bloc = createBloc()..add(const OtherProfileRefreshRequested());

          await pumpEventQueue();
          await bloc.close();
          freshCompleter.complete(createTestProfile());
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );

      test(
        'records no error when closed before a seeded refresh fetch throws',
        () async {
          // Drive the bloc to a loaded state first so the refresh catch
          // block takes the branch that re-adds VerifiedClaimsRequested.
          when(
            () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
          final bloc = createBloc()..add(const OtherProfileLoadRequested());
          await pumpEventQueue();

          final observer = captureBlocErrors();
          final refreshCompleter = Completer<UserProfile?>();
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) => refreshCompleter.future);

          bloc.add(const OtherProfileRefreshRequested());
          await pumpEventQueue();
          await bloc.close();
          refreshCompleter.completeError(Exception('network error'));
          await pumpEventQueue();

          expect(observer.errors, isEmpty);
        },
      );
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

      test('OtherProfileBlockRequested instances are equal', () {
        const event1 = OtherProfileBlockRequested();
        const event2 = OtherProfileBlockRequested();
        expect(event1, equals(event2));
      });

      test('OtherProfileUnblockRequested instances are equal', () {
        const event1 = OtherProfileUnblockRequested();
        const event2 = OtherProfileUnblockRequested();
        expect(event1, equals(event2));
      });
    });

    group('VerifiedClaimsRequested (SWR cache, #3936)', () {
      late _MockIdentityClaimsRepository mockClaimsRepository;

      const identityTags = [
        ['i', 'github:alice', 'proof-a'],
      ];
      const aliceClaim = IdentityClaim(
        pubkey: testPubkey,
        platform: 'github',
        identity: 'alice',
        proof: 'proof-a',
      );
      const bobClaim = IdentityClaim(
        pubkey: testPubkey,
        platform: 'telegram',
        identity: 'bob',
        proof: 'proof-b',
      );

      setUp(() {
        mockClaimsRepository = _MockIdentityClaimsRepository();
        registerFallbackValue(<List<String>>[]);
        when(
          () => mockProfileRepository.cachedIdentityTags(testPubkey),
        ).thenAnswer((_) async => identityTags);
        when(
          () => mockProfileRepository.freshIdentityTags(
            pubkey: testPubkey,
            kind0Tags: any(named: 'kind0Tags'),
            kind0CreatedAt: any(named: 'kind0CreatedAt'),
          ),
        ).thenAnswer((_) async => identityTags);
      });

      OtherProfileBloc createClaimsBloc() => OtherProfileBloc(
        profileRepository: mockProfileRepository,
        pubkey: testPubkey,
        contentBlocklistRepository: mockBlocklistRepository,
        currentUserPubkey: testCurrentUserPubkey,
        followRepository: mockFollowRepository,
        identityClaimsRepository: mockClaimsRepository,
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'renders cached claims without a verifier call when the snapshot '
        'is fresh and covers every claim',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => const CachedVerifiedClaims(
              claims: [aliceClaim],
              isFresh: true,
            ),
          );
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
        ],
        verify: (_) {
          verifyNever(
            () => mockClaimsRepository.verifiedClaims(
              pubkey: any(named: 'pubkey'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'emits cached claims then re-verifies when the snapshot is stale',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => const CachedVerifiedClaims(
              claims: [aliceClaim],
              isFresh: false,
            ),
          );
          when(
            () => mockClaimsRepository.verifiedClaims(
              pubkey: testPubkey,
              tags: identityTags,
            ),
          ).thenAnswer((_) async => const [aliceClaim, bobClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        're-verifies when a fresh snapshot does not cover a new claim',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
        ),
        setUp: () {
          when(
            () => mockProfileRepository.freshIdentityTags(
              pubkey: testPubkey,
              kind0Tags: any(named: 'kind0Tags'),
              kind0CreatedAt: any(named: 'kind0CreatedAt'),
            ),
          ).thenAnswer(
            (_) async => const [
              ['i', 'github:alice', 'proof-a'],
              ['i', 'telegram:bob', 'proof-b'],
            ],
          );
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => const CachedVerifiedClaims(
              claims: [aliceClaim],
              isFresh: true,
            ),
          );
          when(
            () => mockClaimsRepository.verifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => const [aliceClaim, bobClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim, bobClaim],
          ),
        ],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'keeps last-known-good claims when the verifier fails',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
        ),
        setUp: () {
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => const CachedVerifiedClaims(
              claims: [aliceClaim],
              isFresh: false,
            ),
          );
          when(
            () => mockClaimsRepository.verifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenThrow(const VerifierApiException(503, 'down'));
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
        ],
        errors: () => [isA<VerifierApiException>()],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'degrades to the network path when the cache read throws',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
        ),
        setUp: () {
          when(
            () => mockProfileRepository.cachedIdentityTags(testPubkey),
          ).thenThrow(Exception('db corrupt'));
          when(
            () => mockClaimsRepository.verifiedClaims(
              pubkey: testPubkey,
              tags: identityTags,
            ),
          ).thenAnswer((_) async => const [aliceClaim]);
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const VerifiedClaimsRequested()),
        expect: () => [
          isA<OtherProfileLoaded>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<OtherProfileBloc, OtherProfileState>(
        'carries claims through refresh instead of dropping them',
        seed: () => OtherProfileLoaded(
          profile: createTestProfile(),
          isFresh: true,
          verifiedClaims: const [aliceClaim],
        ),
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: testPubkey,
              requireRawKind0: any(named: 'requireRawKind0'),
            ),
          ).thenAnswer((_) async => createTestProfile());
          when(
            () => mockClaimsRepository.cachedVerifiedClaims(
              pubkey: testPubkey,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => const CachedVerifiedClaims(
              claims: [aliceClaim],
              isFresh: true,
            ),
          );
        },
        build: createClaimsBloc,
        act: (bloc) => bloc.add(const OtherProfileRefreshRequested()),
        expect: () => [
          isA<OtherProfileLoading>().having(
            (s) => s.verifiedClaims,
            'verifiedClaims',
            [aliceClaim],
          ),
          isA<OtherProfileLoaded>()
              .having((s) => s.isFresh, 'isFresh', true)
              .having((s) => s.verifiedClaims, 'verifiedClaims', [aliceClaim]),
        ],
      );
    });
  });
}

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

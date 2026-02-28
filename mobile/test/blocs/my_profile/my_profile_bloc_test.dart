// ABOUTME: Unit tests for MyProfileBloc
// ABOUTME: Tests one-shot load, stream subscription, and NIP-05 extraction

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group(MyProfileBloc, () {
    late _MockProfileRepository mockProfileRepository;

    // Test data constants - using full 64-character hex pubkey as required
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    /// Helper to create a test UserProfile
    UserProfile createTestProfile({
      String pubkey = testPubkey,
      String? displayName = 'Test User',
      String? about = 'Test bio',
      String? picture = 'https://example.com/avatar.png',
      String? nip05,
      String eventId =
          'event123456789012345678901234567890123456789012345678901234567890',
    }) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        about: about,
        picture: picture,
        nip05: nip05,
        rawData: const {},
        createdAt: DateTime(2024),
        eventId: eventId,
      );
    }

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
    });

    MyProfileBloc createBloc({String pubkey = testPubkey}) =>
        MyProfileBloc(profileRepository: mockProfileRepository, pubkey: pubkey);

    test('initial state is $MyProfileInitial', () {
      final bloc = createBloc();
      expect(bloc.state, isA<MyProfileInitial>());
      expect(bloc.pubkey, equals(testPubkey));
      bloc.close();
    });

    group('$MyProfileState', () {
      test('$MyProfileInitial instances are equal', () {
        const state1 = MyProfileInitial();
        const state2 = MyProfileInitial();
        expect(state1, equals(state2));
      });

      test('$MyProfileLoading instances are equal with same profile', () {
        final profile = createTestProfile();
        final state1 = MyProfileLoading(profile: profile);
        final state2 = MyProfileLoading(profile: profile);
        expect(state1, equals(state2));
      });

      test('$MyProfileLoading instances differ with different profiles', () {
        final profile1 = createTestProfile(
          eventId:
              'event1234567890123456789012345678901234567890123456789012345678',
        );
        final profile2 = createTestProfile(
          eventId:
              'event2345678901234567890123456789012345678901234567890123456789',
        );
        final state1 = MyProfileLoading(profile: profile1);
        final state2 = MyProfileLoading(profile: profile2);
        expect(state1, isNot(equals(state2)));
      });

      test(
        '$MyProfileLoading instances differ with different extractedUsername',
        () {
          final profile = createTestProfile();
          final state1 = MyProfileLoading(
            profile: profile,
            extractedUsername: 'alice',
          );
          final state2 = MyProfileLoading(
            profile: profile,
            extractedUsername: 'bob',
          );
          expect(state1, isNot(equals(state2)));
        },
      );

      test(
        '$MyProfileLoaded instances are equal with same profile and flags',
        () {
          final profile = createTestProfile();
          final state1 = MyProfileLoaded(
            profile: profile,
            isFresh: true,
            extractedUsername: 'alice',
          );
          final state2 = MyProfileLoaded(
            profile: profile,
            isFresh: true,
            extractedUsername: 'alice',
          );
          expect(state1, equals(state2));
        },
      );

      test('$MyProfileLoaded instances differ with different isFresh', () {
        final profile = createTestProfile();
        final state1 = MyProfileLoaded(profile: profile, isFresh: true);
        final state2 = MyProfileLoaded(profile: profile, isFresh: false);
        expect(state1, isNot(equals(state2)));
      });

      test(
        '$MyProfileLoaded instances differ with different extractedUsername',
        () {
          final profile = createTestProfile();
          final state1 = MyProfileLoaded(
            profile: profile,
            isFresh: true,
            extractedUsername: 'alice',
          );
          final state2 = MyProfileLoaded(
            profile: profile,
            isFresh: true,
            extractedUsername: 'bob',
          );
          expect(state1, isNot(equals(state2)));
        },
      );

      test('$MyProfileError instances are equal with same errorType', () {
        const state1 = MyProfileError(errorType: MyProfileErrorType.notFound);
        const state2 = MyProfileError(errorType: MyProfileErrorType.notFound);
        expect(state1, equals(state2));
      });

      test('$MyProfileError instances differ with different errorType', () {
        const state1 = MyProfileError(errorType: MyProfileErrorType.notFound);
        const state2 = MyProfileError(
          errorType: MyProfileErrorType.networkError,
        );
        expect(state1, isNot(equals(state2)));
      });

      test(
        '$MyProfileUpdated instances are equal with same profile',
        () {
          final profile = createTestProfile();
          final state1 = MyProfileUpdated(
            profile: profile,
            extractedUsername: 'alice',
          );
          final state2 = MyProfileUpdated(
            profile: profile,
            extractedUsername: 'alice',
          );
          expect(state1, equals(state2));
        },
      );

      test(
        '$MyProfileUpdated instances differ with different profiles',
        () {
          final profile1 = createTestProfile(
            eventId:
                'event1234567890123456789012345678901234567890123456789012345678',
          );
          final profile2 = createTestProfile(
            eventId:
                'event2345678901234567890123456789012345678901234567890123456789',
          );
          final state1 = MyProfileUpdated(profile: profile1);
          final state2 = MyProfileUpdated(profile: profile2);
          expect(state1, isNot(equals(state2)));
        },
      );

      test(
        '$MyProfileUpdated instances differ with different extractedUsername',
        () {
          final profile = createTestProfile();
          final state1 = MyProfileUpdated(
            profile: profile,
            extractedUsername: 'alice',
          );
          final state2 = MyProfileUpdated(
            profile: profile,
            extractedUsername: 'bob',
          );
          expect(state1, isNot(equals(state2)));
        },
      );
    });

    group('$MyProfileEvent', () {
      test('$MyProfileLoadRequested instances are equal', () {
        const event1 = MyProfileLoadRequested();
        const event2 = MyProfileLoadRequested();
        expect(event1, equals(event2));
      });

      test('$MyProfileSubscriptionRequested instances are equal', () {
        const event1 = MyProfileSubscriptionRequested();
        const event2 = MyProfileSubscriptionRequested();
        expect(event1, equals(event2));
      });

      test('$MyProfileFetchRequested instances are equal', () {
        const event1 = MyProfileFetchRequested();
        const event2 = MyProfileFetchRequested();
        expect(event1, equals(event2));
      });
    });

    group('$MyProfileLoadRequested', () {
      group('with cached profile available', () {
        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading with cache, loaded fresh] '
          'when fresh fetch succeeds',
          setUp: () {
            final cachedProfile = createTestProfile(
              nip05: '_@alice.divine.video',
              eventId:
                  'cached12345678901234567890123456789012345678901234567890123456',
            );
            final freshProfile = createTestProfile(
              nip05: '_@alice.divine.video',
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
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>()
                .having(
                  (s) => s.profile?.eventId,
                  'profile.eventId',
                  'cached12345678901234567890123456789012345678901234567890123456',
                )
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  'alice',
                ),
            isA<MyProfileLoaded>()
                .having(
                  (s) => s.profile.eventId,
                  'profile.eventId',
                  'fresh123456789012345678901234567890123456789012345678901234567',
                )
                .having((s) => s.isFresh, 'isFresh', true)
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  'alice',
                ),
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

        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading with cache, loaded stale] '
          'when fresh fetch returns null',
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
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<MyProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading with cache, loaded stale] '
          'when fresh fetch throws',
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
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.profile,
              'profile',
              isNotNull,
            ),
            isA<MyProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', false),
          ],
        );
      });

      group('without cached profile', () {
        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading null, loaded fresh] '
          'when fresh fetch succeeds',
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
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
            isA<MyProfileLoaded>()
                .having((s) => s.profile.pubkey, 'profile.pubkey', testPubkey)
                .having((s) => s.isFresh, 'isFresh', true),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading null, error notFound] '
          'when fresh fetch returns null',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
            isA<MyProfileError>().having(
              (s) => s.errorType,
              'errorType',
              MyProfileErrorType.notFound,
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'emits [loading null, error networkError] '
          'when fresh fetch throws',
          setUp: () {
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => null);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenThrow(Exception('Network error'));
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having((s) => s.profile, 'profile', isNull),
            isA<MyProfileError>().having(
              (s) => s.errorType,
              'errorType',
              MyProfileErrorType.networkError,
            ),
          ],
        );
      });

      group('NIP-05 username extraction', () {
        blocTest<MyProfileBloc, MyProfileState>(
          'extracts username from new subdomain format '
          '_@username.divine.video',
          setUp: () {
            final profile = createTestProfile(nip05: '_@alice.divine.video');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'alice',
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'alice',
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'extracts username from legacy format '
          'username@divine.video',
          setUp: () {
            final profile = createTestProfile(nip05: 'bob@divine.video');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'bob',
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'bob',
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'extracts username from legacy format '
          'username@openvine.co',
          setUp: () {
            final profile = createTestProfile(nip05: 'charlie@openvine.co');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'charlie',
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              'charlie',
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null extractedUsername for non-divine NIP-05',
          setUp: () {
            final profile = createTestProfile(nip05: 'user@example.com');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null extractedUsername when NIP-05 is null',
          setUp: () {
            final profile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null extractedUsername when NIP-05 is empty',
          setUp: () {
            final profile = createTestProfile(nip05: '');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.extractedUsername,
              'extractedUsername',
              isNull,
            ),
          ],
        );
      });

      group('external NIP-05 extraction', () {
        blocTest<MyProfileBloc, MyProfileState>(
          'extracts external NIP-05 for non-divine domain',
          setUp: () {
            final profile = createTestProfile(nip05: 'alice@example.com');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>()
                .having(
                  (s) => s.externalNip05,
                  'externalNip05',
                  'alice@example.com',
                )
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  isNull,
                ),
            isA<MyProfileLoaded>()
                .having(
                  (s) => s.externalNip05,
                  'externalNip05',
                  'alice@example.com',
                )
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  isNull,
                ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null externalNip05 for divine.video domain',
          setUp: () {
            final profile = createTestProfile(nip05: '_@alice.divine.video');
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>()
                .having((s) => s.externalNip05, 'externalNip05', isNull)
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  'alice',
                ),
            isA<MyProfileLoaded>()
                .having((s) => s.externalNip05, 'externalNip05', isNull)
                .having(
                  (s) => s.extractedUsername,
                  'extractedUsername',
                  'alice',
                ),
          ],
        );

        blocTest<MyProfileBloc, MyProfileState>(
          'returns null externalNip05 when NIP-05 is null',
          setUp: () {
            final profile = createTestProfile();
            when(
              () => mockProfileRepository.getCachedProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
            when(
              () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
            ).thenAnswer((_) async => profile);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const MyProfileLoadRequested()),
          expect: () => [
            isA<MyProfileLoading>().having(
              (s) => s.externalNip05,
              'externalNip05',
              isNull,
            ),
            isA<MyProfileLoaded>().having(
              (s) => s.externalNip05,
              'externalNip05',
              isNull,
            ),
          ],
        );
      });
    });

    group('$MyProfileSubscriptionRequested', () {
      blocTest<MyProfileBloc, MyProfileState>(
        'emits [loading, updated] when stream emits a profile',
        setUp: () {
          final profile = createTestProfile();
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.value(profile));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          isA<MyProfileLoading>(),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.pubkey,
            'profile.pubkey',
            testPubkey,
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'emits only [loading] when stream emits null',
        setUp: () {
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.value(null));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          // Initial loading + stream null → same state, BLoC deduplicates
          isA<MyProfileLoading>(),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'emits [loading, updated, updated] '
        'when stream emits multiple profiles',
        setUp: () {
          final cached = createTestProfile(
            displayName: 'Old Name',
            eventId:
                'cached12345678901234567890123456789012345678901234567890123456',
          );
          final fresh = createTestProfile(
            displayName: 'New Name',
            eventId:
                'fresh123456789012345678901234567890123456789012345678901234567',
          );
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.fromIterable([cached, fresh]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          isA<MyProfileLoading>(),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'displayName',
            'Old Name',
          ),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'displayName',
            'New Name',
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.fetchFreshProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'extracts username from stream profile NIP-05',
        setUp: () {
          final profile = createTestProfile(nip05: '_@alice.divine.video');
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.value(profile));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          isA<MyProfileLoading>(),
          isA<MyProfileUpdated>().having(
            (s) => s.extractedUsername,
            'extractedUsername',
            'alice',
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'extracts external NIP-05 from stream profile',
        setUp: () {
          final profile = createTestProfile(nip05: 'alice@example.com');
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) => Stream.value(profile));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileSubscriptionRequested()),
        expect: () => [
          isA<MyProfileLoading>(),
          isA<MyProfileUpdated>()
              .having(
                (s) => s.externalNip05,
                'externalNip05',
                'alice@example.com',
              )
              .having(
                (s) => s.extractedUsername,
                'extractedUsername',
                isNull,
              ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(1);
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'cancels previous subscription when dispatched again',
        setUp: () {
          final profile1 = createTestProfile(
            displayName: 'First',
            eventId:
                'first12345678901234567890123456789012345678901234567890123456',
          );
          final profile2 = createTestProfile(
            displayName: 'Second',
            eventId:
                'second1234567890123456789012345678901234567890123456789012345',
          );
          var callCount = 0;
          when(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).thenAnswer((_) {
            callCount++;
            if (callCount == 1) return Stream.value(profile1);
            return Stream.value(profile2);
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyProfileSubscriptionRequested());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const MyProfileSubscriptionRequested());
        },
        expect: () => [
          isA<MyProfileLoading>(),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'displayName',
            'First',
          ),
          isA<MyProfileLoading>(),
          isA<MyProfileUpdated>().having(
            (s) => s.profile.displayName,
            'displayName',
            'Second',
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.watchProfile(pubkey: testPubkey),
          ).called(2);
        },
      );
    });

    group('$MyProfileFetchRequested', () {
      blocTest<MyProfileBloc, MyProfileState>(
        'calls fetchFreshProfile and emits nothing',
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => createTestProfile());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileFetchRequested()),
        expect: () => <MyProfileState>[],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.watchProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.getCachedProfile(
              pubkey: any(named: 'pubkey'),
            ),
          );
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'reports error without emitting state when fetch throws',
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileFetchRequested()),
        expect: () => <MyProfileState>[],
        errors: () => [isA<Exception>()],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).called(1);
        },
      );

      blocTest<MyProfileBloc, MyProfileState>(
        'does not emit error when fetch returns null',
        setUp: () {
          when(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyProfileFetchRequested()),
        expect: () => <MyProfileState>[],
        verify: (_) {
          verify(
            () => mockProfileRepository.fetchFreshProfile(pubkey: testPubkey),
          ).called(1);
        },
      );
    });
  });
}

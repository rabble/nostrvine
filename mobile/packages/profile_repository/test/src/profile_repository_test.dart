import 'dart:convert';

// Hide Drift table class to avoid collision with ProfileStats domain model.
import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockEvent extends Mock implements Event {}

class MockUserProfilesDao extends Mock implements UserProfilesDao {}

class MockHttpClient extends Mock implements Client {}

class MockProfileStatsDao extends Mock implements ProfileStatsDao {}

class MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  group('ProfileRepository', () {
    late MockNostrClient mockNostrClient;
    late ProfileRepository profileRepository;
    late MockEvent mockProfileEvent;
    late MockUserProfilesDao mockUserProfilesDao;
    late MockHttpClient mockHttpClient;

    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const otherPubkey =
        'b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2c3d4e5f6b1b2';
    const testEventId =
        'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';

    setUpAll(() {
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(
        UserProfile(
          pubkey: 'pubkey',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'eventId',
        ),
      );
      registerFallbackValue(Uri.parse('https://example.com'));
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockProfileEvent = MockEvent();
      mockUserProfilesDao = MockUserProfilesDao();
      mockHttpClient = MockHttpClient();
      profileRepository = ProfileRepository(
        nostrClient: mockNostrClient,
        userProfilesDao: mockUserProfilesDao,
        httpClient: mockHttpClient,
      );

      // Default mock event setup
      when(() => mockProfileEvent.kind).thenReturn(0);
      when(() => mockProfileEvent.pubkey).thenReturn(testPubkey);
      when(() => mockProfileEvent.createdAt).thenReturn(1704067200);
      when(() => mockProfileEvent.id).thenReturn(testEventId);
      when(() => mockProfileEvent.content).thenReturn(
        jsonEncode({
          'display_name': 'Test User',
          'about': 'A test bio',
          'picture': 'https://example.com/avatar.png',
          'nip05': 'test@example.com',
        }),
      );

      when(
        () => mockNostrClient.fetchProfile(testPubkey),
      ).thenAnswer((_) async => mockProfileEvent);

      when(
        () => mockNostrClient.sendProfile(
          profileContent: any(named: 'profileContent'),
        ),
      ).thenAnswer((_) async => mockProfileEvent);
      when(
        () => mockUserProfilesDao.getProfile(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockUserProfilesDao.upsertProfile(any()),
      ).thenAnswer((_) async {});
    });

    /// Helper to create a current profile with given content
    Future<UserProfile> createCurrentProfile(
      Map<String, dynamic> content,
    ) async {
      when(() => mockProfileEvent.content).thenReturn(jsonEncode(content));
      return (await profileRepository.fetchFreshProfile(pubkey: testPubkey))!;
    }

    group('getCachedProfile', () {
      test('returns cached profile when it exists', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        when(
          () => mockUserProfilesDao.getProfile(any()),
        ).thenAnswer((_) async => profile);

        final result = await profileRepository.getCachedProfile(
          pubkey: testPubkey,
        );

        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.displayName, equals('Test User'));

        verify(() => mockUserProfilesDao.getProfile(any())).called(1);
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });

      test('returns null when no cached profile exists', () async {
        final result = await profileRepository.getCachedProfile(
          pubkey: testPubkey,
        );

        expect(result, isNull);

        verify(() => mockUserProfilesDao.getProfile(any())).called(1);
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });
    });

    group('cacheProfile', () {
      test('delegates to userProfilesDao.upsertProfile', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);

        await profileRepository.cacheProfile(profile);

        verify(() => mockUserProfilesDao.upsertProfile(profile)).called(1);
      });

      test('adds pubkey to known cached set', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);

        await profileRepository.cacheProfile(profile);

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });

      test('clears pubkey from confirmed missing set', () async {
        // First make the pubkey confirmed missing
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
        await profileRepository.fetchFreshProfile(pubkey: testPubkey);
        expect(profileRepository.isConfirmedMissing(testPubkey), isTrue);

        // Now cache a profile for it
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        await profileRepository.cacheProfile(profile);

        expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
      });
    });

    group('hasProfile', () {
      test('returns false for unknown pubkey', () {
        expect(profileRepository.hasProfile(testPubkey), isFalse);
      });

      test('returns true after caching a profile', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        await profileRepository.cacheProfile(profile);

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });

      test('returns true after fetching from relay', () async {
        await profileRepository.fetchFreshProfile(pubkey: testPubkey);

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });
    });

    group('loadKnownCachedPubkeys', () {
      test('populates known cached set from Drift', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [profile]);

        await profileRepository.loadKnownCachedPubkeys();

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });
    });

    group('deleteCachedProfile', () {
      test('delegates to userProfilesDao.deleteProfile', () async {
        when(
          () => mockUserProfilesDao.deleteProfile(any()),
        ).thenAnswer((_) async => 1);

        final result = await profileRepository.deleteCachedProfile(
          pubkey: testPubkey,
        );

        expect(result, equals(1));
        verify(() => mockUserProfilesDao.deleteProfile(testPubkey)).called(1);
      });

      test('returns 0 when profile does not exist', () async {
        when(
          () => mockUserProfilesDao.deleteProfile(any()),
        ).thenAnswer((_) async => 0);

        final result = await profileRepository.deleteCachedProfile(
          pubkey: testPubkey,
        );

        expect(result, equals(0));
      });
    });

    group('getAllCachedProfiles', () {
      test('returns all profiles from dao', () async {
        final profiles = [UserProfile.fromNostrEvent(mockProfileEvent)];
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => profiles);

        final result = await profileRepository.getAllCachedProfiles();

        expect(result, equals(profiles));
        verify(() => mockUserProfilesDao.getAllProfiles()).called(1);
      });

      test('returns empty list when no profiles cached', () async {
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => []);

        final result = await profileRepository.getAllCachedProfiles();

        expect(result, isEmpty);
      });
    });

    group('watchProfile', () {
      test('emits profile from DAO stream', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        when(
          () => mockUserProfilesDao.watchProfile(any()),
        ).thenAnswer((_) => Stream.value(profile));

        final stream = profileRepository.watchProfile(pubkey: testPubkey);

        await expectLater(stream, emits(equals(profile)));
        verify(() => mockUserProfilesDao.watchProfile(testPubkey)).called(1);
      });

      test('emits null when no cached profile exists', () async {
        when(
          () => mockUserProfilesDao.watchProfile(any()),
        ).thenAnswer((_) => Stream.value(null));

        final stream = profileRepository.watchProfile(pubkey: testPubkey);

        await expectLater(stream, emits(isNull));
      });

      test('emits updates when profile changes', () async {
        final profile1 = UserProfile.fromNostrEvent(mockProfileEvent);
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({'display_name': 'Updated User', 'about': 'Updated bio'}),
        );
        final profile2 = UserProfile.fromNostrEvent(mockProfileEvent);

        when(
          () => mockUserProfilesDao.watchProfile(any()),
        ).thenAnswer((_) => Stream.fromIterable([profile1, profile2]));

        final stream = profileRepository.watchProfile(pubkey: testPubkey);

        await expectLater(
          stream,
          emitsInOrder([
            isA<UserProfile>().having(
              (p) => p.displayName,
              'displayName',
              equals('Test User'),
            ),
            isA<UserProfile>().having(
              (p) => p.displayName,
              'displayName',
              equals('Updated User'),
            ),
          ]),
        );
      });
    });

    group('watchProfileStats', () {
      late MockProfileStatsDao mockProfileStatsDao;
      late ProfileRepository profileRepository;

      setUp(() {
        mockProfileStatsDao = MockProfileStatsDao();
        profileRepository = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          profileStatsDao: mockProfileStatsDao,
        );
      });

      test('maps ProfileStatRow to ProfileStats domain model', () async {
        final row = ProfileStatRow(
          pubkey: testPubkey,
          videoCount: 5,
          followerCount: 100,
          followingCount: 50,
          totalViews: 1000,
          totalLikes: 200,
          cachedAt: DateTime(2026),
        );
        when(
          () => mockProfileStatsDao.watchStats(any()),
        ).thenAnswer((_) => Stream.value(row));

        final stream = profileRepository.watchProfileStats(pubkey: testPubkey);

        await expectLater(
          stream,
          emits(
            equals(
              ProfileStats(
                pubkey: testPubkey,
                videoCount: 5,
                totalLikes: 200,
                followers: 100,
                following: 50,
                totalViews: 1000,
                lastUpdated: DateTime(2026),
              ),
            ),
          ),
        );
      });

      test('emits null when no stats exist', () async {
        when(
          () => mockProfileStatsDao.watchStats(any()),
        ).thenAnswer((_) => Stream.value(null));

        final stream = profileRepository.watchProfileStats(pubkey: testPubkey);

        await expectLater(stream, emits(isNull));
      });

      test('defaults nullable int fields to zero', () async {
        final row = ProfileStatRow(
          pubkey: testPubkey,
          cachedAt: DateTime(2026),
        );
        when(
          () => mockProfileStatsDao.watchStats(any()),
        ).thenAnswer((_) => Stream.value(row));

        final stream = profileRepository.watchProfileStats(pubkey: testPubkey);

        await expectLater(
          stream,
          emits(
            isA<ProfileStats>()
                .having((s) => s.videoCount, 'videoCount', equals(0))
                .having((s) => s.totalLikes, 'totalLikes', equals(0))
                .having((s) => s.followers, 'followers', equals(0))
                .having((s) => s.following, 'following', equals(0))
                .having((s) => s.totalViews, 'totalViews', equals(0)),
          ),
        );
      });

      test('returns empty stream when ProfileStatsDao not injected', () async {
        final repoWithoutStats = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
        );

        final stream = repoWithoutStats.watchProfileStats(pubkey: testPubkey);

        await expectLater(stream, emitsDone);
      });
    });

    group('fetchFreshProfile', () {
      /// Stubs both relay and indexer to return nothing, so tests that
      /// only care about one layer can focus on that.
      void stubAllSourcesMiss() {
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
      }

      test('fetches from relay and caches profile', () async {
        final result = await profileRepository.fetchFreshProfile(
          pubkey: testPubkey,
        );

        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.displayName, equals('Test User'));
        expect(result.about, equals('A test bio'));

        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        verify(() => mockUserProfilesDao.upsertProfile(result)).called(1);
      });

      test('returns null when all sources return no profile', () async {
        stubAllSourcesMiss();

        final result = await profileRepository.fetchFreshProfile(
          pubkey: testPubkey,
        );

        expect(result, isNull);

        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
      });

      test('marks pubkey as confirmed missing when all sources miss', () async {
        stubAllSourcesMiss();

        await profileRepository.fetchFreshProfile(pubkey: testPubkey);

        expect(profileRepository.isConfirmedMissing(testPubkey), isTrue);
      });

      test(
        'skips all fetches for confirmed missing pubkeys',
        () async {
          stubAllSourcesMiss();

          // First call — hits all sources, marks missing
          await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          // Second call — should not hit any source
          await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          verify(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).called(1);
        },
      );

      test(
        'deduplicates concurrent calls for the same pubkey',
        () async {
          final results = await Future.wait([
            profileRepository.fetchFreshProfile(pubkey: testPubkey),
            profileRepository.fetchFreshProfile(pubkey: testPubkey),
            profileRepository.fetchFreshProfile(pubkey: testPubkey),
          ]);

          // All return the same profile
          for (final r in results) {
            expect(r?.pubkey, equals(testPubkey));
          }
          // Only one relay call
          verify(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).called(1);
        },
      );

      group('with Funnelcake API', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;
        late ProfileRepository repoWithFunnelcake;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );
        });

        test('uses Funnelcake REST API first when available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => {
              'pubkey': testPubkey,
              'display_name': 'REST User',
              'name': 'restuser',
              'picture': 'https://example.com/pic.png',
            },
          );

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('REST User'));
          verify(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).called(1);
          // Should NOT fall through to relay
          verifyNever(() => mockNostrClient.fetchProfile(testPubkey));
          verify(() => mockUserProfilesDao.upsertProfile(any())).called(1);
        });

        test('falls back to relay when Funnelcake throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenThrow(Exception('API down'));

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Test User'));
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        });

        test(
          'falls back to relay when Funnelcake returns null (404)',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer((_) async => null);

            final result = await repoWithFunnelcake.fetchFreshProfile(
              pubkey: testPubkey,
            );

            expect(result, isNotNull);
            expect(result!.displayName, equals('Test User'));
            verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
          },
        );

        test(
          'marks missing immediately when Funnelcake returns '
          '_noProfile sentinel',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => {'_noProfile': true, 'pubkey': testPubkey},
            );

            final result = await repoWithFunnelcake.fetchFreshProfile(
              pubkey: testPubkey,
            );

            expect(result, isNull);
            expect(
              repoWithFunnelcake.isConfirmedMissing(testPubkey),
              isTrue,
            );
            // Should NOT fall through to relay or indexer
            verifyNever(() => mockNostrClient.fetchProfile(any()));
            verifyNever(
              () => mockNostrClient.queryEvents(
                any(),
                tempRelays: any(named: 'tempRelays'),
                useCache: any(named: 'useCache'),
              ),
            );
          },
        );

        test('skips Funnelcake when not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Test User'));
          verifyNever(
            () => mockFunnelcakeClient.getUserProfile(any()),
          );
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        });
      });

      group('indexer relay fallback', () {
        late MockEvent mockIndexerEvent;

        setUp(() {
          mockIndexerEvent = MockEvent();
          when(() => mockIndexerEvent.kind).thenReturn(0);
          when(() => mockIndexerEvent.pubkey).thenReturn(testPubkey);
          when(() => mockIndexerEvent.createdAt).thenReturn(1704067200);
          when(() => mockIndexerEvent.id).thenReturn(
            'idx_$testEventId',
          );
          when(() => mockIndexerEvent.content).thenReturn(
            jsonEncode({
              'display_name': 'Indexer User',
              'picture': 'https://example.com/indexer.png',
            }),
          );
        });

        test('falls back to indexer relays when relay misses', () async {
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [mockIndexerEvent]);

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Indexer User'));
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: false,
            ),
          ).called(1);
          verify(() => mockUserProfilesDao.upsertProfile(any())).called(1);
        });

        test('marks missing when indexer also returns nothing', () async {
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
          expect(profileRepository.isConfirmedMissing(testPubkey), isTrue);
        });

        test('handles indexer relay timeout gracefully', () async {
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenThrow(Exception('Indexer timeout'));

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
          expect(profileRepository.isConfirmedMissing(testPubkey), isTrue);
        });
      });
    });

    group('saveProfileEvent', () {
      test('sends all provided fields to nostrClient and caches and returns '
          'user profile', () async {
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({
            'display_name': 'New Name',
            'about': 'New bio',
            'nip05': '_@newuser.divine.video',
            'picture': 'https://example.com/new.png',
          }),
        );

        final profile = await profileRepository.saveProfileEvent(
          displayName: 'New Name',
          about: 'New bio',
          username: 'newuser',
          picture: 'https://example.com/new.png',
        );

        expect(profile.displayName, equals('New Name'));
        expect(profile.about, equals('New bio'));
        expect(profile.nip05, equals('_@newuser.divine.video'));
        expect(profile.picture, equals('https://example.com/new.png'));

        verify(
          () => mockNostrClient.sendProfile(
            profileContent: {
              'display_name': 'New Name',
              'about': 'New bio',
              'nip05': '_@newuser.divine.video',
              'picture': 'https://example.com/new.png',
            },
          ),
        ).called(1);
        verify(() => mockUserProfilesDao.upsertProfile(profile)).called(1);
      });

      test('constructs nip05 identifier from username', () async {
        await profileRepository.saveProfileEvent(
          displayName: 'Test',
          username: 'alice',
        );

        verify(
          () => mockNostrClient.sendProfile(
            profileContent: {
              'display_name': 'Test',
              'nip05': '_@alice.divine.video',
            },
          ),
        ).called(1);
      });

      test('normalizes username to lowercase in nip05', () async {
        await profileRepository.saveProfileEvent(
          displayName: 'Test',
          username: 'Alice',
        );

        verify(
          () => mockNostrClient.sendProfile(
            profileContent: {
              'display_name': 'Test',
              'nip05': '_@alice.divine.video',
            },
          ),
        ).called(1);
      });

      test('uses external nip05 directly when provided', () async {
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({'display_name': 'Test', 'nip05': 'alice@example.com'}),
        );

        await profileRepository.saveProfileEvent(
          displayName: 'Test',
          nip05: 'alice@example.com',
        );

        verify(
          () => mockNostrClient.sendProfile(
            profileContent: {
              'display_name': 'Test',
              'nip05': 'alice@example.com',
            },
          ),
        ).called(1);
      });

      test('external nip05 takes precedence over username', () async {
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({'display_name': 'Test', 'nip05': 'alice@example.com'}),
        );

        await profileRepository.saveProfileEvent(
          displayName: 'Test',
          username: 'alice',
          nip05: 'alice@example.com',
        );

        verify(
          () => mockNostrClient.sendProfile(
            profileContent: {
              'display_name': 'Test',
              'nip05': 'alice@example.com',
            },
          ),
        ).called(1);
      });

      test('omits null optional fields', () async {
        await profileRepository.saveProfileEvent(displayName: 'Only Name');

        verify(
          () => mockNostrClient.sendProfile(
            profileContent: {'display_name': 'Only Name'},
          ),
        ).called(1);
      });

      test('includes banner when provided', () async {
        when(() => mockProfileEvent.content).thenReturn(
          jsonEncode({'display_name': 'Test User', 'banner': '0x33ccbf'}),
        );

        await profileRepository.saveProfileEvent(
          displayName: 'Test User',
          banner: '0x33ccbf',
        );

        verify(
          () => mockNostrClient.sendProfile(
            profileContent: {'display_name': 'Test User', 'banner': '0x33ccbf'},
          ),
        ).called(1);
      });

      test(
        'throws ProfilePublishFailedException when sendProfile fails',
        () async {
          when(
            () => mockNostrClient.sendProfile(
              profileContent: any(named: 'profileContent'),
            ),
          ).thenAnswer((_) async => null);

          await expectLater(
            profileRepository.saveProfileEvent(displayName: 'Test'),
            throwsA(isA<ProfilePublishFailedException>()),
          );
          verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
        },
      );

      group('with currentProfile', () {
        test('preserves unrelated fields from currentProfile', () async {
          final currentProfile = await createCurrentProfile({
            'display_name': 'Old Name',
            'website': 'https://old.com',
            'lud16': 'user@wallet.com',
            'custom_field': 'preserved',
          });

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            currentProfile: currentProfile,
          );

          verify(
            () => mockNostrClient.sendProfile(
              profileContent: {
                'display_name': 'New Name',
                'website': 'https://old.com',
                'lud16': 'user@wallet.com',
                'custom_field': 'preserved',
              },
            ),
          ).called(1);
        });

        test('new fields override existing fields', () async {
          final currentProfile = await createCurrentProfile({
            'display_name': 'Old Name',
            'nip05': 'old@example.com',
            'about': 'Old bio',
          });

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            username: 'newuser',
            about: 'New bio',
            currentProfile: currentProfile,
          );

          verify(
            () => mockNostrClient.sendProfile(
              profileContent: {
                'display_name': 'New Name',
                'nip05': '_@newuser.divine.video',
                'about': 'New bio',
              },
            ),
          ).called(1);
        });

        test(
          'preserves rawData fields when optional params are null',
          () async {
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'about': 'Preserved bio',
            });

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              currentProfile: currentProfile,
            );

            verify(
              () => mockNostrClient.sendProfile(
                profileContent: {
                  'display_name': 'New Name',
                  'about': 'Preserved bio',
                },
              ),
            ).called(1);
          },
        );

        test(
          'preserves existing nip05 from rawData when clearNip05 is false',
          () async {
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'nip05': 'alice@example.com',
            });

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              currentProfile: currentProfile,
            );

            verify(
              () => mockNostrClient.sendProfile(
                profileContent: {
                  'display_name': 'New Name',
                  'nip05': 'alice@example.com',
                },
              ),
            ).called(1);
          },
        );

        test('removes nip05 from rawData when clearNip05 is true', () async {
          final currentProfile = await createCurrentProfile({
            'display_name': 'Old Name',
            'nip05': 'alice@example.com',
            'about': 'Bio',
          });

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            clearNip05: true,
            currentProfile: currentProfile,
          );

          verify(
            () => mockNostrClient.sendProfile(
              profileContent: {'display_name': 'New Name', 'about': 'Bio'},
            ),
          ).called(1);
        });

        test(
          'clearNip05 is a no-op when a new nip05 is also provided',
          () async {
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'nip05': 'old@example.com',
            });

            when(() => mockProfileEvent.content).thenReturn(
              jsonEncode({
                'display_name': 'New Name',
                'nip05': 'new@example.com',
              }),
            );

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              nip05: 'new@example.com',
              clearNip05: true,
              currentProfile: currentProfile,
            );

            verify(
              () => mockNostrClient.sendProfile(
                profileContent: {
                  'display_name': 'New Name',
                  'nip05': 'new@example.com',
                },
              ),
            ).called(1);
          },
        );
      });
    });

    group('searchUsers', () {
      test('returns empty list for empty query', () async {
        // Act
        final result = await profileRepository.searchUsers(query: '');

        // Assert
        expect(result, isEmpty);
        verifyNever(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        );
      });

      test('returns empty list for whitespace-only query', () async {
        // Act
        final result = await profileRepository.searchUsers(query: '   ');

        // Assert
        expect(result, isEmpty);
        verifyNever(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        );
      });

      test('returns profiles from NostrClient', () async {
        // Arrange
        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent]);

        // Act
        final result = await profileRepository.searchUsers(query: 'test');

        // Assert
        expect(result, hasLength(1));
        expect(result.first.pubkey, equals(testPubkey));
        expect(result.first.displayName, equals('Test User'));
        verify(() => mockNostrClient.queryUsers('test', limit: 200)).called(1);
      });

      test('uses custom limit when provided', () async {
        // Arrange
        when(
          () => mockNostrClient.queryUsers('test', limit: 10),
        ).thenAnswer((_) async => [mockProfileEvent]);

        // Act
        final result = await profileRepository.searchUsers(
          query: 'test',
          limit: 10,
        );

        // Assert
        expect(result, hasLength(1));
        verify(() => mockNostrClient.queryUsers('test', limit: 10)).called(1);
      });

      test('returns empty list when NostrClient returns empty list', () async {
        // Arrange
        when(
          () => mockNostrClient.queryUsers('unknown', limit: 200),
        ).thenAnswer((_) async => []);

        // Act
        final result = await profileRepository.searchUsers(query: 'unknown');

        // Assert
        expect(result, isEmpty);
      });

      test(
        'returns multiple profiles when NostrClient returns multiple events',
        () async {
          // Arrange
          final mockProfileEvent1 = MockEvent();
          final mockProfileEvent2 = MockEvent();
          const testPubkey1 =
              'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
              'c3d4e5f6a1b2c3d4e5f6a1b2';
          const testPubkey2 =
              'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
              'c3d4e5f6a1b2c3d4e5f6a1b2c3';
          const testEventId1 =
              'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
              'd3c4b5a6f1e2d3c4b5a6f1e2';
          const testEventId2 =
              'e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
              'd3c4b5a6f1e2d3c4b5a6f1e2d3';

          when(() => mockProfileEvent1.kind).thenReturn(0);
          when(() => mockProfileEvent1.pubkey).thenReturn(testPubkey1);
          when(() => mockProfileEvent1.createdAt).thenReturn(1704067200);
          when(() => mockProfileEvent1.id).thenReturn(testEventId1);
          when(() => mockProfileEvent1.content).thenReturn(
            jsonEncode({
              'display_name': 'Alice Wonder',
              'about': 'A test user',
            }),
          );

          when(() => mockProfileEvent2.kind).thenReturn(0);
          when(() => mockProfileEvent2.pubkey).thenReturn(testPubkey2);
          when(() => mockProfileEvent2.createdAt).thenReturn(1704067300);
          when(() => mockProfileEvent2.id).thenReturn(testEventId2);
          when(() => mockProfileEvent2.content).thenReturn(
            jsonEncode({
              'display_name': 'Alice Smith',
              'about': 'Another user',
            }),
          );

          when(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).thenAnswer((_) async => [mockProfileEvent1, mockProfileEvent2]);

          // Act
          final result = await profileRepository.searchUsers(query: 'alice');

          // Assert
          expect(result, hasLength(2));
          expect(result[0].displayName, equals('Alice Wonder'));
          expect(result[1].displayName, equals('Alice Smith'));
        },
      );

      test('enriches profiles missing picture from local cache', () async {
        // Arrange - search result has no picture
        final mockSearchEvent = MockEvent();
        const searchPubkey =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2';
        const searchEventId =
            'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2';

        when(() => mockSearchEvent.kind).thenReturn(0);
        when(() => mockSearchEvent.pubkey).thenReturn(searchPubkey);
        when(() => mockSearchEvent.createdAt).thenReturn(1704067200);
        when(() => mockSearchEvent.id).thenReturn(searchEventId);
        when(
          () => mockSearchEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Alice'}));

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => [mockSearchEvent]);

        // Cache has a profile with a picture
        when(() => mockUserProfilesDao.getProfile(searchPubkey)).thenAnswer(
          (_) async => UserProfile(
            pubkey: searchPubkey,
            displayName: 'Alice Cached',
            picture: 'https://example.com/alice.png',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: searchEventId,
          ),
        );

        // Act
        final result = await profileRepository.searchUsers(query: 'alice');

        // Assert - picture enriched from cache
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice'));
        expect(result.first.picture, equals('https://example.com/alice.png'));
      });

      test('does not overwrite existing picture with cached version', () async {
        // Arrange - search result already has a picture
        final mockSearchEvent = MockEvent();
        const searchPubkey =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2';
        const searchEventId =
            'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2';

        when(() => mockSearchEvent.kind).thenReturn(0);
        when(() => mockSearchEvent.pubkey).thenReturn(searchPubkey);
        when(() => mockSearchEvent.createdAt).thenReturn(1704067200);
        when(() => mockSearchEvent.id).thenReturn(searchEventId);
        when(() => mockSearchEvent.content).thenReturn(
          jsonEncode({
            'display_name': 'Alice',
            'picture': 'https://example.com/fresh.png',
          }),
        );

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => [mockSearchEvent]);

        // Cache has a different (stale) picture
        when(() => mockUserProfilesDao.getProfile(searchPubkey)).thenAnswer(
          (_) async => UserProfile(
            pubkey: searchPubkey,
            picture: 'https://example.com/stale.png',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: searchEventId,
          ),
        );

        // Act
        final result = await profileRepository.searchUsers(query: 'alice');

        // Assert - search result picture preserved, not overwritten
        expect(result, hasLength(1));
        expect(result.first.picture, equals('https://example.com/fresh.png'));
      });

      test('enriches multiple null fields from cache', () async {
        // Arrange - search result has minimal data
        final mockSearchEvent = MockEvent();
        const searchPubkey =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2';
        const searchEventId =
            'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2';

        when(() => mockSearchEvent.kind).thenReturn(0);
        when(() => mockSearchEvent.pubkey).thenReturn(searchPubkey);
        when(() => mockSearchEvent.createdAt).thenReturn(1704067200);
        when(() => mockSearchEvent.id).thenReturn(searchEventId);
        when(
          () => mockSearchEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Alice'}));

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => [mockSearchEvent]);

        // Cache has complete profile
        when(() => mockUserProfilesDao.getProfile(searchPubkey)).thenAnswer(
          (_) async => UserProfile(
            pubkey: searchPubkey,
            displayName: 'Alice Cached',
            about: 'Bio from cache',
            picture: 'https://example.com/alice.png',
            nip05: 'alice@example.com',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: searchEventId,
          ),
        );

        // Act
        final result = await profileRepository.searchUsers(query: 'alice');

        // Assert - null fields enriched, non-null preserved
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice'));
        expect(result.first.about, equals('Bio from cache'));
        expect(result.first.picture, equals('https://example.com/alice.png'));
        expect(result.first.nip05, equals('alice@example.com'));
      });

      test('uses profileSearchFilter when provided', () async {
        // Arrange
        final mockProfileEvent1 = MockEvent();
        final mockProfileEvent2 = MockEvent();
        const testPubkey1 =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2';
        const testPubkey2 =
            'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
            'c3d4e5f6a1b2c3d4e5f6a1b2c3';
        const testEventId1 =
            'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2';
        const testEventId2 =
            'e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
            'd3c4b5a6f1e2d3c4b5a6f1e2d3';

        when(() => mockProfileEvent1.kind).thenReturn(0);
        when(() => mockProfileEvent1.pubkey).thenReturn(testPubkey1);
        when(() => mockProfileEvent1.createdAt).thenReturn(1704067200);
        when(() => mockProfileEvent1.id).thenReturn(testEventId1);
        when(() => mockProfileEvent1.content).thenReturn(
          jsonEncode({'display_name': 'Bob Smith', 'about': 'First user'}),
        );

        when(() => mockProfileEvent2.kind).thenReturn(0);
        when(() => mockProfileEvent2.pubkey).thenReturn(testPubkey2);
        when(() => mockProfileEvent2.createdAt).thenReturn(1704067300);
        when(() => mockProfileEvent2.id).thenReturn(testEventId2);
        when(() => mockProfileEvent2.content).thenReturn(
          jsonEncode({'display_name': 'Alice Jones', 'about': 'Second user'}),
        );

        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent1, mockProfileEvent2]);

        // Track filter invocations
        var filterCalled = false;
        String? receivedQuery;
        List<UserProfile>? receivedProfiles;

        // Create repository with custom search filter that reverses the list
        final repoWithFilter = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          profileSearchFilter: (query, profiles) {
            filterCalled = true;
            receivedQuery = query;
            receivedProfiles = profiles;
            // Return reversed list to prove custom filter was used
            return profiles.reversed.toList();
          },
        );

        // Act
        final result = await repoWithFilter.searchUsers(query: 'test');

        // Assert
        expect(filterCalled, isTrue);
        expect(receivedQuery, equals('test'));
        expect(receivedProfiles, hasLength(2));
        // Verify the custom filter's reversal was applied
        expect(result, hasLength(2));
        expect(result[0].displayName, equals('Alice Jones'));
        expect(result[1].displayName, equals('Bob Smith'));
      });
    });

    group('searchUsersLocally', () {
      test('returns empty list when query is blank', () async {
        final result = await profileRepository.searchUsersLocally(query: '   ');

        expect(result, isEmpty);
        verifyNever(() => mockUserProfilesDao.getAllProfiles());
      });

      test('filters cached profiles and applies limit', () async {
        final cachedProfiles = [
          UserProfile(
            pubkey: testPubkey,
            displayName: 'Alice Example',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: testEventId,
          ),
          UserProfile(
            pubkey: otherPubkey,
            about: 'Talks about ALPHA builds',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'z' * 64,
          ),
          UserProfile(
            pubkey: 'c' * 64,
            displayName: 'Charlie',
            about: 'No match here',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'd' * 64,
          ),
        ];
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => cachedProfiles);

        final result = await profileRepository.searchUsersLocally(
          query: '  al  ',
          limit: 1,
        );

        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice Example'));
        verify(() => mockUserProfilesDao.getAllProfiles()).called(1);
      });

      test('uses custom profileSearchFilter when provided', () async {
        final cachedProfiles = [
          UserProfile(
            pubkey: testPubkey,
            displayName: 'Alice Example',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: testEventId,
          ),
          UserProfile(
            pubkey: otherPubkey,
            displayName: 'Bob Example',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'e' * 64,
          ),
        ];
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => cachedProfiles);

        var filterCalled = false;
        final repoWithFilter = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          profileSearchFilter: (query, profiles) {
            filterCalled = true;
            expect(query, equals('alice'));
            expect(profiles, same(cachedProfiles));
            return [profiles.last];
          },
        );

        final result = await repoWithFilter.searchUsersLocally(query: 'alice');

        expect(filterCalled, isTrue);
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Bob Example'));
      });

      test('countUsersLocally returns number of cached matches', () async {
        final cachedProfiles = [
          UserProfile(
            pubkey: testPubkey,
            displayName: 'Alice Example',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: testEventId,
          ),
          UserProfile(
            pubkey: otherPubkey,
            about: 'Alice in bio only',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'f' * 64,
          ),
        ];
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => cachedProfiles);

        final count = await profileRepository.countUsersLocally(query: 'alice');

        expect(count, equals(2));
      });
    });

    group('searchUsers with FunnelcakeApiClient', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test(
        'uses Funnelcake first then WebSocket when both available',
        () async {
          // Arrange
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'alice',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'a' * 64,
                displayName: 'Alice REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          final mockWsEvent = MockEvent();
          when(() => mockWsEvent.kind).thenReturn(0);
          when(() => mockWsEvent.pubkey).thenReturn('b' * 64);
          when(() => mockWsEvent.createdAt).thenReturn(1704067200);
          when(() => mockWsEvent.id).thenReturn('c' * 64);
          when(
            () => mockWsEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Alice WS'}));

          when(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).thenAnswer((_) async => [mockWsEvent]);

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act
          final result = await repoWithFunnelcake.searchUsers(query: 'alice');

          // Assert - both results merged
          expect(result, hasLength(2));
          expect(result.any((p) => p.displayName == 'Alice REST'), isTrue);
          expect(result.any((p) => p.displayName == 'Alice WS'), isTrue);

          verify(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'alice',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).called(1);
          verify(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).called(1);
        },
      );

      test('skips Funnelcake when not available', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        // Use 'test' as query so it matches 'Test User' display name
        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent]);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(query: 'test');

        // Assert
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Test User'));

        verifyNever(
          () => mockFunnelcakeClient.searchProfiles(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        );
        verify(() => mockNostrClient.queryUsers('test', limit: 200)).called(1);
      });

      test('continues to WebSocket when Funnelcake fails', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'test',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenThrow(Exception('REST API error'));

        // Use 'test' as query so it matches 'Test User' display name
        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent]);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(query: 'test');

        // Assert - falls back to WebSocket results
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Test User'));
      });

      test('deduplicates results by pubkey (REST takes priority)', () async {
        // Arrange
        final samePubkey = 'd' * 64;

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'alice',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenAnswer(
          (_) async => [
            ProfileSearchResult(
              pubkey: samePubkey,
              displayName: 'Alice REST',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            ),
          ],
        );

        final mockWsEvent = MockEvent();
        when(() => mockWsEvent.kind).thenReturn(0);
        when(() => mockWsEvent.pubkey).thenReturn(samePubkey);
        when(() => mockWsEvent.createdAt).thenReturn(1704067200);
        when(() => mockWsEvent.id).thenReturn('e' * 64);
        when(
          () => mockWsEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Alice WS'}));

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => [mockWsEvent]);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(query: 'alice');

        // Assert - only one result, REST version preserved
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice REST'));
      });

      test('skips WebSocket on paginated request (offset > 0)', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'alice',
            limit: any(named: 'limit'),
            offset: 50,
            sortBy: 'followers',
            hasVideos: true,
          ),
        ).thenAnswer(
          (_) async => [
            ProfileSearchResult(
              pubkey: 'a' * 64,
              displayName: 'Alice Page 2',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            ),
          ],
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(
          query: 'alice',
          offset: 50,
          sortBy: 'followers',
          hasVideos: true,
        );

        // Assert
        expect(result, hasLength(1));
        expect(result.first.displayName, equals('Alice Page 2'));

        // WebSocket should NOT have been called for offset > 0
        verifyNever(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        );
      });

      test('skips client-side filter when sortBy is set', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'alice',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: 'followers',
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenAnswer(
          (_) async => [
            ProfileSearchResult(
              pubkey: 'a' * 64,
              displayName: 'Alice REST',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            ),
          ],
        );

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenAnswer((_) async => []);

        var filterCalled = false;
        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          profileSearchFilter: (query, profiles) {
            filterCalled = true;
            return profiles;
          },
        );

        // Act
        await repoWithFunnelcake.searchUsers(
          query: 'alice',
          sortBy: 'followers',
        );

        // Assert - filter should NOT be called when sortBy is set
        expect(filterCalled, isFalse);
      });

      test(
        'preserves Phase 1 REST results when Phase 2 WebSocket throws',
        () async {
          // Arrange
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'alice',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'a' * 64,
                displayName: 'Alice REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          // Phase 2 WebSocket throws
          when(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).thenThrow(StateError('WebSocket connection failed'));

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act
          final result = await repoWithFunnelcake.searchUsers(query: 'alice');

          // Assert - Phase 1 results preserved despite Phase 2 failure
          expect(result, hasLength(1));
          expect(result.first.displayName, equals('Alice REST'));
        },
      );

      test('returns empty list when both phases fail', () async {
        // Arrange
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchProfiles(
            query: 'alice',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            sortBy: any(named: 'sortBy'),
            hasVideos: any(named: 'hasVideos'),
          ),
        ).thenThrow(Exception('REST API error'));

        when(
          () => mockNostrClient.queryUsers('alice', limit: 200),
        ).thenThrow(Exception('WebSocket error'));

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        // Act
        final result = await repoWithFunnelcake.searchUsers(query: 'alice');

        // Assert - empty list, no crash
        expect(result, isEmpty);
      });
    });

    group('searchUsersProgressive', () {
      test('returns empty stream for empty query', () async {
        final results = await profileRepository
            .searchUsersProgressive(query: '')
            .toList();

        expect(results, isEmpty);
      });

      test('returns empty stream for whitespace-only query', () async {
        final results = await profileRepository
            .searchUsersProgressive(query: '   ')
            .toList();

        expect(results, isEmpty);
      });

      test('yields local results first then remote results', () async {
        // Arrange - local cache has a profile
        final cachedProfile = UserProfile(
          pubkey: testPubkey,
          displayName: 'Test User',
          rawData: const {'display_name': 'Test User'},
          createdAt: DateTime(2026),
          eventId: testEventId,
        );
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [cachedProfile]);

        // Remote NIP-50 returns a different profile
        final mockRemoteEvent = MockEvent();
        when(() => mockRemoteEvent.kind).thenReturn(0);
        when(() => mockRemoteEvent.pubkey).thenReturn(otherPubkey);
        when(() => mockRemoteEvent.createdAt).thenReturn(1704067200);
        when(() => mockRemoteEvent.id).thenReturn('e' * 64);
        when(
          () => mockRemoteEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Test Remote'}));

        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockRemoteEvent]);

        // Act
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'test')
            .toList();

        // Assert - at least 2 emissions: local first, then merged
        expect(emissions.length, greaterThanOrEqualTo(2));

        // First emission: local results only
        expect(emissions.first, hasLength(1));
        expect(emissions.first.first.pubkey, equals(testPubkey));

        // Last emission: merged and enriched
        expect(emissions.last.length, greaterThanOrEqualTo(1));
      });

      test('skips local phase when offset > 0', () async {
        // Arrange
        when(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) async => [mockProfileEvent]);

        // Act
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'test', offset: 10)
            .toList();

        // Assert - only one emission (no local phase)
        expect(emissions, hasLength(1));

        // NIP-50 should NOT be called for offset > 0
        verifyNever(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        );
      });

      test('yields single result when local cache is empty', () async {
        // Arrange - empty local cache
        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => []);

        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent]);

        // Act
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'test')
            .toList();

        // Assert - no local emission (empty), just the final one
        expect(emissions, hasLength(1));
        expect(emissions.first, hasLength(1));
        expect(emissions.first.first.pubkey, equals(testPubkey));
      });

      group('with FunnelcakeApiClient', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('yields progressively: local, then API+relay merged', () async {
          // Arrange - local cache
          final cachedProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Test Cached',
            rawData: const {'display_name': 'Test Cached'},
            createdAt: DateTime(2026),
            eventId: testEventId,
          );
          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => [cachedProfile]);

          // Funnelcake REST
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: otherPubkey,
                displayName: 'Test REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          // NIP-50
          when(
            () => mockNostrClient.queryUsers('test', limit: 200),
          ).thenAnswer((_) async => []);

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act
          final emissions = await repoWithFunnelcake
              .searchUsersProgressive(query: 'test')
              .toList();

          // Assert
          expect(emissions.length, greaterThanOrEqualTo(2));

          // First emission: local only
          expect(emissions.first, hasLength(1));
          expect(emissions.first.first.displayName, equals('Test Cached'));

          // Last emission: merged results
          expect(emissions.last.length, greaterThanOrEqualTo(1));
        });

        test('continues when REST fails and yields WS results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenThrow(Exception('REST API error'));

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);

          when(
            () => mockNostrClient.queryUsers('test', limit: 200),
          ).thenAnswer((_) async => [mockProfileEvent]);

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake
              .searchUsersProgressive(query: 'test')
              .last;

          expect(result, hasLength(1));
          expect(result.first.pubkey, equals(testPubkey));
        });

        test('continues when WS fails and yields REST results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'a' * 64,
                displayName: 'Test REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);

          when(
            () => mockNostrClient.queryUsers('test', limit: 200),
          ).thenThrow(StateError('WebSocket error'));

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake
              .searchUsersProgressive(query: 'test')
              .last;

          expect(result, hasLength(1));
          expect(result.first.displayName, equals('Test REST'));
        });

        test('yields enriched results when WS adds new profiles', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'a' * 64,
                displayName: 'Test REST',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          final mockWsEvent = MockEvent();
          when(() => mockWsEvent.kind).thenReturn(0);
          when(() => mockWsEvent.pubkey).thenReturn('b' * 64);
          when(() => mockWsEvent.createdAt).thenReturn(1704067200);
          when(() => mockWsEvent.id).thenReturn('c' * 64);
          when(
            () => mockWsEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Test WS'}));

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);

          when(
            () => mockNostrClient.queryUsers('test', limit: 200),
          ).thenAnswer((_) async => [mockWsEvent]);

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake
              .searchUsersProgressive(query: 'test')
              .last;

          // Both REST and WS results merged
          expect(result, hasLength(2));
        });

        test('uses custom profileSearchFilter when no server sort', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);

          final mockWsEvent = MockEvent();
          when(() => mockWsEvent.kind).thenReturn(0);
          when(() => mockWsEvent.pubkey).thenReturn('a' * 64);
          when(() => mockWsEvent.createdAt).thenReturn(1704067200);
          when(() => mockWsEvent.id).thenReturn('b' * 64);
          when(
            () => mockWsEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Alice Test'}));

          when(
            () => mockNostrClient.queryUsers('test', limit: 200),
          ).thenAnswer((_) async => [mockWsEvent]);

          var filterCalled = false;
          final repoWithFilter = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileSearchFilter: (query, profiles) {
              filterCalled = true;
              return profiles;
            },
          );

          await repoWithFilter.searchUsersProgressive(query: 'test').last;

          expect(filterCalled, isTrue);
        });

        test(
          'skips client-side filter on final yield when sortBy is set',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.searchProfiles(
                query: 'alice',
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                sortBy: 'followers',
                hasVideos: any(named: 'hasVideos'),
              ),
            ).thenAnswer(
              (_) async => [
                ProfileSearchResult(
                  pubkey: 'a' * 64,
                  displayName: 'Alice REST',
                  createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
                ),
              ],
            );

            when(
              () => mockNostrClient.queryUsers('alice', limit: 200),
            ).thenAnswer((_) async => []);

            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenAnswer((_) async => []);

            // Track filter calls with their context
            var finalYieldFilterCalled = false;
            final repoWithFunnelcake = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
              profileSearchFilter: (query, profiles) {
                // The filter may be called by searchUsersLocally (local phase),
                // but should NOT be called by _applyFilter when sortBy is set.
                // If called with non-empty profiles it means the final yield
                // is filtering — which it shouldn't with server sort.
                if (profiles.isNotEmpty) finalYieldFilterCalled = true;
                return profiles;
              },
            );

            // Act
            final result = await repoWithFunnelcake
                .searchUsersProgressive(query: 'alice', sortBy: 'followers')
                .last;

            // Assert - final yield preserves server order, filter not called
            // on non-empty results
            expect(result, hasLength(1));
            expect(result.first.displayName, equals('Alice REST'));
            expect(finalYieldFilterCalled, isFalse);
          },
        );
      });
    });

    group('exceptions', () {
      test('ProfilePublishFailedException has message and toString', () {
        const e = ProfilePublishFailedException('test');

        expect(e.message, equals('test'));
        expect(e.toString(), contains('test'));
      });

      test('ProfileRepositoryException handles null message', () {
        const e = ProfileRepositoryException();

        expect(e.message, isNull);
        expect(e.toString(), contains('ProfileRepositoryException'));
      });
    });

    group('claimUsername', () {
      test('returns UsernameClaimSuccess when response is 200', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 200)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(usernameClaimResult, equals(const UsernameClaimSuccess()));
      });

      test('returns UsernameClaimSuccess when response is 201', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 201)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(usernameClaimResult, equals(const UsernameClaimSuccess()));
      });

      test('returns UsernameClaimReserved when response is 403', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 403)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(usernameClaimResult, equals(const UsernameClaimReserved()));
      });

      test('returns UsernameClaimTaken when response is 409', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 409)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(usernameClaimResult, equals(const UsernameClaimTaken()));
      });

      test('returns UsernameClaimError when response is unexpected', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('body', 500)));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(
          usernameClaimResult,
          isA<UsernameClaimError>().having(
            (e) => e.message,
            'message',
            'Unexpected response: 500',
          ),
        );
      });

      test('returns UsernameClaimError on network exception ', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('network exception'));

        final usernameClaimResult = await profileRepository.claimUsername(
          username: 'username',
        );
        expect(
          usernameClaimResult,
          isA<UsernameClaimError>().having(
            (e) => e.message,
            'message',
            'Network error: Exception: network exception',
          ),
        );
      });

      test(
        'returns UsernameClaimError when nip98 auth header is null',
        () async {
          when(
            () => mockNostrClient.createNip98AuthHeader(
              url: any(named: 'url'),
              method: any(named: 'method'),
              payload: any(named: 'payload'),
            ),
          ).thenAnswer((_) => Future.value());

          final usernameClaimResult = await profileRepository.claimUsername(
            username: 'username',
          );
          expect(
            usernameClaimResult,
            isA<UsernameClaimError>().having(
              (e) => e.message,
              'message',
              'Nip98 authorization failed',
            ),
          );

          verifyNever(() => mockHttpClient.post(any()));
        },
      );

      test(
        'sends lowercase username in payload for mixed-case input',
        () async {
          final expectedPayload = jsonEncode({'name': 'testuser'});
          when(
            () => mockNostrClient.createNip98AuthHeader(
              url: any(named: 'url'),
              method: any(named: 'method'),
              payload: any(named: 'payload'),
            ),
          ).thenAnswer((_) => Future.value('authHeader'));
          when(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) => Future.value(Response('body', 200)));

          final result = await profileRepository.claimUsername(
            username: 'TestUser',
          );

          expect(result, equals(const UsernameClaimSuccess()));
          verify(
            () => mockHttpClient.post(
              Uri.parse('https://names.divine.video/api/username/claim'),
              headers: any(named: 'headers'),
              body: expectedPayload,
            ),
          ).called(1);
        },
      );

      test('returns server error message when server returns '
          'non-200 with JSON error body', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) => Future.value(Response('{"error": "Username too short"}', 400)),
        );

        final result = await profileRepository.claimUsername(username: 'ab');

        expect(
          result,
          isA<UsernameClaimError>().having(
            (e) => e.message,
            'message',
            'Username too short',
          ),
        );
      });

      test('returns error with default message when server returns '
          'non-200 with unparseable body', () async {
        when(
          () => mockNostrClient.createNip98AuthHeader(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) => Future.value('authHeader'));
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) => Future.value(Response('not json at all', 400)));

        final result = await profileRepository.claimUsername(
          username: 'baduser',
        );

        expect(
          result,
          isA<UsernameClaimError>().having(
            (e) => e.message,
            'message',
            'Invalid username format',
          ),
        );
      });
    });

    group('UsernameClaimResult', () {
      test('UsernameClaimError toString returns formatted message', () {
        const error = UsernameClaimError('test error');
        expect(error.toString(), equals('UsernameClaimError(test error)'));
      });
    });

    group('checkUsernameAvailability', () {
      // Helper: stub name-server check endpoint
      void stubNameServerCheck(
        String username, {
        bool available = true,
        String? reason,
        String? code,
        int statusCode = 200,
      }) {
        when(
          () => mockHttpClient.get(
            Uri.parse(
              'https://names.divine.video/api/username/check/$username',
            ),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'available': available,
              'reason': ?reason,
              'code': ?code,
            }),
            statusCode,
          ),
        );
      }

      // Helper: stub keycast NIP-05 endpoint
      void stubKeycastCheck(
        String username, {
        bool taken = false,
        int statusCode = 200,
      }) {
        when(
          () => mockHttpClient.get(
            Uri.parse(
              'https://login.divine.video/.well-known/nostr.json'
              '?name=$username',
            ),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'names': taken ? {username: 'pubkey123'} : <String, dynamic>{},
            }),
            statusCode,
          ),
        );
      }

      test(
        'returns UsernameAvailable when both servers say available',
        () async {
          stubNameServerCheck('newuser');
          stubKeycastCheck('newuser');

          final result = await profileRepository.checkUsernameAvailability(
            username: 'newuser',
          );

          expect(result, equals(const UsernameAvailable()));
        },
      );

      test(
        'returns UsernameTaken when name-server says not available',
        () async {
          stubNameServerCheck('takenuser', available: false);

          final result = await profileRepository.checkUsernameAvailability(
            username: 'takenuser',
          );

          expect(result, equals(const UsernameTaken()));
        },
      );

      test('returns UsernameTaken when name-server says available but '
          'keycast has it', () async {
        stubNameServerCheck('keycastuser');
        stubKeycastCheck('keycastuser', taken: true);

        final result = await profileRepository.checkUsernameAvailability(
          username: 'keycastuser',
        );

        expect(result, equals(const UsernameTaken()));
      });

      test('returns UsernameAvailable when keycast is unreachable '
          'but name-server says available', () async {
        stubNameServerCheck('testuser');
        when(
          () => mockHttpClient.get(
            Uri.parse(
              'https://login.divine.video/.well-known/nostr.json'
              '?name=testuser',
            ),
          ),
        ).thenThrow(Exception('Connection timeout'));

        final result = await profileRepository.checkUsernameAvailability(
          username: 'testuser',
        );

        // Keycast failure is non-blocking
        expect(result, equals(const UsernameAvailable()));
      });

      test('returns UsernameInvalidFormat for names with dots', () async {
        final result = await profileRepository.checkUsernameAvailability(
          username: 'mr.',
        );

        expect(result, isA<UsernameInvalidFormat>());
      });

      test(
        'returns UsernameInvalidFormat for names with underscores',
        () async {
          final result = await profileRepository.checkUsernameAvailability(
            username: 'my_name',
          );

          expect(result, isA<UsernameInvalidFormat>());
        },
      );

      test(
        'returns UsernameInvalidFormat for names starting with hyphen',
        () async {
          final result = await profileRepository.checkUsernameAvailability(
            username: '-alice',
          );

          expect(result, isA<UsernameInvalidFormat>());
        },
      );

      test(
        'returns UsernameInvalidFormat for names ending with hyphen',
        () async {
          final result = await profileRepository.checkUsernameAvailability(
            username: 'alice-',
          );

          expect(result, isA<UsernameInvalidFormat>());
        },
      );

      test('returns UsernameCheckError when name-server returns 500', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('https://names.divine.video/api/username/check/testuser'),
          ),
        ).thenAnswer((_) async => Response('Server error', 500));

        final result = await profileRepository.checkUsernameAvailability(
          username: 'testuser',
        );

        expect(
          result,
          isA<UsernameCheckError>().having(
            (e) => e.message,
            'message',
            'Server returned status 500',
          ),
        );
      });

      test('returns UsernameCheckError on network exception', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('https://names.divine.video/api/username/check/testuser'),
          ),
        ).thenThrow(Exception('Connection timeout'));

        final result = await profileRepository.checkUsernameAvailability(
          username: 'testuser',
        );

        expect(
          result,
          isA<UsernameCheckError>().having(
            (e) => e.message,
            'message',
            'Network error: Exception: Connection timeout',
          ),
        );
      });

      test('normalizes username to lowercase', () async {
        stubNameServerCheck('alice');
        stubKeycastCheck('alice');

        final result = await profileRepository.checkUsernameAvailability(
          username: 'Alice',
        );

        expect(result, equals(const UsernameAvailable()));

        verify(
          () => mockHttpClient.get(
            Uri.parse('https://names.divine.video/api/username/check/alice'),
          ),
        ).called(1);
      });

      // --- code field tests ---

      test('returns $UsernameReserved when code is reserved', () async {
        stubNameServerCheck(
          'admin',
          available: false,
          code: 'reserved',
          reason: 'Username is reserved',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'admin',
        );
        expect(result, isA<UsernameReserved>());
      });

      test('returns $UsernameBurned when code is burned', () async {
        stubNameServerCheck(
          'badname',
          available: false,
          code: 'burned',
          reason: 'Username has been burned',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'badname',
        );
        expect(result, isA<UsernameBurned>());
      });

      test('returns $UsernameTaken when code is taken', () async {
        stubNameServerCheck(
          'alice',
          available: false,
          code: 'taken',
          reason: 'Username is already taken',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'alice',
        );
        expect(result, isA<UsernameTaken>());
      });

      test(
        'returns $UsernameTaken when code is pending_confirmation',
        () async {
          stubNameServerCheck(
            'pending',
            available: false,
            code: 'pending_confirmation',
            reason: 'Username is pending confirmation',
          );
          final result = await profileRepository.checkUsernameAvailability(
            username: 'pending',
          );
          expect(result, isA<UsernameTaken>());
        },
      );

      test(
        'returns $UsernameInvalidFormat when code is invalid_format',
        () async {
          stubNameServerCheck(
            'bad..name',
            available: false,
            code: 'invalid_format',
            reason: 'Contains consecutive dots',
          );
          final result = await profileRepository.checkUsernameAvailability(
            username: 'bad..name',
          );
          expect(result, isA<UsernameInvalidFormat>());
        },
      );

      test('returns $UsernameInvalidFormat with fallback message '
          'when code is invalid_format but no reason', () async {
        stubNameServerCheck('bad', available: false, code: 'invalid_format');
        final result = await profileRepository.checkUsernameAvailability(
          username: 'bad',
        );
        expect(result, isA<UsernameInvalidFormat>());
        expect(
          (result as UsernameInvalidFormat).reason,
          equals('Invalid username format'),
        );
      });

      test('returns $UsernameTaken when code field is missing', () async {
        stubNameServerCheck(
          'mystery',
          available: false,
          reason: 'Something unexpected',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'mystery',
        );
        expect(result, isA<UsernameTaken>());
      });

      test('returns UsernameAvailable when name is taken but pubkey matches '
          'current user (admin-assigned)', () async {
        // Simulate the name-server returning pubkey for an active name
        when(
          () => mockHttpClient.get(
            Uri.parse('https://names.divine.video/api/username/check/vipuser'),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'ok': true,
              'available': false,
              'status': 'active',
              'pubkey': testPubkey,
              'reason': 'Username is already taken',
            }),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'vipuser',
          currentUserPubkey: testPubkey,
        );

        expect(result, equals(const UsernameAvailable()));
      });

      test('returns UsernameTaken when name is taken and pubkey does not match '
          'current user', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('https://names.divine.video/api/username/check/vipuser'),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'ok': true,
              'available': false,
              'status': 'active',
              'pubkey': otherPubkey,
              'reason': 'Username is already taken',
            }),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'vipuser',
          currentUserPubkey: testPubkey,
        );

        expect(result, equals(const UsernameTaken()));
      });

      test('returns UsernameTaken when name is taken and no currentUserPubkey '
          'provided (backwards compatible)', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('https://names.divine.video/api/username/check/vipuser'),
          ),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'ok': true,
              'available': false,
              'status': 'active',
              'pubkey': testPubkey,
              'reason': 'Username is already taken',
            }),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'vipuser',
        );

        expect(result, equals(const UsernameTaken()));
      });
    });

    group('UsernameAvailabilityResult', () {
      test('UsernameCheckError toString returns formatted message', () {
        const error = UsernameCheckError('test error');
        expect(error.toString(), equals('UsernameCheckError(test error)'));
      });
    });

    group('getUserProfileFromApi', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns profile data on success', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getUserProfile(testPubkey)).thenAnswer(
          (_) async => {
            'pubkey': testPubkey,
            'display_name': 'Test User',
            'picture': 'https://example.com/avatar.png',
          },
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getUserProfileFromApi(
          pubkey: testPubkey,
        );

        expect(result, isNotNull);
        expect(result!['display_name'], equals('Test User'));
        verify(() => mockFunnelcakeClient.getUserProfile(testPubkey)).called(1);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getUserProfileFromApi(
          pubkey: testPubkey,
        );

        expect(result, isNull);
        verifyNever(() => mockFunnelcakeClient.getUserProfile(any()));
      });

      test('returns null when client is null', () async {
        final result = await profileRepository.getUserProfileFromApi(
          pubkey: testPubkey,
        );

        expect(result, isNull);
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getUserProfile(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/users',
          ),
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getUserProfileFromApi(pubkey: testPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('propagates FunnelcakeTimeoutException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getUserProfile(any()),
        ).thenThrow(const FunnelcakeTimeoutException());

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getUserProfileFromApi(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getBulkProfilesFromApi', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns BulkProfilesResponse on success', () async {
        const testResponse = BulkProfilesResponse(
          profiles: {
            testPubkey: {
              'display_name': 'Test User',
              'picture': 'https://example.com/avatar.png',
            },
          },
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkProfiles([testPubkey]),
        ).thenAnswer((_) async => testResponse);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getBulkProfilesFromApi([
          testPubkey,
        ]);

        expect(result, isNotNull);
        expect(result!.profiles, hasLength(1));
        expect(result.profiles[testPubkey], isNotNull);
        verify(
          () => mockFunnelcakeClient.getBulkProfiles([testPubkey]),
        ).called(1);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getBulkProfilesFromApi([
          testPubkey,
        ]);

        expect(result, isNull);
        verifyNever(() => mockFunnelcakeClient.getBulkProfiles(any()));
      });

      test('returns null when client is null', () async {
        final result = await profileRepository.getBulkProfilesFromApi([
          testPubkey,
        ]);

        expect(result, isNull);
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/users/bulk',
          ),
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getBulkProfilesFromApi([testPubkey]),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('propagates FunnelcakeTimeoutException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkProfiles(any()),
        ).thenThrow(const FunnelcakeTimeoutException());

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getBulkProfilesFromApi([testPubkey]),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getSocialCounts', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns SocialCounts when client is available', () async {
        const expectedCounts = SocialCounts(
          pubkey: testPubkey,
          followerCount: 42,
          followingCount: 10,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getSocialCounts(testPubkey),
        ).thenAnswer((_) async => expectedCounts);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getSocialCounts(testPubkey);

        expect(result, isNotNull);
        expect(result!.followerCount, 42);
        expect(result.followingCount, 10);
        verify(
          () => mockFunnelcakeClient.getSocialCounts(testPubkey),
        ).called(1);
      });

      test('returns null when client is null', () async {
        final result = await profileRepository.getSocialCounts(testPubkey);

        expect(result, isNull);
      });

      test('returns null when client is not available', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getSocialCounts(testPubkey);

        expect(result, isNull);
        verifyNever(() => mockFunnelcakeClient.getSocialCounts(any()));
      });

      test('passes pubkey to client correctly', () async {
        // Uses the sibling otherPubkey constant defined in the parent group.
        const expectedCounts = SocialCounts(
          pubkey: otherPubkey,
          followerCount: 5,
          followingCount: 3,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getSocialCounts(otherPubkey),
        ).thenAnswer((_) async => expectedCounts);

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.getSocialCounts(otherPubkey);

        expect(result, isNotNull);
        verify(
          () => mockFunnelcakeClient.getSocialCounts(otherPubkey),
        ).called(1);
        verifyNever(
          () => mockFunnelcakeClient.getSocialCounts(testPubkey),
        );
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getSocialCounts(any()),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/users/$testPubkey/social',
          ),
        );

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repoWithFunnelcake.getSocialCounts(testPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('fetchBatchProfiles', () {
      const testPubkey2 =
          'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
      const testPubkey3 =
          'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';

      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();

        registerFallbackValue(<UserProfile>[]);
      });

      test('returns empty map for empty pubkeys', () async {
        final result = await profileRepository.fetchBatchProfiles(pubkeys: []);
        expect(result, isEmpty);
      });

      test('returns all from cache when all are cached', () async {
        final cached = UserProfile(
          pubkey: testPubkey,
          displayName: 'Cached',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'cached-event',
        );
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys([testPubkey]),
        ).thenAnswer((_) async => [cached]);

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('Cached'));
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });

      test('fetches uncached from Funnelcake API', () async {
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
          (_) async => const BulkProfilesResponse(
            profiles: {
              testPubkey: {
                'display_name': 'API User',
                'picture': 'https://example.com/pic.jpg',
              },
            },
          ),
        );
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('API User'));
        verify(() => mockUserProfilesDao.upsertProfiles(any())).called(1);
      });

      test('falls back to relay for pubkeys not in cache or API', () async {
        final relayEvent = MockEvent();
        when(() => relayEvent.kind).thenReturn(0);
        when(() => relayEvent.pubkey).thenReturn(testPubkey);
        when(() => relayEvent.createdAt).thenReturn(1704067200);
        when(() => relayEvent.id).thenReturn(testEventId);
        when(
          () => relayEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Relay User'}));

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => relayEvent);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('Relay User'));
      });

      test('combines cache, API, and relay results', () async {
        final cachedProfile = UserProfile(
          pubkey: testPubkey,
          displayName: 'Cached',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'cached-event',
        );

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => [cachedProfile]);
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
          (_) async => const BulkProfilesResponse(
            profiles: {
              testPubkey2: {'display_name': 'API User'},
            },
          ),
        );

        final relayEvent = MockEvent();
        when(() => relayEvent.kind).thenReturn(0);
        when(() => relayEvent.pubkey).thenReturn(testPubkey3);
        when(() => relayEvent.createdAt).thenReturn(1704067200);
        when(() => relayEvent.id).thenReturn(
          'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5',
        );
        when(
          () => relayEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Relay User'}));

        when(
          () => mockNostrClient.fetchProfile(testPubkey3),
        ).thenAnswer((_) async => relayEvent);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.fetchBatchProfiles(
          pubkeys: [testPubkey, testPubkey2, testPubkey3],
        );

        expect(result, hasLength(3));
        expect(result[testPubkey]?.displayName, equals('Cached'));
        expect(result[testPubkey2]?.displayName, equals('API User'));
        expect(result[testPubkey3]?.displayName, equals('Relay User'));
      });

      test('handles API failure gracefully and falls back to relay', () async {
        final relayEvent = MockEvent();
        when(() => relayEvent.kind).thenReturn(0);
        when(() => relayEvent.pubkey).thenReturn(testPubkey);
        when(() => relayEvent.createdAt).thenReturn(1704067200);
        when(() => relayEvent.id).thenReturn(testEventId);
        when(
          () => relayEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Relay Fallback'}));

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com',
          ),
        );
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => relayEvent);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final repoWithFunnelcake = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repoWithFunnelcake.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('Relay Fallback'));
      });

      test('handles relay failure gracefully with partial results', () async {
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenThrow(Exception('Relay error'));
        // Step 4 indexer fallback also calls queryEvents
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, isEmpty);
      });

      test('falls back to indexer relay when step 3 returns nothing', () async {
        final indexerEvent = MockEvent();
        when(() => indexerEvent.kind).thenReturn(0);
        when(() => indexerEvent.pubkey).thenReturn(testPubkey);
        when(() => indexerEvent.createdAt).thenReturn(1704067200);
        when(() => indexerEvent.id).thenReturn(testEventId);
        when(
          () => indexerEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Indexer User'}));

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        // Step 3 returns null (no result)
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);
        // Step 4 indexer fallback returns the profile
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [indexerEvent]);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('Indexer User'));
      });

      test('handles indexer relay failure gracefully', () async {
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        // Step 3 returns null
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);
        // Step 4 indexer fallback throws
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenThrow(Exception('Indexer error'));

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, isEmpty);
      });

      test(
        'skips relay fallback for _noProfile sentinel entries',
        () async {
          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
            (_) async => const BulkProfilesResponse(
              profiles: {
                testPubkey: {'_noProfile': true},
              },
            ),
          );

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake.fetchBatchProfiles(
            pubkeys: [testPubkey],
          );

          expect(result, isEmpty);
          verifyNever(() => mockNostrClient.fetchProfile(any()));
          verifyNever(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          );
          verifyNever(
            () => mockUserProfilesDao.upsertProfiles(any()),
          );
        },
      );

      test(
        'processes real profiles alongside _noProfile sentinels',
        () async {
          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
            (_) async => const BulkProfilesResponse(
              profiles: {
                testPubkey: {'display_name': 'Real User'},
                testPubkey2: {'_noProfile': true},
              },
            ),
          );
          when(
            () => mockUserProfilesDao.upsertProfiles(any()),
          ).thenAnswer((_) async {});

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repoWithFunnelcake.fetchBatchProfiles(
            pubkeys: [testPubkey, testPubkey2],
          );

          expect(result, hasLength(1));
          expect(
            result[testPubkey]?.displayName,
            equals('Real User'),
          );
          expect(result.containsKey(testPubkey2), isFalse);
          verifyNever(() => mockNostrClient.fetchProfile(any()));
        },
      );

      test('does not batch-write when nothing was fetched', () async {
        final cached = UserProfile(
          pubkey: testPubkey,
          displayName: 'Cached',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'cached-event',
        );
        when(
          () => mockUserProfilesDao.getProfilesByPubkeys([testPubkey]),
        ).thenAnswer((_) async => [cached]);

        await profileRepository.fetchBatchProfiles(pubkeys: [testPubkey]);

        verifyNever(() => mockUserProfilesDao.upsertProfiles(any()));
      });
    });
  });
}

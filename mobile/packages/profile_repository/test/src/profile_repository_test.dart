import 'dart:async';
import 'dart:convert';

// Hide Drift table class to avoid collision with ProfileStats domain model.
import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockEvent extends Mock implements Event {
  @override
  DateTime get createdAtDateTime =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000, isUtc: true);

  @override
  List<List<String>> get tags => const [];
}

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
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      UserProfile? storedProfile;
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

      // Default stub for parallel indexer queries.
      when(
        () => mockNostrClient.queryEvents(
          any(),
          tempRelays: any(named: 'tempRelays'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => <Event>[]);

      when(
        () => mockNostrClient.sendProfileAwaitOk(
          profileContent: any(named: 'profileContent'),
        ),
      ).thenAnswer((_) async => PublishSuccess(event: mockProfileEvent));
      when(() => mockUserProfilesDao.getProfile(any())).thenAnswer((
        invocation,
      ) async {
        final pubkey = invocation.positionalArguments.first as String;
        if (storedProfile?.pubkey == pubkey) {
          return storedProfile;
        }
        return null;
      });
      when(() => mockUserProfilesDao.upsertProfile(any())).thenAnswer((
        invocation,
      ) async {
        storedProfile = invocation.positionalArguments.first as UserProfile;
      });
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

      test(
        'removes pubkey from known cached set on successful delete',
        () async {
          final profile = UserProfile.fromNostrEvent(mockProfileEvent);
          await profileRepository.cacheProfile(profile);
          expect(profileRepository.hasProfile(testPubkey), isTrue);

          when(
            () => mockUserProfilesDao.deleteProfile(any()),
          ).thenAnswer((_) async => 1);

          await profileRepository.deleteCachedProfile(pubkey: testPubkey);

          expect(profileRepository.hasProfile(testPubkey), isFalse);
        },
      );

      test('keeps pubkey in known cached set when delete is a no-op', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        await profileRepository.cacheProfile(profile);
        expect(profileRepository.hasProfile(testPubkey), isTrue);

        when(
          () => mockUserProfilesDao.deleteProfile(any()),
        ).thenAnswer((_) async => 0);

        await profileRepository.deleteCachedProfile(pubkey: testPubkey);

        expect(profileRepository.hasProfile(testPubkey), isTrue);
      });

      test('does not mark pubkey as confirmed missing on delete', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        await profileRepository.cacheProfile(profile);
        when(
          () => mockUserProfilesDao.deleteProfile(any()),
        ).thenAnswer((_) async => 1);

        await profileRepository.deleteCachedProfile(pubkey: testPubkey);

        expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
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
        'rechecks sources on explicit fetch after confirmed missing',
        () async {
          stubAllSourcesMiss();

          // First call — hits all sources, marks missing
          final firstResult = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );
          expect(firstResult, isNull);
          expect(profileRepository.isConfirmedMissing(testPubkey), isTrue);

          // Second call — explicit fetch should clear the stale marker
          // and try the sources again.
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => mockProfileEvent);

          final secondResult = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(secondResult, isNotNull);
          expect(secondResult!.pubkey, equals(testPubkey));
          expect(profileRepository.isConfirmedMissing(testPubkey), isFalse);
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(2);
          verify(() => mockUserProfilesDao.upsertProfile(any())).called(1);
        },
      );

      test('deduplicates concurrent calls for the same pubkey', () async {
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
        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
      });

      group('with Funnelcake API', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;
        late MockProfileStatsDao mockProfileStatsDao;
        late ProfileRepository repoWithFunnelcake;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          mockProfileStatsDao = MockProfileStatsDao();
          when(
            () => mockProfileStatsDao.upsertStats(
              pubkey: any(named: 'pubkey'),
              videoCount: any(named: 'videoCount'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
              totalViews: any(named: 'totalViews'),
              totalLikes: any(named: 'totalLikes'),
            ),
          ).thenAnswer((_) async {});
          repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockProfileStatsDao,
          );
        });

        test('uses Funnelcake REST API first when available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'REST User',
                'name': 'restuser',
                'picture': 'https://example.com/pic.png',
              }),
            ),
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

        test('marks missing immediately when Funnelcake returns '
            'UserProfileNotPublished', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileNotPublished(
              pubkey: testPubkey,
              social: ProfileSocialData.fromJson(const {
                'follower_count': 12,
                'following_count': 7,
              }),
              stats: ProfileStatsData.fromJson(const {'video_count': 3}),
              engagement: ProfileEngagementData.fromJson(const {
                'total_reactions': 42,
                'total_loops': 12.6,
                'total_views': 99,
              }),
            ),
          );

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
          expect(repoWithFunnelcake.isConfirmedMissing(testPubkey), isTrue);
          // Should NOT fall through to relay or indexer
          verifyNever(() => mockNostrClient.fetchProfile(any()));
          verifyNever(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          );
          verify(
            () => mockProfileStatsDao.upsertStats(
              pubkey: testPubkey,
              followerCount: 12,
              followingCount: 7,
              videoCount: 3,
              totalLikes: 42,
              totalViews: 99,
            ),
          ).called(1);
        });

        test('uses rounded loops when unified views are unavailable', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileNotPublished(
              pubkey: testPubkey,
              engagement: ProfileEngagementData.fromJson(const {
                'total_loops': 12.6,
                'total_views': 0,
              }),
            ),
          );

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNull);
          expect(repoWithFunnelcake.isConfirmedMissing(testPubkey), isTrue);
          verify(
            () => mockProfileStatsDao.upsertStats(
              pubkey: testPubkey,
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
              videoCount: any(named: 'videoCount'),
              totalLikes: any(named: 'totalLikes'),
              totalViews: 13,
            ),
          ).called(1);
        });

        test('skips Funnelcake when not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          final result = await repoWithFunnelcake.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Test User'));
          verifyNever(() => mockFunnelcakeClient.getUserProfile(any()));
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        });

        test('does not overwrite a newer locally-cached bio with stale '
            'Funnelcake data (regression: bio appears not to save)', () async {
          // Simulate: user just saved their bio. The local cache holds the
          // freshly-published profile (newer). Funnelcake returns a stale
          // profile carrying its original — older — Kind 0 timestamp
          // (profile.profile_updated). Newest-wins must keep the local copy:
          // no overwrite, and the newer local profile is returned (#3141,
          // follow-up to #3104).
          final freshlySavedProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Test User',
            about: 'My new bio',
            rawData: const {'display_name': 'Test User', 'about': 'My new bio'},
            createdAt: DateTime.utc(2024, 1, 2), // newer — just saved
            eventId: testEventId,
          );

          // Use a fresh DAO mock so we can control getProfile return values
          // without stub-ordering issues from the outer setUp.
          final freshDao = MockUserProfilesDao();
          when(
            () => freshDao.getProfile(any()),
          ).thenAnswer((_) async => freshlySavedProfile);
          when(() => freshDao.upsertProfile(any())).thenAnswer((_) async {});

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: freshDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockProfileStatsDao,
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'Test User',
                'about': '', // stale — bio not yet indexed by Funnelcake
                'profile_updated': '2024-01-01T00:00:00Z', // older
              }),
            ),
          );

          final result = await repo.fetchFreshProfile(pubkey: testPubkey);

          // The stale Funnelcake profile must NOT overwrite the newer cache.
          verifyNever(
            () => freshDao.upsertProfile(
              any(
                that: isA<UserProfile>().having(
                  (p) => p.about,
                  'about',
                  equals(''),
                ),
              ),
            ),
          );

          // Funnelcake now carries the original Kind 0 timestamp, so the
          // relay fallback is no longer needed to protect a freshly-saved
          // bio — newest-wins resolves it directly.
          verifyNever(() => mockNostrClient.fetchProfile(any()));

          // The newer local profile is returned, not the stale Funnelcake
          // copy.
          expect(result, isNotNull);
          expect(result!.about, equals('My new bio'));
        });

        test('updates an older locally-cached profile when Funnelcake has a '
            'newer one (#3141)', () async {
          // The local cache holds an older profile. Funnelcake returns a
          // newer profile carrying a newer original Kind 0 timestamp.
          // Newest-wins must upsert the Funnelcake copy and return it.
          final olderLocalProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Old Name',
            about: 'Old bio',
            rawData: const {'display_name': 'Old Name', 'about': 'Old bio'},
            createdAt: DateTime.utc(2024), // older
            eventId: testEventId,
          );

          UserProfile? stored = olderLocalProfile;
          final freshDao = MockUserProfilesDao();
          when(
            () => freshDao.getProfile(any()),
          ).thenAnswer((_) async => stored);
          when(() => freshDao.upsertProfile(any())).thenAnswer((
            invocation,
          ) async {
            stored = invocation.positionalArguments.first as UserProfile;
          });

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: freshDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockProfileStatsDao,
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'New Name',
                'about': 'New bio',
                'profile_updated': '2024-02-01T00:00:00Z', // newer
              }),
            ),
          );

          final result = await repo.fetchFreshProfile(pubkey: testPubkey);

          // The newer Funnelcake profile upgrades the cache.
          verify(
            () => freshDao.upsertProfile(
              any(
                that: isA<UserProfile>().having(
                  (p) => p.about,
                  'about',
                  equals('New bio'),
                ),
              ),
            ),
          ).called(1);

          // Resolved directly from Funnelcake; no relay fallback needed.
          verifyNever(() => mockNostrClient.fetchProfile(any()));

          expect(result, isNotNull);
          expect(result!.about, equals('New bio'));
          expect(result.displayName, equals('New Name'));
        });

        test('returns the richer local profile on a createdAt tie instead of '
            'the leaner Funnelcake copy (#3141)', () async {
          // Local cache and Funnelcake share the same Kind 0 timestamp.
          // _cacheProfileIfNewer keeps the local copy (not strictly newer),
          // so the return value must match the cache — the richer local
          // profile, not the leaner Funnelcake one that may omit fields.
          final localProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Local Name',
            about: 'Local bio',
            rawData: const {'display_name': 'Local Name', 'about': 'Local bio'},
            createdAt: DateTime.utc(2024, 3),
            eventId: testEventId,
          );

          final freshDao = MockUserProfilesDao();
          when(
            () => freshDao.getProfile(any()),
          ).thenAnswer((_) async => localProfile);
          when(() => freshDao.upsertProfile(any())).thenAnswer((_) async {});

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: freshDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            profileStatsDao: mockProfileStatsDao,
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getUserProfile(testPubkey),
          ).thenAnswer(
            (_) async => UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'Funnelcake Name',
                'about': 'Funnelcake bio',
                'profile_updated': '2024-03-01T00:00:00Z', // tie
              }),
            ),
          );

          final result = await repo.fetchFreshProfile(pubkey: testPubkey);

          // Tie is not strictly newer — the cache is untouched.
          verifyNever(() => freshDao.upsertProfile(any()));
          // Resolved directly from the cache; no relay fallback.
          verifyNever(() => mockNostrClient.fetchProfile(any()));
          // The returned profile is the richer local copy, not Funnelcake's.
          expect(result, isNotNull);
          expect(result!.about, equals('Local bio'));
          expect(result.displayName, equals('Local Name'));
        });

        test(
          'keeps the local cache and falls through to relay when a found '
          'Funnelcake profile carries no timestamp (defensive #3141)',
          () async {
            // Funnelcake returns a found profile but omits profile_updated, so
            // UserProfileData.createdAt is null. With a local profile already
            // cached, newest-wins cannot be applied, so the conservative path
            // must run: do NOT overwrite the cache with the timestamp-less
            // copy, and fall through to the relay/indexer path so a newer
            // Kind 0 can still win.
            final localProfile = UserProfile(
              pubkey: testPubkey,
              displayName: 'Local Name',
              about: 'Local bio',
              rawData: const {
                'display_name': 'Local Name',
                'about': 'Local bio',
              },
              createdAt: DateTime.utc(2024),
              eventId: testEventId,
            );

            final freshDao = MockUserProfilesDao();
            when(
              () => freshDao.getProfile(any()),
            ).thenAnswer((_) async => localProfile);
            when(() => freshDao.upsertProfile(any())).thenAnswer((_) async {});

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: freshDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
              profileStatsDao: mockProfileStatsDao,
            );

            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getUserProfile(testPubkey),
            ).thenAnswer(
              (_) async => UserProfileFound(
                profile: UserProfileData.fromJson(testPubkey, const {
                  'display_name': 'Funnelcake Name',
                  'about': 'Funnelcake bio',
                  // No profile_updated → createdAt stays null.
                }),
              ),
            );

            // Relays find nothing newer — the local cache is the fallback.
            when(
              () => mockNostrClient.fetchProfile(testPubkey),
            ).thenAnswer((_) async => null);

            final result = await repo.fetchFreshProfile(pubkey: testPubkey);

            // The timestamp-less Funnelcake copy must not overwrite the cache.
            verifyNever(() => freshDao.upsertProfile(any()));

            // The relay path must run so a newer Kind 0 can still win.
            verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);

            // Relays found nothing newer, so the local cache is returned.
            expect(result, isNotNull);
            expect(result!.about, equals('Local bio'));
          },
        );
      });

      group('indexer relay fallback', () {
        late MockEvent mockIndexerEvent;

        setUp(() {
          mockIndexerEvent = MockEvent();
          when(() => mockIndexerEvent.kind).thenReturn(0);
          when(() => mockIndexerEvent.pubkey).thenReturn(testPubkey);
          when(() => mockIndexerEvent.createdAt).thenReturn(1704067200);
          when(() => mockIndexerEvent.id).thenReturn('idx_$testEventId');
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

        test(
          'picks newest kind-0 event when indexer returns multiple events '
          'with older event first (regression: bio appears not to save)',
          () async {
            // Simulate: relay returns nothing, but indexer returns two kind-0
            // events for the same pubkey. The older event (stale, no bio) comes
            // first in the list. The fix must select the newest by createdAt.
            when(
              () => mockNostrClient.fetchProfile(testPubkey),
            ).thenAnswer((_) async => null);

            final olderEvent = MockEvent();
            when(() => olderEvent.kind).thenReturn(0);
            when(() => olderEvent.pubkey).thenReturn(testPubkey);
            when(() => olderEvent.createdAt).thenReturn(1704067200); // older
            when(() => olderEvent.id).thenReturn('old_$testEventId');
            when(() => olderEvent.content).thenReturn(
              jsonEncode({'display_name': 'Test User', 'about': ''}),
            );

            final newerEvent = MockEvent();
            when(() => newerEvent.kind).thenReturn(0);
            when(() => newerEvent.pubkey).thenReturn(testPubkey);
            when(() => newerEvent.createdAt).thenReturn(1704153600); // newer
            when(() => newerEvent.id).thenReturn('new_$testEventId');
            when(() => newerEvent.content).thenReturn(
              jsonEncode({
                'display_name': 'Test User',
                'about': 'My saved bio',
              }),
            );

            // Indexer returns older event first, then newer — relay ordering
            // is not guaranteed, so the repository must not trust list order.
            when(
              () => mockNostrClient.queryEvents(
                any(),
                tempRelays: any(named: 'tempRelays'),
                useCache: any(named: 'useCache'),
              ),
            ).thenAnswer((_) async => [olderEvent, newerEvent]);

            final result = await profileRepository.fetchFreshProfile(
              pubkey: testPubkey,
            );

            expect(result, isNotNull);
            expect(result!.about, equals('My saved bio'));
            verify(
              () => mockUserProfilesDao.upsertProfile(
                any(
                  that: isA<UserProfile>().having(
                    (p) => p.about,
                    'about',
                    equals('My saved bio'),
                  ),
                ),
              ),
            ).called(1);
          },
        );
      });

      group('parallel relay + indexer fetch', () {
        test('fires connected and indexer relays concurrently', () async {
          // Both sources miss — verify both are called
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
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: false,
            ),
          ).called(1);
        });

        test('handles connected relay exception gracefully', () async {
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenThrow(Exception('WebSocket error'));
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
        });

        test('handles uncaught Error without hanging', () async {
          // Throw an Error (not Exception) so it escapes
          // _fetchFromConnectedRelays' catch; the safe() wrapper's
          // on Object clause handles it.
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenThrow(StateError('unexpected'));
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
        });

        test('returns relay result when indexer is slower', () async {
          final relayCompleter = Completer<Event?>();
          final indexerCompleter = Completer<List<Event>>();
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) => relayCompleter.future);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) => indexerCompleter.future);

          final fetchFuture = profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );
          relayCompleter.complete(mockProfileEvent);

          final result = await fetchFuture.timeout(
            const Duration(milliseconds: 50),
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Test User'));

          indexerCompleter.complete(<Event>[]);
        });

        test('upgrades cached profile when slower indexer is newer', () async {
          final indexerCompleter = Completer<List<Event>>();
          // Connected relay returns older event (createdAt = 1704067200)
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => mockProfileEvent);
          // Indexer returns newer event (createdAt = 1704153600)
          final indexerEvent = MockEvent();
          when(() => indexerEvent.kind).thenReturn(0);
          when(() => indexerEvent.pubkey).thenReturn(testPubkey);
          when(() => indexerEvent.createdAt).thenReturn(1704153600);
          when(() => indexerEvent.id).thenReturn('idx_$testEventId');
          when(
            () => indexerEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Indexer Name'}));
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) => indexerCompleter.future);

          final fetchFuture = profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );
          final firstResult = await fetchFuture.timeout(
            const Duration(milliseconds: 50),
          );

          expect(firstResult, isNotNull);
          expect(firstResult!.displayName, equals('Test User'));
          verify(
            () => mockUserProfilesDao.upsertProfile(
              any(
                that: isA<UserProfile>().having(
                  (profile) => profile.displayName,
                  'displayName',
                  equals('Test User'),
                ),
              ),
            ),
          ).called(1);

          indexerCompleter.complete([indexerEvent]);
          await Future<void>.delayed(Duration.zero);

          verify(
            () => mockUserProfilesDao.upsertProfile(
              any(
                that: isA<UserProfile>().having(
                  (profile) => profile.displayName,
                  'displayName',
                  equals('Indexer Name'),
                ),
              ),
            ),
          ).called(1);
        });

        test(
          'keeps cached relay profile when slower indexer is older',
          () async {
            final indexerCompleter = Completer<List<Event>>();
            when(
              () => mockNostrClient.fetchProfile(testPubkey),
            ).thenAnswer((_) async => mockProfileEvent);
            final indexerEvent = MockEvent();
            when(() => indexerEvent.kind).thenReturn(0);
            when(() => indexerEvent.pubkey).thenReturn(testPubkey);
            when(() => indexerEvent.createdAt).thenReturn(1703977200);
            when(() => indexerEvent.id).thenReturn('idx_old_$testEventId');
            when(
              () => indexerEvent.content,
            ).thenReturn(jsonEncode({'display_name': 'Old Indexer'}));
            when(
              () => mockNostrClient.queryEvents(
                any(),
                tempRelays: any(named: 'tempRelays'),
                useCache: any(named: 'useCache'),
              ),
            ).thenAnswer((_) => indexerCompleter.future);

            final fetchFuture = profileRepository.fetchFreshProfile(
              pubkey: testPubkey,
            );
            final firstResult = await fetchFuture.timeout(
              const Duration(milliseconds: 50),
            );

            expect(firstResult, isNotNull);
            expect(firstResult!.displayName, equals('Test User'));

            indexerCompleter.complete([indexerEvent]);
            await Future<void>.delayed(Duration.zero);

            verifyNever(
              () => mockUserProfilesDao.upsertProfile(
                any(
                  that: isA<UserProfile>().having(
                    (profile) => profile.displayName,
                    'displayName',
                    equals('Old Indexer'),
                  ),
                ),
              ),
            );
          },
        );

        test('picks newer relay profile over older indexer profile', () async {
          // Connected relay returns newer event (createdAt = 1704153600)
          final newerRelayEvent = MockEvent();
          when(() => newerRelayEvent.kind).thenReturn(0);
          when(() => newerRelayEvent.pubkey).thenReturn(testPubkey);
          when(() => newerRelayEvent.createdAt).thenReturn(1704153600);
          when(() => newerRelayEvent.id).thenReturn('new_$testEventId');
          when(
            () => newerRelayEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Relay Name'}));
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => newerRelayEvent);
          // Indexer returns older event (createdAt = 1704067200)
          final indexerEvent = MockEvent();
          when(() => indexerEvent.kind).thenReturn(0);
          when(() => indexerEvent.pubkey).thenReturn(testPubkey);
          when(() => indexerEvent.createdAt).thenReturn(1704067200);
          when(() => indexerEvent.id).thenReturn('idx_$testEventId');
          when(
            () => indexerEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Old Indexer'}));
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [indexerEvent]);

          final result = await profileRepository.fetchFreshProfile(
            pubkey: testPubkey,
          );

          expect(result, isNotNull);
          expect(result!.displayName, equals('Relay Name'));
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
          () => mockNostrClient.sendProfileAwaitOk(
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
          () => mockNostrClient.sendProfileAwaitOk(
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
          () => mockNostrClient.sendProfileAwaitOk(
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
          () => mockNostrClient.sendProfileAwaitOk(
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
          () => mockNostrClient.sendProfileAwaitOk(
            profileContent: {
              'display_name': 'Test',
              'nip05': 'alice@example.com',
            },
          ),
        ).called(1);
      });

      test(
        'omits unset about/picture/banner keys instead of writing nulls',
        () async {
          await profileRepository.saveProfileEvent(displayName: 'Only Name');

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {'display_name': 'Only Name'},
            ),
          ).called(1);
        },
      );

      test('omits nip05 when neither username nor nip05 is provided', () async {
        await profileRepository.saveProfileEvent(displayName: 'Only Name');

        final captured =
            verify(
                  () => mockNostrClient.sendProfileAwaitOk(
                    profileContent: captureAny(named: 'profileContent'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(captured.containsKey('nip05'), isFalse);
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
          () => mockNostrClient.sendProfileAwaitOk(
            profileContent: {'display_name': 'Test User', 'banner': '0x33ccbf'},
          ),
        ).called(1);
      });

      test('includes website when provided', () async {
        await profileRepository.saveProfileEvent(
          displayName: 'Test User',
          website: 'https://example.com',
        );

        final captured =
            verify(
                  () => mockNostrClient.sendProfileAwaitOk(
                    profileContent: captureAny(named: 'profileContent'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(captured['website'], equals('https://example.com'));
      });

      test('removes website key when empty string is passed', () async {
        final currentProfile = await createCurrentProfile({
          'display_name': 'Old Name',
          'website': 'https://old.com',
        });

        await profileRepository.saveProfileEvent(
          displayName: 'New Name',
          website: '',
          currentProfile: currentProfile,
        );

        final captured =
            verify(
                  () => mockNostrClient.sendProfileAwaitOk(
                    profileContent: captureAny(named: 'profileContent'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(captured.containsKey('website'), isFalse);
      });

      test(
        'throws ProfilePublishFailedException when no relay confirms '
        '(rejection or timeout)',
        () async {
          when(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
            ),
          ).thenAnswer((_) async => const PublishFailed());

          await expectLater(
            profileRepository.saveProfileEvent(displayName: 'Test'),
            throwsA(isA<ProfilePublishFailedException>()),
          );
          verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
        },
      );

      test(
        'throws NoRelaysConnectedException when no relays are connected',
        () async {
          when(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: any(named: 'profileContent'),
            ),
          ).thenAnswer((_) async => const PublishNoRelays());

          await expectLater(
            profileRepository.saveProfileEvent(displayName: 'Test'),
            throwsA(isA<NoRelaysConnectedException>()),
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
            () => mockNostrClient.sendProfileAwaitOk(
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
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {
                'display_name': 'New Name',
                'nip05': '_@newuser.divine.video',
                'about': 'New bio',
              },
            ),
          ).called(1);
        });

        test(
          'clears about/picture/banner when null is explicitly passed',
          () async {
            // The editor surface fills its form fields from the current
            // profile and then sends them as-is. A user clearing their bio,
            // avatar, or banner shows up here as `about: null` /
            // `picture: null` / `banner: null`. The repository must remove
            // those keys from the seed so the cleared values reach the
            // relays.
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'about': 'Old bio',
              'picture': 'https://example.com/old.png',
              'banner': '0xff0000',
            });

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              currentProfile: currentProfile,
            );

            verify(
              () => mockNostrClient.sendProfileAwaitOk(
                profileContent: {'display_name': 'New Name'},
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
              () => mockNostrClient.sendProfileAwaitOk(
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
            about: 'Bio',
            clearNip05: true,
            currentProfile: currentProfile,
          );

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {'display_name': 'New Name', 'about': 'Bio'},
            ),
          ).called(1);
        });

        test('preserves nip05 from currentProfile.rawData when sourced from '
            'Funnelcake REST (post-#4175 fromUserProfileFound mirrors typed '
            'fields into rawData)', () async {
          // After #4175, fromUserProfileFound populates rawData from
          // typed REST fields. Construct a profile in that shape and
          // assert nip05 survives a profile edit unchanged.
          final funnelcakeProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Old Name',
            nip05: '_@ike.divine.video',
            rawData: const {
              'display_name': 'Old Name',
              'nip05': '_@ike.divine.video',
            },
            createdAt: DateTime.now(),
            eventId: 'rest-$testPubkey',
          );

          when(() => mockProfileEvent.content).thenReturn(
            jsonEncode({
              'display_name': 'New Name',
              'nip05': '_@ike.divine.video',
            }),
          );

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            currentProfile: funnelcakeProfile,
          );

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {
                'display_name': 'New Name',
                'nip05': '_@ike.divine.video',
              },
            ),
          ).called(1);
        });

        test('clearNip05 removes nip05 even when sourced from a '
            'post-#4175 Funnelcake profile', () async {
          final funnelcakeProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Old Name',
            nip05: '_@ike.divine.video',
            rawData: const {
              'display_name': 'Old Name',
              'nip05': '_@ike.divine.video',
            },
            createdAt: DateTime.now(),
            eventId: 'rest-$testPubkey',
          );

          await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            clearNip05: true,
            currentProfile: funnelcakeProfile,
          );

          verify(
            () => mockNostrClient.sendProfileAwaitOk(
              profileContent: {'display_name': 'New Name'},
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
              () => mockNostrClient.sendProfileAwaitOk(
                profileContent: {
                  'display_name': 'New Name',
                  'nip05': 'new@example.com',
                },
              ),
            ).called(1);
          },
        );

        test(
          'preserves arbitrary unknown fields when seeded from a '
          'relay-fetched Kind 0 (the load-bearing invariant from #4175)',
          () async {
            // Sets up the relay seed path: fetchProfile returns a Kind 0
            // event whose content carries fields the typed UserProfile
            // model does not know about (custom client keys, NIP-39 i
            // tags, bot, future NIPs). Editing display_name must publish
            // an event with all those fields preserved byte-identical.
            final freshContent = {
              'display_name': 'Old Name',
              'about': 'Existing bio',
              'picture': 'https://example.com/p.png',
              'banner': '0x000000',
              'nip05': 'alice@example.com',
              'lud16': 'alice@strike.me',
              'lud06': 'lnurl1abc',
              'website': 'https://alice.example',
              'bot': true,
              'i': ['github:alice', 'twitter:alice'],
              'weird_future_field': {'nested': 'value'},
            };
            final freshEvent = MockEvent();
            when(() => freshEvent.kind).thenReturn(0);
            when(() => freshEvent.pubkey).thenReturn(testPubkey);
            when(() => freshEvent.id).thenReturn('relay-event-id');
            when(
              () => freshEvent.createdAt,
            ).thenReturn(DateTime.now().millisecondsSinceEpoch ~/ 1000);
            when(() => freshEvent.content).thenReturn(jsonEncode(freshContent));
            when(
              () => mockNostrClient.fetchProfile(
                testPubkey,
                useCache: any(named: 'useCache'),
              ),
            ).thenAnswer((_) async => freshEvent);

            // currentProfile from REST has sparse rawData — the relay seed
            // wins because it has more keys.
            final currentProfile = UserProfile(
              pubkey: testPubkey,
              displayName: 'Old Name',
              nip05: 'alice@example.com',
              rawData: const {
                'display_name': 'Old Name',
                'nip05': 'alice@example.com',
              },
              createdAt: DateTime.now().subtract(const Duration(hours: 1)),
              eventId: 'rest-$testPubkey',
            );

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              about: 'Existing bio',
              picture: 'https://example.com/p.png',
              banner: '0x000000',
              currentProfile: currentProfile,
            );

            final captured =
                verify(
                      () => mockNostrClient.sendProfileAwaitOk(
                        profileContent: captureAny(named: 'profileContent'),
                      ),
                    ).captured.single
                    as Map<String, dynamic>;

            // The user changed display_name only. Every other key should
            // be byte-identical with the relay seed.
            expect(captured['display_name'], equals('New Name'));
            for (final key in freshContent.keys) {
              if (key == 'display_name') continue;
              expect(
                captured[key],
                equals(freshContent[key]),
                reason: 'Field $key was modified by an unrelated edit',
              );
            }
            // No extra keys leaked in.
            expect(captured.keys.toSet(), equals(freshContent.keys.toSet()));
          },
        );

        test(
          'falls back to currentProfile when relay seed fetch fails',
          () async {
            // createCurrentProfile uses fetchProfile internally; build the
            // profile first, THEN stub fetchProfile to throw so only the
            // saveProfileEvent-time seed fetch fails.
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'lud16': 'alice@strike.me',
              'website': 'https://alice.example',
            });
            when(
              () => mockNostrClient.fetchProfile(
                testPubkey,
                useCache: any(named: 'useCache'),
              ),
            ).thenThrow(Exception('relay down'));

            await profileRepository.saveProfileEvent(
              displayName: 'New Name',
              currentProfile: currentProfile,
            );

            verify(
              () => mockNostrClient.sendProfileAwaitOk(
                profileContent: {
                  'display_name': 'New Name',
                  'lud16': 'alice@strike.me',
                  'website': 'https://alice.example',
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

      test('excludes pubkeys hidden by the block filter', () async {
        final blockedPubkey = 'e' * 64;
        final blockedEvent = MockEvent();
        when(() => blockedEvent.kind).thenReturn(0);
        when(() => blockedEvent.pubkey).thenReturn(blockedPubkey);
        when(() => blockedEvent.createdAt).thenReturn(1704067200);
        when(() => blockedEvent.id).thenReturn('f' * 64);
        when(
          () => blockedEvent.content,
        ).thenReturn(jsonEncode({'name': 'Blocked User'}));

        when(
          () => mockNostrClient.queryUsers('test', limit: 200),
        ).thenAnswer((_) async => [mockProfileEvent, blockedEvent]);

        final filteringRepository = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );

        final result = await filteringRepository.searchUsers(query: 'test');

        expect(result, hasLength(1));
        expect(result.first.pubkey, equals(testPubkey));
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
        'searchUsersFromApi excludes pubkeys hidden by the block filter',
        () async {
          final blockedPubkey = 'e' * 64;
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: blockedPubkey,
                displayName: 'Blocked User',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
              ProfileSearchResult(
                pubkey: 'd' * 64,
                displayName: 'Visible User',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          final filteringRepository = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: (pubkey) => pubkey == blockedPubkey,
          );

          final result = await filteringRepository.searchUsersFromApi(
            query: 'user',
          );

          expect(result, hasLength(1));
          expect(result.first.displayName, 'Visible User');
        },
      );

      test(
        'searchUsersFromApi uses Funnelcake only with server sorting',
        () async {
          // Arrange
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'ga',
              limit: 10,
              offset: any(named: 'offset'),
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [
              ProfileSearchResult(
                pubkey: 'd' * 64,
                displayName: 'GaryVee',
                picture: 'https://example.com/garyvee.jpg',
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
          final result = await repoWithFunnelcake.searchUsersFromApi(
            query: 'ga',
            limit: 10,
            sortBy: 'followers',
          );

          // Assert
          expect(result, hasLength(1));
          expect(result.first.displayName, 'GaryVee');
          expect(result.first.picture, 'https://example.com/garyvee.jpg');
          verify(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'ga',
              limit: 10,
              offset: any(named: 'offset'),
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
            ),
          ).called(1);
          verifyNever(
            () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
          );
        },
      );

      test(
        'searchUsersFromApi returns empty results when Funnelcake fails',
        () async {
          // Arrange
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'ga',
              limit: 10,
              offset: any(named: 'offset'),
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenThrow(Exception('REST API error'));

          final repoWithFunnelcake = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Act
          final result = await repoWithFunnelcake.searchUsersFromApi(
            query: 'ga',
            limit: 10,
            sortBy: 'followers',
          );

          // Assert
          expect(result, isEmpty);
          verify(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'ga',
              limit: 10,
              offset: any(named: 'offset'),
              sortBy: 'followers',
              hasVideos: any(named: 'hasVideos'),
            ),
          ).called(1);
          verifyNever(
            () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
          );
        },
      );

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
          () => mockNostrClient.queryUsers(
            'test',
            limit: 200,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [mockRemoteEvent]);

        // Act
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'test')
            .toList();

        // Assert - at least 2 emissions: local first, then merged
        expect(emissions.length, greaterThanOrEqualTo(2));

        // First emission: local results only
        expect(emissions.first.profiles, hasLength(1));
        expect(emissions.first.profiles.first.pubkey, equals(testPubkey));
        expect(
          emissions.first.sources[SearchSource.localCache],
          isA<SearchSourceSuccess>(),
        );
        expect(
          emissions.first.sources[SearchSource.funnelcakeApi],
          isA<SearchSourcePending>(),
        );
        expect(
          emissions.first.sources[SearchSource.nip50Relay],
          isA<SearchSourcePending>(),
        );
        expect(emissions.first.isComplete, isFalse);

        // Last emission: merged and enriched
        expect(emissions.last.profiles.length, greaterThanOrEqualTo(1));
        expect(emissions.last.isComplete, isTrue);
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
        expect(
          emissions.single.sources[SearchSource.localCache],
          isA<SearchSourceSkipped>(),
        );
        expect(
          emissions.single.sources[SearchSource.nip50Relay],
          isA<SearchSourceSkipped>(),
        );

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
          () => mockNostrClient.queryUsers(
            'test',
            limit: 200,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => [mockProfileEvent]);

        // Act
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'test')
            .toList();

        // Assert - no local emission (empty), just the final one
        expect(emissions, hasLength(1));
        expect(emissions.first.profiles, hasLength(1));
        expect(emissions.first.profiles.first.pubkey, equals(testPubkey));
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
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
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
          expect(emissions.first.profiles, hasLength(1));
          expect(
            emissions.first.profiles.first.displayName,
            equals('Test Cached'),
          );

          // Last emission: merged results
          expect(emissions.last.profiles.length, greaterThanOrEqualTo(1));
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
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
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

          expect(result.profiles, hasLength(1));
          expect(result.profiles.first.pubkey, equals(testPubkey));
          expect(
            result.sources[SearchSource.funnelcakeApi],
            isA<SearchSourceFailed>(),
          );
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
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
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

          expect(result.profiles, hasLength(1));
          expect(result.profiles.first.displayName, equals('Test REST'));
          expect(
            result.sources[SearchSource.nip50Relay],
            isA<SearchSourceFailed>(),
          );
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
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
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
          expect(result.profiles, hasLength(2));
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
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
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
              () => mockNostrClient.queryUsers(
                'alice',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
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
            expect(result.profiles, hasLength(1));
            expect(result.profiles.first.displayName, equals('Alice REST'));
            expect(finalYieldFilterCalled, isFalse);
          },
        );
      });

      group('with boostPubkeys', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        // Three distinct 64-char hex pubkeys.
        final pubA = 'a' * 64;
        final pubB = 'b' * 64;
        final pubC = 'c' * 64;

        ProfileSearchResult restResult(String pubkey, String name) {
          return ProfileSearchResult(
            pubkey: pubkey,
            displayName: name,
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          );
        }

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);
          when(
            () => mockNostrClient.queryUsers(
              any(),
              limit: any(named: 'limit'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => []);
        });

        test(
          'promotes boosted pubkeys to the front on the initial page',
          () async {
            when(
              () => mockFunnelcakeClient.searchProfiles(
                query: 'liz',
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                sortBy: any(named: 'sortBy'),
                hasVideos: any(named: 'hasVideos'),
              ),
            ).thenAnswer(
              (_) async => [
                restResult(pubA, 'Zoe'),
                restResult(pubB, 'Liz'),
                restResult(pubC, 'Maya'),
              ],
            );

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(
                  query: 'liz',
                  sortBy: 'followers',
                  boostPubkeys: {pubB},
                )
                .last;

            expect(
              result.profiles.map((p) => p.displayName).toList(),
              equals(['Liz', 'Zoe', 'Maya']),
            );
          },
        );

        test(
          'preserves server-relative order within each boost group',
          () async {
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
                restResult(pubA, 'A'), // boosted
                restResult(pubB, 'B'), // not boosted
                restResult(pubC, 'C'), // boosted
                restResult('d' * 64, 'D'), // not boosted
              ],
            );

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(
                  query: 'test',
                  sortBy: 'followers',
                  boostPubkeys: {pubA, pubC},
                )
                .last;

            expect(
              result.profiles.map((p) => p.displayName).toList(),
              equals(['A', 'C', 'B', 'D']),
            );
          },
        );

        test('is a no-op when the boost set is empty', () async {
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [restResult(pubA, 'Zoe'), restResult(pubB, 'Maya')],
          );

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo
              .searchUsersProgressive(
                query: 'test',
                sortBy: 'followers',
                boostPubkeys: const <String>{},
              )
              .last;

          expect(
            result.profiles.map((p) => p.displayName).toList(),
            equals(['Zoe', 'Maya']),
          );
        });

        test('is a no-op when boostPubkeys is null', () async {
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [restResult(pubA, 'Zoe'), restResult(pubB, 'Maya')],
          );

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo
              .searchUsersProgressive(query: 'test', sortBy: 'followers')
              .last;

          expect(
            result.profiles.map((p) => p.displayName).toList(),
            equals(['Zoe', 'Maya']),
          );
        });

        test('is a no-op when no result is in the boost set', () async {
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [restResult(pubA, 'Zoe'), restResult(pubB, 'Maya')],
          );

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo
              .searchUsersProgressive(
                query: 'test',
                sortBy: 'followers',
                boostPubkeys: {'f' * 64},
              )
              .last;

          expect(
            result.profiles.map((p) => p.displayName).toList(),
            equals(['Zoe', 'Maya']),
          );
        });
      });

      group('source provenance', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        });

        test('records success on every source when all succeed', () async {
          final cachedProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Cached',
            rawData: const {'display_name': 'Cached'},
            createdAt: DateTime(2026),
            eventId: testEventId,
          );
          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => [cachedProfile]);
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
                displayName: 'REST User',
                createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              ),
            ],
          );

          final wsEvent = MockEvent();
          when(() => wsEvent.kind).thenReturn(0);
          when(() => wsEvent.pubkey).thenReturn('b' * 64);
          when(() => wsEvent.createdAt).thenReturn(1704067200);
          when(() => wsEvent.id).thenReturn('c' * 64);
          when(
            () => wsEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'WS User'}));
          when(
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => [wsEvent]);

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.searchUsersProgressive(query: 'test').last;

          expect(
            result.sources[SearchSource.localCache],
            isA<SearchSourceSuccess>(),
          );
          expect(
            result.sources[SearchSource.funnelcakeApi],
            isA<SearchSourceSuccess>(),
          );
          expect(
            result.sources[SearchSource.nip50Relay],
            isA<SearchSourceSuccess>(),
          );
          expect(result.isComplete, isTrue);
        });

        test(
          'records SearchSourceFailed(other) when local cache throws',
          () async {
            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenThrow(StateError('db down'));
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
            when(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer((_) async => []);

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(query: 'test')
                .last;

            final localStatus = result.sources[SearchSource.localCache];
            expect(localStatus, isA<SearchSourceFailed>());
            expect(
              (localStatus! as SearchSourceFailed).reason,
              SearchSourceFailureReason.other,
            );
          },
        );

        test('records SearchSourceFailed(network) when REST throws', () async {
          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => []);
          when(
            () => mockFunnelcakeClient.searchProfiles(
              query: 'test',
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenThrow(Exception('connection refused'));
          when(
            () => mockNostrClient.queryUsers(
              'test',
              limit: 200,
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => []);

          final repo = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repo.searchUsersProgressive(query: 'test').last;

          final apiStatus = result.sources[SearchSource.funnelcakeApi];
          expect(apiStatus, isA<SearchSourceFailed>());
          expect(
            (apiStatus! as SearchSourceFailed).reason,
            SearchSourceFailureReason.network,
          );
        });

        test(
          'records SearchSourceFailed(timeout) when NIP-50 times out',
          () async {
            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenAnswer((_) async => []);
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
            when(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer((_) async {
              // Sleep past the 5 s NIP-50 timeout so .timeout() fires.
              await Future<void>.delayed(const Duration(seconds: 6));
              return <Event>[];
            });

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(query: 'test')
                .last;

            final relayStatus = result.sources[SearchSource.nip50Relay];
            expect(relayStatus, isA<SearchSourceFailed>());
            expect(
              (relayStatus! as SearchSourceFailed).reason,
              SearchSourceFailureReason.timeout,
            );
            verify(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: const Duration(milliseconds: 4500),
              ),
            ).called(1);
          },
          timeout: const Timeout(Duration(seconds: 10)),
        );

        test(
          'records failures across all sources when everything fails',
          () async {
            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenAnswer((_) async => []);
            when(
              () => mockFunnelcakeClient.searchProfiles(
                query: 'test',
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
                sortBy: any(named: 'sortBy'),
                hasVideos: any(named: 'hasVideos'),
              ),
            ).thenThrow(Exception('REST down'));
            when(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
            ).thenThrow(StateError('WS down'));

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(query: 'test')
                .last;

            expect(result.profiles, isEmpty);
            expect(
              result.sources[SearchSource.localCache],
              isA<SearchSourceSuccess>(), // empty local is still "success"
            );
            expect(
              result.sources[SearchSource.funnelcakeApi],
              isA<SearchSourceFailed>(),
            );
            expect(
              result.sources[SearchSource.nip50Relay],
              isA<SearchSourceFailed>(),
            );
            expect(result.isComplete, isTrue);
          },
        );

        test(
          'records SearchSourceSkipped for funnelcake when unavailable',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
            when(
              () => mockUserProfilesDao.getAllProfiles(),
            ).thenAnswer((_) async => []);
            when(
              () => mockNostrClient.queryUsers(
                'test',
                limit: 200,
                timeout: any(named: 'timeout'),
              ),
            ).thenAnswer((_) async => []);

            final repo = ProfileRepository(
              nostrClient: mockNostrClient,
              userProfilesDao: mockUserProfilesDao,
              httpClient: mockHttpClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final result = await repo
                .searchUsersProgressive(query: 'test')
                .last;

            expect(
              result.sources[SearchSource.funnelcakeApi],
              isA<SearchSourceSkipped>(),
            );
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

      test('NoRelaysConnectedException has message and toString', () {
        const e = NoRelaysConnectedException('no relays');

        expect(e.message, equals('no relays'));
        expect(e.toString(), equals('NoRelaysConnectedException: no relays'));
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

      test(
        'returns validation error for too-short username before request',
        () async {
          final result = await profileRepository.claimUsername(username: 'ab');

          expect(
            result,
            isA<UsernameClaimError>().having(
              (e) => e.message,
              'message',
              'Usernames must be 3–63 characters',
            ),
          );
          verifyNever(
            () => mockNostrClient.createNip98AuthHeader(
              url: any(named: 'url'),
              method: any(named: 'method'),
              payload: any(named: 'payload'),
            ),
          );
          verifyNever(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          );
        },
      );

      test('returns server error message when claim returns 400 '
          'with JSON error body', () async {
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
          (_) => Future.value(
            Response('{"error": "Name server rejected claim"}', 400),
          ),
        );

        final result = await profileRepository.claimUsername(
          username: 'validuser',
        );

        expect(
          result,
          isA<UsernameClaimError>().having(
            (e) => e.message,
            'message',
            'Name server rejected claim',
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

      test('returns UsernameClaimError when the POST exceeds the timeout', () {
        fakeAsync((async) {
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
          ).thenAnswer((_) async {
            // Simulates an unresponsive name server: never resolves within
            // the repository's _nameServerHttpTimeout (10s).
            await Future<void>.delayed(const Duration(minutes: 5));
            return Response('unused', 200);
          });

          UsernameClaimResult? result;
          unawaited(
            profileRepository
                .claimUsername(username: 'username')
                .then((r) => result = r),
          );

          // Below the 10s repository timeout — call still pending.
          async
            ..elapse(const Duration(seconds: 9))
            ..flushMicrotasks();
          expect(result, isNull);

          // Crosses the 10s repository timeout.
          async
            ..elapse(const Duration(seconds: 2))
            ..flushMicrotasks();
          expect(
            result,
            isA<UsernameClaimError>().having(
              (e) => e.message,
              'message',
              contains('TimeoutException'),
            ),
          );
        });
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

      test('returns UsernameInvalidFormat for too-short names', () async {
        final result = await profileRepository.checkUsernameAvailability(
          username: 'ab',
        );

        expect(
          result,
          isA<UsernameInvalidFormat>().having(
            (e) => e.reason,
            'reason',
            'Usernames must be 3–63 characters',
          ),
        );
        verifyNever(
          () => mockHttpClient.get(
            Uri.parse('https://names.divine.video/api/username/check/ab'),
          ),
        );
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

      test('returns UsernameCheckError when the GET exceeds the timeout', () {
        fakeAsync((async) {
          when(
            () => mockHttpClient.get(
              Uri.parse(
                'https://names.divine.video/api/username/check/testuser',
              ),
            ),
          ).thenAnswer((_) async {
            // Simulates an unresponsive name server: never resolves within
            // the repository's _nameServerHttpTimeout (10s).
            await Future<void>.delayed(const Duration(minutes: 5));
            return Response('unused', 200);
          });

          UsernameAvailabilityResult? result;
          unawaited(
            profileRepository
                .checkUsernameAvailability(username: 'testuser')
                .then((r) => result = r),
          );

          async
            ..elapse(const Duration(seconds: 9))
            ..flushMicrotasks();
          expect(result, isNull);

          async
            ..elapse(const Duration(seconds: 2))
            ..flushMicrotasks();
          expect(
            result,
            isA<UsernameCheckError>().having(
              (e) => e.message,
              'message',
              contains('TimeoutException'),
            ),
          );
        });
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

      test('returns UserProfileFound on success', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getUserProfile(testPubkey)).thenAnswer(
          (_) async => UserProfileFound(
            profile: UserProfileData.fromJson(testPubkey, const {
              'display_name': 'Test User',
              'picture': 'https://example.com/avatar.png',
            }),
          ),
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

        expect(result, isA<UserProfileFound>());
        expect(
          (result! as UserProfileFound).profile.displayName,
          equals('Test User'),
        );
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
        final testResponse = BulkProfilesResponse(
          profiles: {
            testPubkey: UserProfileFound(
              profile: UserProfileData.fromJson(testPubkey, const {
                'display_name': 'Test User',
                'picture': 'https://example.com/avatar.png',
              }),
            ),
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
        verifyNever(() => mockFunnelcakeClient.getSocialCounts(testPubkey));
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(() => mockFunnelcakeClient.getSocialCounts(any())).thenThrow(
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
          (_) async => BulkProfilesResponse(
            profiles: {
              testPubkey: UserProfileFound(
                profile: UserProfileData.fromJson(testPubkey, const {
                  'display_name': 'API User',
                  'picture': 'https://example.com/pic.jpg',
                }),
              ),
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
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
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
          (_) async => BulkProfilesResponse(
            profiles: {
              testPubkey2: UserProfileFound(
                profile: UserProfileData.fromJson(testPubkey2, const {
                  'display_name': 'API User',
                }),
              ),
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
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
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
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => <Event>[]);
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

      test(
        'handles uncaught relay Error gracefully with partial results',
        () async {
          final relayEvent = MockEvent();
          when(() => relayEvent.kind).thenReturn(0);
          when(() => relayEvent.pubkey).thenReturn(testPubkey2);
          when(() => relayEvent.createdAt).thenReturn(1704067200);
          when(() => relayEvent.id).thenReturn('relay_$testEventId');
          when(
            () => relayEvent.content,
          ).thenReturn(jsonEncode({'display_name': 'Relay User'}));

          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenThrow(StateError('Relay crashed'));
          when(
            () => mockNostrClient.fetchProfile(testPubkey2),
          ).thenAnswer((_) async => relayEvent);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);
          when(
            () => mockUserProfilesDao.upsertProfiles(any()),
          ).thenAnswer((_) async {});

          final result = await profileRepository.fetchBatchProfiles(
            pubkeys: [testPubkey, testPubkey2],
          );

          expect(result, hasLength(1));
          expect(result[testPubkey2]?.displayName, equals('Relay User'));
        },
      );

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
        'skips relay fallback for UserProfileNotPublished entries',
        () async {
          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
            (_) async => const BulkProfilesResponse(
              profiles: {
                testPubkey: UserProfileNotPublished(pubkey: testPubkey),
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
          verifyNever(() => mockUserProfilesDao.upsertProfiles(any()));
        },
      );

      test(
        'processes real profiles alongside UserProfileNotPublished entries',
        () async {
          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(() => mockFunnelcakeClient.getBulkProfiles(any())).thenAnswer(
            (_) async => BulkProfilesResponse(
              profiles: {
                testPubkey: UserProfileFound(
                  profile: UserProfileData.fromJson(testPubkey, const {
                    'display_name': 'Real User',
                  }),
                ),
                testPubkey2: const UserProfileNotPublished(pubkey: testPubkey2),
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
          expect(result[testPubkey]?.displayName, equals('Real User'));
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

      test('picks newest profile per pubkey across sources', () async {
        // Connected relay returns older profile
        final olderEvent = MockEvent();
        when(() => olderEvent.kind).thenReturn(0);
        when(() => olderEvent.pubkey).thenReturn(testPubkey);
        when(() => olderEvent.createdAt).thenReturn(1704067200);
        when(() => olderEvent.id).thenReturn(testEventId);
        when(
          () => olderEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'Old Name'}));

        // Indexer returns newer profile for same pubkey
        final newerEvent = MockEvent();
        when(() => newerEvent.kind).thenReturn(0);
        when(() => newerEvent.pubkey).thenReturn(testPubkey);
        when(() => newerEvent.createdAt).thenReturn(1704153600);
        when(() => newerEvent.id).thenReturn('newer_$testEventId');
        when(
          () => newerEvent.content,
        ).thenReturn(jsonEncode({'display_name': 'New Name'}));

        when(
          () => mockUserProfilesDao.getProfilesByPubkeys(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => olderEvent);
        when(
          () => mockNostrClient.queryEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [newerEvent]);
        when(
          () => mockUserProfilesDao.upsertProfiles(any()),
        ).thenAnswer((_) async {});

        final result = await profileRepository.fetchBatchProfiles(
          pubkeys: [testPubkey],
        );

        expect(result, hasLength(1));
        expect(result[testPubkey]?.displayName, equals('New Name'));
      });
    });

    group('block filter', () {
      const blockedPubkey =
          'dddddddddddddddddddddddddddddddd'
          'dddddddddddddddddddddddddddddddd';

      test(
        'filters blocked users from searchUsersProgressive results',
        () async {
          final blockedProfile = UserProfile(
            pubkey: blockedPubkey,
            displayName: 'Blocked User',
            rawData: const {'display_name': 'Blocked User'},
            createdAt: DateTime(2026),
            eventId: 'evt_blocked',
          );
          final allowedProfile = UserProfile(
            pubkey: testPubkey,
            displayName: 'Allowed User',
            rawData: const {'display_name': 'Allowed User'},
            createdAt: DateTime(2026),
            eventId: testEventId,
          );

          when(
            () => mockUserProfilesDao.getAllProfiles(),
          ).thenAnswer((_) async => [blockedProfile, allowedProfile]);

          when(
            () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
          ).thenAnswer((_) async => []);

          final repoWithBlockFilter = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            blockFilter: (pubkey) => pubkey == blockedPubkey,
          );

          final emissions = await repoWithBlockFilter
              .searchUsersProgressive(query: 'user')
              .toList();

          // Every emission should exclude the blocked profile.
          for (final result in emissions) {
            expect(
              result.profiles.map((p) => p.pubkey),
              isNot(contains(blockedPubkey)),
            );
          }

          // The allowed profile should be present in the last emission.
          expect(emissions.last.profiles, hasLength(1));
          expect(emissions.last.profiles.first.pubkey, equals(testPubkey));
        },
      );

      test('returns all profiles when blockFilter is null', () async {
        final profile1 = UserProfile(
          pubkey: blockedPubkey,
          displayName: 'User One',
          rawData: const {'display_name': 'User One'},
          createdAt: DateTime(2026),
          eventId: 'evt_one',
        );
        final profile2 = UserProfile(
          pubkey: testPubkey,
          displayName: 'User Two',
          rawData: const {'display_name': 'User Two'},
          createdAt: DateTime(2026),
          eventId: testEventId,
        );

        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [profile1, profile2]);

        when(
          () => mockNostrClient.queryUsers(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) async => []);

        // Default profileRepository has no blockFilter.
        final emissions = await profileRepository
            .searchUsersProgressive(query: 'user')
            .toList();

        expect(emissions.last.profiles, hasLength(2));
      });

      test('filters blocked users from searchUsersLocally results', () async {
        const blockedPubkey =
            'dddddddddddddddddddddddddddddddd'
            'dddddddddddddddddddddddddddddddd';
        final blockedProfile = UserProfile(
          pubkey: blockedPubkey,
          displayName: 'Blocked User',
          rawData: const {'display_name': 'Blocked User'},
          createdAt: DateTime(2026),
          eventId: 'evt_blocked_local',
        );
        final allowedProfile = UserProfile(
          pubkey: testPubkey,
          displayName: 'Allowed User',
          rawData: const {'display_name': 'Allowed User'},
          createdAt: DateTime(2026),
          eventId: testEventId,
        );

        when(
          () => mockUserProfilesDao.getAllProfiles(),
        ).thenAnswer((_) async => [blockedProfile, allowedProfile]);

        final repoWithBlockFilter = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );

        final result = await repoWithBlockFilter.searchUsersLocally(
          query: 'user',
        );

        expect(result.map((p) => p.pubkey), isNot(contains(blockedPubkey)));
        expect(result, hasLength(1));
        expect(result.first.pubkey, equals(testPubkey));
      });

      test('fetchFreshProfile returns null for a blocked pubkey', () async {
        const blockedPubkey =
            'dddddddddddddddddddddddddddddddd'
            'dddddddddddddddddddddddddddddddd';

        final repoWithBlockFilter = ProfileRepository(
          nostrClient: mockNostrClient,
          userProfilesDao: mockUserProfilesDao,
          httpClient: mockHttpClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );

        final result = await repoWithBlockFilter.fetchFreshProfile(
          pubkey: blockedPubkey,
        );

        expect(result, isNull);
        verifyNever(() => mockNostrClient.fetchProfile(any()));
      });

      test(
        'fetchBatchProfiles excludes blocked pubkeys from map result',
        () async {
          const blockedPubkey =
              'dddddddddddddddddddddddddddddddd'
              'dddddddddddddddddddddddddddddddd';

          final blockedEvent = MockEvent();
          when(() => blockedEvent.kind).thenReturn(0);
          when(() => blockedEvent.pubkey).thenReturn(blockedPubkey);
          when(() => blockedEvent.createdAt).thenReturn(1704067200);
          when(() => blockedEvent.id).thenReturn(
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          );
          when(
            () => blockedEvent.content,
          ).thenReturn('{"display_name":"Blocked Batch User"}');

          when(
            () => mockUserProfilesDao.getProfilesByPubkeys(any()),
          ).thenAnswer((_) async => []);

          when(
            () => mockNostrClient.fetchProfile(blockedPubkey),
          ).thenAnswer((_) async => blockedEvent);
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => mockProfileEvent);

          when(
            () => mockUserProfilesDao.upsertProfiles(any()),
          ).thenAnswer((_) async {});

          final repoWithBlockFilter = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            blockFilter: (pubkey) => pubkey == blockedPubkey,
          );

          final result = await repoWithBlockFilter.fetchBatchProfiles(
            pubkeys: [blockedPubkey, testPubkey],
          );

          expect(result.containsKey(blockedPubkey), isFalse);
          expect(result.containsKey(testPubkey), isTrue);
        },
      );
    });
  });
}

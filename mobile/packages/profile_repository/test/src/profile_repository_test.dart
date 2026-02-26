import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockEvent extends Mock implements Event {}

class MockUserProfilesDao extends Mock implements UserProfilesDao {}

class MockHttpClient extends Mock implements Client {}

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

    group('fetchFreshProfile', () {
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

      test('returns null when relay returns no profile', () async {
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);

        final result = await profileRepository.fetchFreshProfile(
          pubkey: testPubkey,
        );

        expect(result, isNull);

        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
      });
    });

    group('saveProfileEvent', () {
      test(
        'sends all provided fields to nostrClient and caches and returns '
        'user profile',
        () async {
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
        },
      );

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
          jsonEncode({
            'display_name': 'Test',
            'nip05': 'alice@example.com',
          }),
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
          jsonEncode({
            'display_name': 'Test',
            'nip05': 'alice@example.com',
          }),
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
          jsonEncode({
            'display_name': 'Test User',
            'banner': '0x33ccbf',
          }),
        );

        await profileRepository.saveProfileEvent(
          displayName: 'Test User',
          banner: '0x33ccbf',
        );

        verify(
          () => mockNostrClient.sendProfile(
            profileContent: {
              'display_name': 'Test User',
              'banner': '0x33ccbf',
            },
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

      test(
        'returns empty list when NostrClient returns empty list',
        () async {
          // Arrange
          when(
            () => mockNostrClient.queryUsers('unknown', limit: 200),
          ).thenAnswer((_) async => []);

          // Act
          final result = await profileRepository.searchUsers(query: 'unknown');

          // Assert
          expect(result, isEmpty);
        },
      );

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
          ).thenAnswer(
            (_) async => [mockProfileEvent1, mockProfileEvent2],
          );

          // Act
          final result = await profileRepository.searchUsers(query: 'alice');

          // Assert
          expect(result, hasLength(2));
          expect(result[0].displayName, equals('Alice Wonder'));
          expect(result[1].displayName, equals('Alice Smith'));
        },
      );

      test(
        'filters out blocked users when userBlockFilter is provided',
        () async {
          // Arrange
          final mockProfileEvent1 = MockEvent();
          final mockProfileEvent2 = MockEvent();
          const blockedPubkey =
              'blocked1e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
              'c3d4e5f6a1b2c3d4e5f6a1b2';
          const allowedPubkey =
              'allowed2e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2'
              'c3d4e5f6a1b2c3d4e5f6a1b2';
          const testEventId1 =
              'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
              'd3c4b5a6f1e2d3c4b5a6f1e2';
          const testEventId2 =
              'e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2'
              'd3c4b5a6f1e2d3c4b5a6f1e2d3';

          when(() => mockProfileEvent1.kind).thenReturn(0);
          when(() => mockProfileEvent1.pubkey).thenReturn(blockedPubkey);
          when(() => mockProfileEvent1.createdAt).thenReturn(1704067200);
          when(() => mockProfileEvent1.id).thenReturn(testEventId1);
          when(() => mockProfileEvent1.content).thenReturn(
            jsonEncode({
              'display_name': 'Alice Blocked',
              'about': 'A blocked user',
            }),
          );

          when(() => mockProfileEvent2.kind).thenReturn(0);
          when(() => mockProfileEvent2.pubkey).thenReturn(allowedPubkey);
          when(() => mockProfileEvent2.createdAt).thenReturn(1704067300);
          when(() => mockProfileEvent2.id).thenReturn(testEventId2);
          when(() => mockProfileEvent2.content).thenReturn(
            jsonEncode({
              'display_name': 'Alice Allowed',
              'about': 'An allowed user',
            }),
          );

          when(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).thenAnswer(
            (_) async => [mockProfileEvent1, mockProfileEvent2],
          );

          // Create repository with block filter
          final repoWithFilter = ProfileRepository(
            nostrClient: mockNostrClient,
            userProfilesDao: mockUserProfilesDao,
            httpClient: mockHttpClient,
            userBlockFilter: (pubkey) => pubkey == blockedPubkey,
          );

          // Act
          final result = await repoWithFilter.searchUsers(query: 'alice');

          // Assert
          expect(result, hasLength(1));
          expect(result.first.displayName, equals('Alice Allowed'));
          expect(result.any((p) => p.pubkey == blockedPubkey), isFalse);
        },
      );

      test(
        'enriches profiles missing picture from local cache',
        () async {
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
          when(() => mockSearchEvent.content).thenReturn(
            jsonEncode({'display_name': 'Alice'}),
          );

          when(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).thenAnswer((_) async => [mockSearchEvent]);

          // Cache has a profile with a picture
          when(
            () => mockUserProfilesDao.getProfile(searchPubkey),
          ).thenAnswer(
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
        },
      );

      test(
        'does not overwrite existing picture with cached version',
        () async {
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
          when(
            () => mockUserProfilesDao.getProfile(searchPubkey),
          ).thenAnswer(
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
          expect(
            result.first.picture,
            equals('https://example.com/fresh.png'),
          );
        },
      );

      test(
        'enriches multiple null fields from cache',
        () async {
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
          when(() => mockSearchEvent.content).thenReturn(
            jsonEncode({'display_name': 'Alice'}),
          );

          when(
            () => mockNostrClient.queryUsers('alice', limit: 200),
          ).thenAnswer((_) async => [mockSearchEvent]);

          // Cache has complete profile
          when(
            () => mockUserProfilesDao.getProfile(searchPubkey),
          ).thenAnswer(
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
        },
      );

      test(
        'uses profileSearchFilter when provided',
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
              'display_name': 'Bob Smith',
              'about': 'First user',
            }),
          );

          when(() => mockProfileEvent2.kind).thenReturn(0);
          when(() => mockProfileEvent2.pubkey).thenReturn(testPubkey2);
          when(() => mockProfileEvent2.createdAt).thenReturn(1704067300);
          when(() => mockProfileEvent2.id).thenReturn(testEventId2);
          when(() => mockProfileEvent2.content).thenReturn(
            jsonEncode({
              'display_name': 'Alice Jones',
              'about': 'Second user',
            }),
          );

          when(
            () => mockNostrClient.queryUsers('test', limit: 200),
          ).thenAnswer(
            (_) async => [mockProfileEvent1, mockProfileEvent2],
          );

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
        },
      );
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
          when(() => mockWsEvent.content).thenReturn(
            jsonEncode({'display_name': 'Alice WS'}),
          );

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
        when(() => mockWsEvent.content).thenReturn(
          jsonEncode({'display_name': 'Alice WS'}),
        );

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

      test(
        'skips WebSocket on paginated request (offset > 0)',
        () async {
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
            () => mockNostrClient.queryUsers(
              any(),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      test(
        'skips client-side filter when sortBy is set',
        () async {
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
        },
      );
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

      test(
        'returns server error message when server returns '
        'non-200 with JSON error body',
        () async {
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
              Response('{"error": "Username too short"}', 400),
            ),
          );

          final result = await profileRepository.claimUsername(
            username: 'ab',
          );

          expect(
            result,
            isA<UsernameClaimError>().having(
              (e) => e.message,
              'message',
              'Username too short',
            ),
          );
        },
      );

      test(
        'returns error with default message when server returns '
        'non-200 with unparseable body',
        () async {
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
            (_) => Future.value(Response('not json at all', 400)),
          );

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
        },
      );
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
            Uri.parse(
              'https://names.divine.video/api/username/check/testuser',
            ),
          ),
        ).thenAnswer(
          (_) async => Response('Server error', 500),
        );

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
            Uri.parse(
              'https://names.divine.video/api/username/check/testuser',
            ),
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
            Uri.parse(
              'https://names.divine.video/api/username/check/alice',
            ),
          ),
        ).called(1);
      });

      test('returns UsernameInvalidFormat with server reason for '
          'validation failures', () async {
        stubNameServerCheck(
          'bad',
          available: false,
          reason: 'Username contains invalid characters',
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'bad',
        );

        expect(
          result,
          isA<UsernameInvalidFormat>().having(
            (e) => e.reason,
            'reason',
            'Username contains invalid characters',
          ),
        );
      });

      test('returns UsernameInvalidFormat for hyphen reason', () async {
        stubNameServerCheck(
          'ok',
          available: false,
          reason: 'Cannot start with hyphen',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'ok',
        );
        expect(result, isA<UsernameInvalidFormat>());
      });

      test('returns UsernameInvalidFormat for emoji reason', () async {
        stubNameServerCheck(
          'ok',
          available: false,
          reason: 'Username contains emoji',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'ok',
        );
        expect(result, isA<UsernameInvalidFormat>());
      });

      test('returns UsernameInvalidFormat for DNS reason', () async {
        stubNameServerCheck(
          'ok',
          available: false,
          reason: 'Not a valid DNS label',
        );
        final result = await profileRepository.checkUsernameAvailability(
          username: 'ok',
        );
        expect(result, isA<UsernameInvalidFormat>());
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
        when(
          () => mockFunnelcakeClient.getUserProfile(testPubkey),
        ).thenAnswer(
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
        when(
          () => mockFunnelcakeClient.getUserProfile(any()),
        ).thenThrow(
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

        final result = await repoWithFunnelcake.getBulkProfilesFromApi(
          [testPubkey],
        );

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

        final result = await repoWithFunnelcake.getBulkProfilesFromApi(
          [testPubkey],
        );

        expect(result, isNull);
        verifyNever(() => mockFunnelcakeClient.getBulkProfiles(any()));
      });

      test('returns null when client is null', () async {
        final result = await profileRepository.getBulkProfilesFromApi(
          [testPubkey],
        );

        expect(result, isNull);
      });

      test('propagates FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkProfiles(any()),
        ).thenThrow(
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
  });
}

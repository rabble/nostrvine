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
      return (await profileRepository.getProfile(pubkey: testPubkey))!;
    }

    group('getProfile', () {
      test('returns and caches UserProfile on cache miss and when fetchProfile '
          'returns an event', () async {
        final result = await profileRepository.getProfile(pubkey: testPubkey);

        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.displayName, equals('Test User'));
        expect(result.about, equals('A test bio'));

        verify(() => mockUserProfilesDao.getProfile(any())).called(1);
        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
        verify(() => mockUserProfilesDao.upsertProfile(result)).called(1);
      });

      test('returns cached profile on cache hit', () async {
        final profile = UserProfile.fromNostrEvent(mockProfileEvent);
        when(
          () => mockUserProfilesDao.getProfile(any()),
        ).thenAnswer((_) async => profile);

        final result = await profileRepository.getProfile(pubkey: testPubkey);

        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.displayName, equals('Test User'));
        expect(result.about, equals('A test bio'));

        verify(() => mockUserProfilesDao.getProfile(any())).called(1);
        verifyNever(() => mockNostrClient.fetchProfile(any()));
        verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
      });

      test(
        'returns null on cache miss and when fetchProfile returns null',
        () async {
          when(
            () => mockNostrClient.fetchProfile(testPubkey),
          ).thenAnswer((_) async => null);

          final result = await profileRepository.getProfile(pubkey: testPubkey);

          expect(result, isNull);

          verify(() => mockUserProfilesDao.getProfile(any())).called(1);
          verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
          verifyNever(() => mockUserProfilesDao.upsertProfile(any()));
        },
      );
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
              'nip05': 'new@example.com',
              'picture': 'https://example.com/new.png',
            }),
          );

          final profile = await profileRepository.saveProfileEvent(
            displayName: 'New Name',
            about: 'New bio',
            nip05: 'new@example.com',
            picture: 'https://example.com/new.png',
          );

          expect(profile.displayName, equals('New Name'));
          expect(profile.about, equals('New bio'));
          expect(profile.nip05, equals('new@example.com'));
          expect(profile.picture, equals('https://example.com/new.png'));

          verify(
            () => mockNostrClient.sendProfile(
              profileContent: {
                'display_name': 'New Name',
                'about': 'New bio',
                'nip05': 'new@example.com',
                'picture': 'https://example.com/new.png',
              },
            ),
          ).called(1);
          verify(() => mockUserProfilesDao.upsertProfile(profile)).called(1);
        },
      );

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
            nip05: 'new@example.com',
            about: 'New bio',
            currentProfile: currentProfile,
          );

          verify(
            () => mockNostrClient.sendProfile(
              profileContent: {
                'display_name': 'New Name',
                'nip05': 'new@example.com',
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
              limit: 200,
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
            () =>
                mockFunnelcakeClient.searchProfiles(query: 'alice', limit: 200),
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
            limit: 200,
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
            limit: 200,
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
    });

    group('UsernameClaimResult', () {
      test('UsernameClaimError toString returns formatted message', () {
        const error = UsernameClaimError('test error');
        expect(error.toString(), equals('UsernameClaimError(test error)'));
      });
    });

    group('checkUsernameAvailability', () {
      test('returns UsernameAvailable when username not in '
          'names map', () async {
        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'names': {'existinguser': 'pubkey123'},
            }),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'newuser',
        );

        expect(result, equals(const UsernameAvailable()));

        verify(
          () => mockHttpClient.get(
            Uri.parse(
              'https://divine.video/.well-known/nostr.json?name=newuser',
            ),
          ),
        ).called(1);
      });

      test('returns UsernameAvailable when names map is null', () async {
        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({'relays': <String, dynamic>{}}),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'testuser',
        );

        expect(result, equals(const UsernameAvailable()));

        verify(
          () => mockHttpClient.get(
            Uri.parse(
              'https://divine.video/.well-known/nostr.json?name=testuser',
            ),
          ),
        ).called(1);
      });

      test('returns UsernameAvailable when names map is empty', () async {
        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({'names': <String, dynamic>{}}),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'testuser',
        );

        expect(result, equals(const UsernameAvailable()));

        verify(
          () => mockHttpClient.get(
            Uri.parse(
              'https://divine.video/.well-known/nostr.json?name=testuser',
            ),
          ),
        ).called(1);
      });

      test('returns UsernameTaken when username exists in names map', () async {
        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer(
          (_) async => Response(
            jsonEncode({
              'names': {
                'alice': 'pubkey1',
                'bob': 'pubkey2',
                'takenuser': 'pubkey3',
              },
            }),
            200,
          ),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'takenuser',
        );

        expect(result, equals(const UsernameTaken()));

        verify(
          () => mockHttpClient.get(
            Uri.parse(
              'https://divine.video/.well-known/nostr.json?name=takenuser',
            ),
          ),
        ).called(1);
      });

      test('returns UsernameCheckError when HTTP status is not 200', () async {
        when(
          () => mockHttpClient.get(any()),
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

        verify(
          () => mockHttpClient.get(
            Uri.parse(
              'https://divine.video/.well-known/nostr.json?name=testuser',
            ),
          ),
        ).called(1);
      });

      test('returns UsernameCheckError on network exception', () async {
        when(
          () => mockHttpClient.get(any()),
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

        verify(
          () => mockHttpClient.get(
            Uri.parse(
              'https://divine.video/.well-known/nostr.json?name=testuser',
            ),
          ),
        ).called(1);
      });

      test('returns UsernameCheckError on JSON parsing error', () async {
        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer(
          (_) async => Response('invalid json', 200),
        );

        final result = await profileRepository.checkUsernameAvailability(
          username: 'testuser',
        );

        expect(
          result,
          isA<UsernameCheckError>().having(
            (e) => e.message,
            'message',
            contains('Network error'),
          ),
        );

        verify(
          () => mockHttpClient.get(
            Uri.parse(
              'https://divine.video/.well-known/nostr.json?name=testuser',
            ),
          ),
        ).called(1);
      });
    });

    group('UsernameAvailabilityResult', () {
      test('UsernameCheckError toString returns formatted message', () {
        const error = UsernameCheckError('test error');
        expect(error.toString(), equals('UsernameCheckError(test error)'));
      });
    });
  });
}

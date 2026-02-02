import 'dart:convert';

import 'package:db_client/db_client.dart';
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
  });
}

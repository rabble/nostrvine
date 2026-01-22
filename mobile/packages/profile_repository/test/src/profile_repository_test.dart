import 'dart:convert';

import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockEvent extends Mock implements Event {}

class MockHttpClient extends Mock implements Client {}

void main() {
  group('ProfileRepository', () {
    late MockNostrClient mockNostrClient;
    late ProfileRepository repository;
    late MockEvent mockProfileEvent;
    late MockHttpClient mockHttpClient;

    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testEventId =
        'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';

    setUpAll(() {
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(Uri.parse('https://example.com'));
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockProfileEvent = MockEvent();
      mockHttpClient = MockHttpClient();
      repository = ProfileRepository(
        nostrClient: mockNostrClient,
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
    });

    /// Helper to create a current profile with given content
    Future<UserProfile> createCurrentProfile(
      Map<String, dynamic> content,
    ) async {
      when(() => mockProfileEvent.content).thenReturn(jsonEncode(content));
      return (await repository.getProfile(pubkey: testPubkey))!;
    }

    group('getProfile', () {
      test('returns UserProfile when fetchProfile returns an event', () async {
        // Act
        final result = await repository.getProfile(pubkey: testPubkey);

        // Assert
        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.displayName, equals('Test User'));
        expect(result.about, equals('A test bio'));

        // Verify
        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
      });

      test('returns null when fetchProfile returns null', () async {
        // Arrange
        when(
          () => mockNostrClient.fetchProfile(testPubkey),
        ).thenAnswer((_) async => null);

        // Act
        final result = await repository.getProfile(pubkey: testPubkey);

        // Assert
        expect(result, isNull);

        // Verify
        verify(() => mockNostrClient.fetchProfile(testPubkey)).called(1);
      });
    });

    group('saveProfileEvent', () {
      test('sends all provided fields to nostrClient', () async {
        // Act
        await repository.saveProfileEvent(
          displayName: 'New Name',
          about: 'New bio',
          nip05: 'new@example.com',
          picture: 'https://example.com/new.png',
        );

        // Verify
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
      });

      test('omits null optional fields', () async {
        // Act
        await repository.saveProfileEvent(displayName: 'Only Name');

        // Verify
        verify(
          () => mockNostrClient.sendProfile(
            profileContent: {'display_name': 'Only Name'},
          ),
        ).called(1);
      });

      test(
        'throws ProfilePublishFailedException when sendProfile fails',
        () async {
          // Arrange
          when(
            () => mockNostrClient.sendProfile(
              profileContent: any(named: 'profileContent'),
            ),
          ).thenAnswer((_) async => null);

          // Act & Assert
          await expectLater(
            repository.saveProfileEvent(displayName: 'Test'),
            throwsA(isA<ProfilePublishFailedException>()),
          );
        },
      );

      group('with currentProfile', () {
        test('preserves unrelated fields from currentProfile', () async {
          // Arrange
          final currentProfile = await createCurrentProfile({
            'display_name': 'Old Name',
            'website': 'https://old.com',
            'lud16': 'user@wallet.com',
            'custom_field': 'preserved',
          });

          // Act
          await repository.saveProfileEvent(
            displayName: 'New Name',
            currentProfile: currentProfile,
          );

          // Verify
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
          // Arrange
          final currentProfile = await createCurrentProfile({
            'display_name': 'Old Name',
            'nip05': 'old@example.com',
            'about': 'Old bio',
          });

          // Act
          await repository.saveProfileEvent(
            displayName: 'New Name',
            nip05: 'new@example.com',
            about: 'New bio',
            currentProfile: currentProfile,
          );

          // Verify
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
            // Arrange
            final currentProfile = await createCurrentProfile({
              'display_name': 'Old Name',
              'about': 'Preserved bio',
            });

            // Act
            await repository.saveProfileEvent(
              displayName: 'New Name',
              currentProfile: currentProfile,
            );

            // Verify
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

        final usernameClaimResult = await repository.claimUsername(
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

        final usernameClaimResult = await repository.claimUsername(
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

        final usernameClaimResult = await repository.claimUsername(
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

        final usernameClaimResult = await repository.claimUsername(
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

        final usernameClaimResult = await repository.claimUsername(
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

        final usernameClaimResult = await repository.claimUsername(
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

          final usernameClaimResult = await repository.claimUsername(
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

// ABOUTME: Unit tests for NIP-05 username registration service
// ABOUTME: Tests username validation, availability checking, and registration flow

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/nip05_service.dart';

@GenerateMocks([http.Client, NostrClient])
import 'nip05_service_test.mocks.dart';

void main() {
  group('Nip05Service', () {
    late Nip05Service service;
    late MockClient mockClient;
    late MockNostrClient mockNostrClient;

    setUp(() {
      mockClient = MockClient();
      mockNostrClient = MockNostrClient();
      // Stub connectedRelays getter
      when(
        mockNostrClient.connectedRelays,
      ).thenReturn(['wss://relay1.com', 'wss://relay2.com']);
      service = Nip05Service(
        httpClient: mockClient,
        nostrClient: mockNostrClient,
      );
    });

    group('checkUsernameAvailability', () {
      test('returns true when username is available', () async {
        // Arrange
        const username = 'testuser';
        when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response(jsonEncode({'names': {}}), 200),
        );

        // Act
        final result = await service.checkUsernameAvailability(username);

        // Assert
        expect(result, true);
      });

      test('returns false when username is taken', () async {
        // Arrange
        const username = 'taken';
        when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'names': {'taken': 'pubkey123'},
            }),
            200,
          ),
        );

        // Act
        final result = await service.checkUsernameAvailability(username);

        // Assert
        expect(result, false);
      });

      test('returns false for invalid username format', () async {
        // Test invalid usernames (no network call needed)
        expect(await service.checkUsernameAvailability(''), false);
        expect(
          await service.checkUsernameAvailability('a'),
          false,
        ); // too short
        expect(
          await service.checkUsernameAvailability('user name'),
          false,
        ); // contains space
        expect(
          await service.checkUsernameAvailability('user@name'),
          false,
        ); // invalid char
        expect(
          await service.checkUsernameAvailability('aaaaaaaaaaaaaaaaaaaaa'),
          false,
        ); // too long (21 chars)
      });

      test('returns false on network error', () async {
        // Arrange
        const username = 'testuser';
        when(mockClient.get(any)).thenThrow(Exception('Network error'));

        // Act
        final result = await service.checkUsernameAvailability(username);

        // Assert
        expect(result, false);
      });
    });

    group('registerUsername', () {
      const validPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      test('successfully registers a username', () async {
        // Arrange
        const username = 'newuser';

        when(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'success': true}), 201),
        );

        // Act & Assert - should complete without throwing
        await expectLater(
          service.registerUsername(username, validPubkey),
          completes,
        );

        // Verify post was called
        verify(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).called(1);
      });

      test('throws UsernameTakenException on 409', () async {
        // Arrange
        const username = 'taken';

        when(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'error': 'Username already taken'}),
            409,
          ),
        );

        // Act & Assert
        await expectLater(
          () => service.registerUsername(username, validPubkey),
          throwsA(isA<UsernameTakenException>()),
        );
      });

      test('throws UsernameReservedException on 403', () async {
        // Arrange
        const username = 'reserved';

        when(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async =>
              http.Response(jsonEncode({'error': 'Username is reserved'}), 403),
        );

        // Act & Assert
        await expectLater(
          () => service.registerUsername(username, validPubkey),
          throwsA(isA<UsernameReservedException>()),
        );
      });

      test('throws ArgumentError for invalid username format', () async {
        // Act & Assert
        await expectLater(
          () => service.registerUsername('ab', validPubkey), // too short
          throwsA(isA<ArgumentError>()),
        );

        await expectLater(
          () => service.registerUsername('user@invalid', validPubkey),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError for invalid pubkey format', () async {
        // Act & Assert - too short
        await expectLater(
          () => service.registerUsername(
            'validuser',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
          throwsA(isA<ArgumentError>()),
        );

        // Non-hex characters
        await expectLater(
          () => service.registerUsername(
            'validuser',
            'gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws Nip05ServiceException on network error', () async {
        // Arrange
        when(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenThrow(Exception('Network error'));

        // Act & Assert
        await expectLater(
          () => service.registerUsername('validuser', validPubkey),
          throwsA(isA<Nip05ServiceException>()),
        );
      });

      test('throws Nip05ServiceException on unexpected status code', () async {
        // Arrange
        when(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => http.Response('Server error', 500));

        // Act & Assert
        await expectLater(
          () => service.registerUsername('validuser', validPubkey),
          throwsA(isA<Nip05ServiceException>()),
        );
      });
    });
  });
}

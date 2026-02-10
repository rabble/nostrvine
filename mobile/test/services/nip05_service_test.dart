// ABOUTME: Unit tests for NIP-05 username availability service
// ABOUTME: Tests username validation and availability checking

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/nip05_service.dart';

@GenerateMocks([http.Client])
import 'nip05_service_test.mocks.dart';

void main() {
  group('Nip05Service', () {
    late Nip05Service service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      service = Nip05Service(httpClient: mockClient);
    });

    group('checkSubdomainAvailability', () {
      test('returns true when subdomain returns 404 (not found)', () async {
        // Arrange
        const username = 'testuser';
        when(
          mockClient.get(any),
        ).thenAnswer((_) async => http.Response('Not Found', 404));

        // Act
        final result = await service.checkSubdomainAvailability(username);

        // Assert
        expect(result, true);
        verify(
          mockClient.get(
            Uri.parse(
              'https://testuser.divine.video/.well-known/nostr.json?name=_',
            ),
          ),
        ).called(1);
      });

      test('returns true when subdomain exists but has no _ entry', () async {
        // Arrange
        const username = 'testuser';
        when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response(jsonEncode({'names': {}}), 200),
        );

        // Act
        final result = await service.checkSubdomainAvailability(username);

        // Assert
        expect(result, true);
      });

      test('returns false when subdomain has _ entry (taken)', () async {
        // Arrange
        const username = 'taken';
        when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'names': {'_': 'pubkey123'},
            }),
            200,
          ),
        );

        // Act
        final result = await service.checkSubdomainAvailability(username);

        // Assert
        expect(result, false);
      });

      test('returns false for invalid username format', () async {
        // Test invalid usernames (no network call needed)
        expect(await service.checkSubdomainAvailability(''), false);
        expect(
          await service.checkSubdomainAvailability('a'),
          false,
        ); // too short
        expect(
          await service.checkSubdomainAvailability('user name'),
          false,
        ); // contains space
        expect(
          await service.checkSubdomainAvailability('user@name'),
          false,
        ); // invalid char
        expect(
          await service.checkSubdomainAvailability('aaaaaaaaaaaaaaaaaaaaa'),
          false,
        ); // too long
      });

      test('falls back to legacy check on network error', () async {
        // Arrange
        const username = 'testuser';
        var callCount = 0;
        when(mockClient.get(any)).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            // First call (subdomain) throws
            throw Exception('Network error');
          }
          // Second call (legacy) succeeds
          return http.Response(jsonEncode({'names': {}}), 200);
        });

        // Act
        final result = await service.checkSubdomainAvailability(username);

        // Assert
        expect(result, true);
        expect(callCount, 2);
      });
    });

    group('checkUsernameAvailability (legacy)', () {
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
  });
}

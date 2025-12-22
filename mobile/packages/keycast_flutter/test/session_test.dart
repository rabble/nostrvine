// ABOUTME: Tests for KeycastSession - session model with expiry handling
// ABOUTME: Verifies session creation, expiry checks, and serialization

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/src/models/keycast_session.dart';
import 'package:keycast_flutter/src/oauth/token_response.dart';

void main() {
  group('KeycastSession', () {
    group('fromTokenResponse', () {
      test('creates session from token response', () {
        final tokenResponse = TokenResponse(
          bunkerUrl: 'bunker://test',
          accessToken: 'test_token',
          expiresIn: 3600,
          scope: 'policy:social',
        );

        final session = KeycastSession.fromTokenResponse(tokenResponse);

        expect(session.bunkerUrl, 'bunker://test');
        expect(session.accessToken, 'test_token');
        expect(session.scope, 'policy:social');
        expect(session.expiresAt, isNotNull);
      });

      test('handles zero expiresIn', () {
        final tokenResponse = TokenResponse(
          bunkerUrl: 'bunker://test',
          accessToken: 'test_token',
          expiresIn: 0,
        );

        final session = KeycastSession.fromTokenResponse(tokenResponse);
        expect(session.expiresAt, isNull);
      });

      test('handles missing accessToken', () {
        final tokenResponse = TokenResponse(
          bunkerUrl: 'bunker://test',
        );

        final session = KeycastSession.fromTokenResponse(tokenResponse);
        expect(session.accessToken, isNull);
      });
    });

    group('isExpired', () {
      test('returns false when expiresAt is null', () {
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'token',
          expiresAt: null,
        );
        expect(session.isExpired, isFalse);
      });

      test('returns false when expiresAt is in the future', () {
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'token',
          expiresAt: DateTime.now().add(Duration(hours: 1)),
        );
        expect(session.isExpired, isFalse);
      });

      test('returns true when expiresAt is in the past', () {
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'token',
          expiresAt: DateTime.now().subtract(Duration(hours: 1)),
        );
        expect(session.isExpired, isTrue);
      });
    });

    group('hasRpcAccess', () {
      test('returns true when has token and not expired', () {
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'token',
          expiresAt: DateTime.now().add(Duration(hours: 1)),
        );
        expect(session.hasRpcAccess, isTrue);
      });

      test('returns false when accessToken is null', () {
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: null,
          expiresAt: DateTime.now().add(Duration(hours: 1)),
        );
        expect(session.hasRpcAccess, isFalse);
      });

      test('returns false when expired', () {
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'token',
          expiresAt: DateTime.now().subtract(Duration(hours: 1)),
        );
        expect(session.hasRpcAccess, isFalse);
      });
    });

    group('serialization', () {
      test('toJson and fromJson round-trip', () {
        final original = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'token',
          expiresAt: DateTime.parse('2024-12-31T12:00:00Z'),
          scope: 'policy:social',
          userPubkey: 'abc123',
        );

        final json = original.toJson();
        final restored = KeycastSession.fromJson(json);

        expect(restored.bunkerUrl, original.bunkerUrl);
        expect(restored.accessToken, original.accessToken);
        expect(restored.expiresAt?.toIso8601String(),
            original.expiresAt?.toIso8601String());
        expect(restored.scope, original.scope);
        expect(restored.userPubkey, original.userPubkey);
      });

      test('handles null fields in serialization', () {
        final original = KeycastSession(
          bunkerUrl: 'bunker://test',
        );

        final json = original.toJson();
        final restored = KeycastSession.fromJson(json);

        expect(restored.bunkerUrl, original.bunkerUrl);
        expect(restored.accessToken, isNull);
        expect(restored.expiresAt, isNull);
      });
    });
  });
}

// ABOUTME: Tests the protected-minor repository: token gating, mapping, and
// ABOUTME: unknown status on Keycast fetch errors (#174)

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/repositories/protected_minor_repository.dart';

KeycastOAuth _oauthReturning(String body, int status) {
  return KeycastOAuth(
    config: const OAuthConfig(
      serverUrl: 'https://login.divine.video',
      clientId: 'c',
      redirectUri: 'divine://cb',
    ),
    httpClient: MockClient((_) async => http.Response(body, status)),
  );
}

const _minorBody =
    '{"email":"a","email_verified":true,"public_key":"p",'
    '"verified_minor":true,"verified_minor_at":"2026-06-30T12:00:00Z"}';

void main() {
  group('ProtectedMinorRepository.fetchCurrentStatus', () {
    test('protected when keycast reports verified_minor true', () async {
      final repo = ProtectedMinorRepository(
        oauthClient: _oauthReturning(_minorBody, 200),
        readAccessToken: () async => 'tok',
      );

      final s = await repo.fetchCurrentStatus();

      expect(s.isProtectedMinor, isTrue);
    });

    test('not protected when there is no access token', () async {
      final repo = ProtectedMinorRepository(
        oauthClient: _oauthReturning(_minorBody, 200),
        readAccessToken: () async => null,
      );

      final s = await repo.fetchCurrentStatus();

      expect(s.isProtectedMinor, isFalse);
    });

    test('unknown on server error', () async {
      final repo = ProtectedMinorRepository(
        oauthClient: _oauthReturning('err', 500),
        readAccessToken: () async => 'tok',
      );

      final s = await repo.fetchCurrentStatus();

      expect(s.kind, ProtectedMinorStatusKind.unknown);
      expect(s.isKnown, isFalse);
      expect(s.isProtectedMinor, isFalse);
    });

    test('not protected when the access token is empty', () async {
      final repo = ProtectedMinorRepository(
        oauthClient: _oauthReturning(_minorBody, 200),
        readAccessToken: () async => '',
      );

      final s = await repo.fetchCurrentStatus();

      expect(s.isProtectedMinor, isFalse);
    });

    test('unknown when reading the token throws', () async {
      final repo = ProtectedMinorRepository(
        oauthClient: _oauthReturning(_minorBody, 200),
        readAccessToken: () async => throw Exception('boom'),
      );

      final s = await repo.fetchCurrentStatus();

      expect(s.kind, ProtectedMinorStatusKind.unknown);
      expect(s.isKnown, isFalse);
      expect(s.isProtectedMinor, isFalse);
    });
  });
}

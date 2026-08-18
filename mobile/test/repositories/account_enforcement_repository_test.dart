// ABOUTME: Tests the account enforcement repository: token gating, mapping,
// ABOUTME: and unknown status on Keycast fetch errors (s-t-s#200).

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/repositories/account_enforcement_repository.dart';

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

const _activeBody =
    '{"email":"a","email_verified":true,"public_key":"p",'
    '"verified_minor":false}';

const _suspendedBody =
    '{"email":"a","email_verified":true,"public_key":"p",'
    '"verified_minor":false,"account_status":"suspended",'
    '"suspended_reason":"moderation"}';

void main() {
  group('AccountEnforcementRepository.fetchCurrentStatus', () {
    test('suspended when keycast reports account_status suspended', () async {
      final repo = AccountEnforcementRepository(
        oauthClient: _oauthReturning(_suspendedBody, 200),
        readAccessToken: () async => 'tok',
      );

      final s = await repo.fetchCurrentStatus();

      expect(s.kind, AccountEnforcementKind.suspended);
      expect(s.isEnforced, isTrue);
    });

    test('none when keycast reports an active account', () async {
      final repo = AccountEnforcementRepository(
        oauthClient: _oauthReturning(_activeBody, 200),
        readAccessToken: () async => 'tok',
      );

      final s = await repo.fetchCurrentStatus();

      expect(s.kind, AccountEnforcementKind.none);
    });

    test(
      'unknown when there is no access token (self-custody signer)',
      () async {
        // A self-custody signer has no Keycast session, so there is no signal
        // here at all. It must NOT read as a positive "in good standing" — the
        // relay rejection reason is the enforcement signal for those accounts.
        final repo = AccountEnforcementRepository(
          oauthClient: _oauthReturning(_suspendedBody, 200),
          readAccessToken: () async => null,
        );

        final s = await repo.fetchCurrentStatus();

        expect(s.kind, AccountEnforcementKind.unknown);
        expect(s.isKnown, isFalse);
      },
    );

    test('unknown on server error', () async {
      final repo = AccountEnforcementRepository(
        oauthClient: _oauthReturning('err', 500),
        readAccessToken: () async => 'tok',
      );

      final s = await repo.fetchCurrentStatus();

      expect(s.kind, AccountEnforcementKind.unknown);
    });

    test('unknown when reading the token throws', () async {
      final repo = AccountEnforcementRepository(
        oauthClient: _oauthReturning(_activeBody, 200),
        readAccessToken: () async => throw StateError('secure storage locked'),
      );

      final s = await repo.fetchCurrentStatus();

      expect(s.kind, AccountEnforcementKind.unknown);
    });
  });
}

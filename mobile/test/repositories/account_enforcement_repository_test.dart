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
      'a missing token is a failed ask, not a clean bill of health',
      () async {
        // Same exit as a failed read: resolving this would be indistinguishable
        // from a successful "no enforcement" answer and would clear a
        // restriction the user had already been shown. Self-custody never
        // reaches here; the provider short-circuits it.
        final repo = AccountEnforcementRepository(
          oauthClient: _oauthReturning(_suspendedBody, 200),
          readAccessToken: () async => null,
        );

        await expectLater(
          repo.fetchCurrentStatus(),
          throwsA(isA<AccountStatusUnavailable>()),
        );
      },
    );

    test('an empty token is treated the same as a missing one', () async {
      // Without the isEmpty half of the guard this would send `Bearer ` and
      // read whatever the server makes of it, instead of reporting that we
      // could not ask.
      final repo = AccountEnforcementRepository(
        oauthClient: _oauthReturning(_activeBody, 200),
        readAccessToken: () async => '',
      );

      await expectLater(
        repo.fetchCurrentStatus(),
        throwsA(isA<AccountStatusUnavailable>()),
      );
    });

    test('surfaces a read failure as an error, not as a status', () async {
      // A failed read must be distinguishable from a successful "no
      // enforcement" read: collapsing them lets an offline refresh clear a
      // restriction marker the user already earned.
      final repo = AccountEnforcementRepository(
        oauthClient: _oauthReturning('err', 500),
        readAccessToken: () async => 'tok',
      );

      await expectLater(
        repo.fetchCurrentStatus(),
        throwsA(isA<AccountStatusUnavailable>()),
      );
    });

    test('propagates an error from reading the token', () async {
      final repo = AccountEnforcementRepository(
        oauthClient: _oauthReturning(_activeBody, 200),
        readAccessToken: () async => throw StateError('secure storage locked'),
      );

      await expectLater(repo.fetchCurrentStatus(), throwsA(isA<StateError>()));
    });
  });
}

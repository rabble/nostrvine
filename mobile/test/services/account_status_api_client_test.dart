// ABOUTME: Tests the NIP-98 Funnelcake account status HTTP contract.
// ABOUTME: Ensures only a valid account-bound 200 response becomes status state.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/account_status_api_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

AccountStatusApiClient _client({
  required Future<http.Response> Function(http.Request) handler,
  Future<String?> Function({required String url, required HttpMethod method})?
  auth,
  Duration timeout = const Duration(seconds: 30),
}) {
  return AccountStatusApiClient(
    baseUri: Uri.parse('https://api.divine.video/base'),
    authHeaderProvider:
        auth ??
        ({required url, required method}) async {
          expect(url, 'https://api.divine.video/api/users/$_pubkey/status');
          expect(method, HttpMethod.get);
          return 'Nostr signed-token';
        },
    httpClient: MockClient(handler),
    timeout: timeout,
  );
}

void main() {
  group('AccountStatusApiClient.fetchStatus', () {
    test('signs and sends the exact API URL', () async {
      final client = _client(
        handler: (request) async {
          expect(request.headers['Authorization'], 'Nostr signed-token');
          return http.Response('{"pubkey":"$_pubkey","status":"active"}', 200);
        },
      );

      expect(
        await client.fetchStatus(expectedPubkey: _pubkey),
        FunnelcakeAccountStatus.active,
      );
    });

    test('maps all recognized and future status strings', () async {
      for (final entry in {
        'active': FunnelcakeAccountStatus.active,
        'suspended': FunnelcakeAccountStatus.suspended,
        'banned': FunnelcakeAccountStatus.banned,
        'future': FunnelcakeAccountStatus.unknown,
      }.entries) {
        final client = _client(
          handler: (_) async => http.Response(
            '{"pubkey":"$_pubkey","status":"${entry.key}"}',
            200,
          ),
        );
        expect(await client.fetchStatus(expectedPubkey: _pubkey), entry.value);
      }
    });

    test('accepts matching pubkey case-insensitively', () async {
      final client = _client(
        handler: (_) async => http.Response(
          '{"pubkey":"${_pubkey.toUpperCase()}","status":"active"}',
          200,
        ),
      );
      expect(
        await client.fetchStatus(expectedPubkey: _pubkey),
        FunnelcakeAccountStatus.active,
      );
    });

    test('rejects a response for another account', () async {
      final other = List.filled(64, 'b').join();
      final client = _client(
        handler: (_) async =>
            http.Response('{"pubkey":"$other","status":"active"}', 200),
      );
      await expectLater(
        client.fetchStatus(expectedPubkey: _pubkey),
        throwsA(
          isA<AccountStatusApiException>().having(
            (error) => error.kind,
            'kind',
            AccountStatusApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('rejects malformed and incomplete 200 responses', () async {
      for (final body in ['not-json', '{}', '[]', '{"pubkey":"$_pubkey"}']) {
        final client = _client(handler: (_) async => http.Response(body, 200));
        await expectLater(
          client.fetchStatus(expectedPubkey: _pubkey),
          throwsA(isA<AccountStatusApiException>()),
        );
      }
    });

    test('does not map non-2xx responses to active', () async {
      for (final code in [401, 404, 500, 503]) {
        final client = _client(
          handler: (_) async => http.Response('unavailable', code),
        );
        await expectLater(
          client.fetchStatus(expectedPubkey: _pubkey),
          throwsA(isA<AccountStatusApiException>()),
        );
      }
    });

    test('reports missing signer, transport failure, and timeout', () async {
      final unsigned = _client(
        auth: ({required url, required method}) async => null,
        handler: (_) async => http.Response('', 500),
      );
      await expectLater(
        unsigned.fetchStatus(expectedPubkey: _pubkey),
        throwsA(isA<AccountStatusApiException>()),
      );

      final transportFailure = _client(
        handler: (_) async => throw http.ClientException('offline'),
      );
      await expectLater(
        transportFailure.fetchStatus(expectedPubkey: _pubkey),
        throwsA(isA<AccountStatusApiException>()),
      );

      final timedOut = _client(
        timeout: Duration.zero,
        handler: (_) => Completer<http.Response>().future,
      );
      await expectLater(
        timedOut.fetchStatus(expectedPubkey: _pubkey),
        throwsA(isA<AccountStatusApiException>()),
      );
    });
  });
}

// ABOUTME: Tests for KeycastOAuth.exportKey over HTTP
// ABOUTME: Covers the POST /user/export-key contract and its refusal mapping

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/src/oauth/headless_models.dart';
import 'package:keycast_flutter/src/oauth/oauth_client.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';

void main() {
  group('KeycastOAuth.exportKey', () {
    const config = OAuthConfig(
      serverUrl: 'https://login.divine.video',
      clientId: 'test-client',
      redirectUri: 'divine://oauth/callback',
    );

    const nsec =
        'nsec1testkeymaterialthatisnotarealkey00000000000000000000000000';

    /// A client that answers export-key with [status]/[body] and account-status
    /// with [accountStatusCode], so the 401 disambiguation can be driven.
    MockClient exportClient({
      required int status,
      required String body,
      int accountStatusCode = 200,
      void Function(http.Request request)? onExport,
    }) {
      return MockClient((request) async {
        if (request.url.path == '/api/user/export-key') {
          onExport?.call(request);
          return http.Response(body, status);
        }
        if (request.url.path == '/api/user/account') {
          return http.Response(
            '{"email":"a@b.com","email_verified":true,"public_key":"abc"}',
            accountStatusCode,
          );
        }
        return http.Response('unexpected ${request.url.path}', 404);
      });
    }

    test(
      'POSTs the bearer token, password and format, and returns the key',
      () async {
        late http.Request captured;
        final oauth = KeycastOAuth(
          config: config,
          httpClient: exportClient(
            status: 200,
            body: jsonEncode({'key': nsec}),
            onExport: (request) => captured = request,
          ),
        );

        final result = await oauth.exportKey('tok123', 'hunter2');

        expect(captured.method, 'POST');
        expect(
          captured.url.toString(),
          'https://login.divine.video/api/user/export-key',
        );
        expect(captured.headers['Authorization'], 'Bearer tok123');
        expect(jsonDecode(captured.body), {
          'password': 'hunter2',
          'format': 'nsec',
        });
        expect(result.success, isTrue);
        expect(result.key, nsec);
        expect(result.failure, isNull);
      },
    );

    test('forwards a non-default format', () async {
      late http.Request captured;
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 200,
          body: jsonEncode({'key': 'deadbeef'}),
          onExport: (request) => captured = request,
        ),
      );

      await oauth.exportKey('tok', 'pw', format: 'hex');

      expect((jsonDecode(captured.body) as Map)['format'], 'hex');
    });

    test(
      'treats a 200 with no key as a failure rather than an empty key',
      () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: exportClient(status: 200, body: '{}'),
        );

        final result = await oauth.exportKey('tok', 'pw');

        expect(result.success, isFalse);
        expect(result.key, isNull);
        expect(result.failure, ExportKeyFailure.unknown);
      },
    );

    // Keycast answers 401 for a wrong password and for a stale token alike, so
    // these two pin the only thing that separates them.
    test('reads 401 as a wrong password while the token still works', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 401,
          body: jsonEncode({'error': 'Invalid email or password.'}),
        ),
      );

      final result = await oauth.exportKey('tok', 'wrong');

      expect(result.success, isFalse);
      expect(result.failure, ExportKeyFailure.wrongPassword);
    });

    test('reads 401 as needing sign-in when the token is dead too', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 401,
          body: jsonEncode({'error': 'Invalid or expired token.'}),
          accountStatusCode: 401,
        ),
      );

      final result = await oauth.exportKey('tok', 'pw');

      expect(result.success, isFalse);
      expect(result.failure, ExportKeyFailure.needsSignIn);
    });

    test(
      'separates an unverified email from a policy refusal on 403',
      () async {
        final unverified = KeycastOAuth(
          config: config,
          httpClient: exportClient(
            status: 403,
            body: jsonEncode({
              'error':
                  'Please verify your email address before continuing. '
                  'Check your inbox for the verification link.',
            }),
          ),
        );

        expect(
          (await unverified.exportKey('tok', 'pw')).failure,
          ExportKeyFailure.emailUnverified,
        );

        // The verified_minor refusal is deliberately worded to leak no account
        // state, so anything that is not the email message is a policy denial.
        final denied = KeycastOAuth(
          config: config,
          httpClient: exportClient(
            status: 403,
            body: jsonEncode({'error': 'Operation denied by policy'}),
          ),
        );

        expect(
          (await denied.exportKey('tok', 'pw')).failure,
          ExportKeyFailure.denied,
        );
      },
    );

    test('maps 404 to no key on record', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 404,
          body: jsonEncode({'error': 'No account found with this email.'}),
        ),
      );

      expect(
        (await oauth.exportKey('tok', 'pw')).failure,
        ExportKeyFailure.noKey,
      );
    });

    test('maps 5xx to a server failure', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 503,
          body: jsonEncode({'error': 'Service temporarily unavailable.'}),
        ),
      );

      final result = await oauth.exportKey('tok', 'pw');

      expect(result.failure, ExportKeyFailure.server);
      expect(result.error, contains('Service temporarily unavailable'));
    });

    test('maps a transport failure to network', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: MockClient(
          (_) async => throw http.ClientException('connection reset'),
        ),
      );

      final result = await oauth.exportKey('tok', 'pw');

      expect(result.success, isFalse);
      expect(result.failure, ExportKeyFailure.network);
    });

    test('never returns a key on any failure path', () async {
      for (final status in [400, 401, 403, 404, 500, 503]) {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: exportClient(
            status: status,
            // A server that wrongly echoes key material must not leak it
            // through a failure result.
            body: jsonEncode({'error': 'nope', 'key': nsec}),
          ),
        );

        final result = await oauth.exportKey('tok', 'pw');

        expect(result.success, isFalse, reason: 'status $status');
        expect(result.key, isNull, reason: 'status $status');
      }
    });
  });
}

// ABOUTME: Tests for KeycastOAuth client - OAuth flow handling
// ABOUTME: Verifies URL building, callback parsing, token exchange (mocked HTTP)

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/src/oauth/oauth_client.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';
import 'package:keycast_flutter/src/oauth/callback_result.dart';

void main() {
  final config = OAuthConfig(
    serverUrl: 'https://login.divine.video',
    clientId: 'test-client',
    redirectUri: 'divine://oauth/callback',
  );

  group('KeycastOAuth', () {
    group('getAuthorizationUrl', () {
      test('generates URL with required parameters', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, verifier) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(uri.host, 'login.divine.video');
        expect(uri.path, '/api/oauth/authorize');
        expect(uri.queryParameters['client_id'], 'test-client');
        expect(uri.queryParameters['redirect_uri'], 'divine://oauth/callback');
        expect(uri.queryParameters['code_challenge'], isNotEmpty);
        expect(uri.queryParameters['code_challenge_method'], 'S256');
        expect(verifier, isNotEmpty);
      });

      test('includes default scope', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(uri.queryParameters['scope'], 'policy:social');
      });

      test('accepts custom scope', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl(scope: 'custom:scope');

        final uri = Uri.parse(url);
        expect(uri.queryParameters['scope'], 'custom:scope');
      });

      test('includes default_register=true by default', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(uri.queryParameters['default_register'], 'true');
      });

      test('respects defaultRegister=false', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl(defaultRegister: false);

        final uri = Uri.parse(url);
        expect(uri.queryParameters['default_register'], 'false');
      });

      test('omits byok_pubkey when nsec not provided', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(uri.queryParameters.containsKey('byok_pubkey'), isFalse);
      });

      test('includes byok_pubkey when nsec provided', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, verifier) = await oauth.getAuthorizationUrl(
          nsec:
              'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5',
        );

        final uri = Uri.parse(url);
        expect(uri.queryParameters.containsKey('byok_pubkey'), isTrue);
        expect(uri.queryParameters['byok_pubkey']?.length, 64);
        expect(verifier, contains('.nsec1'));
      });

      test('returns null URL for invalid nsec', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl(nsec: 'invalid');
        expect(url, isEmpty);
      });
    });

    group('parseCallback', () {
      test('extracts code from successful callback', () {
        final oauth = KeycastOAuth(config: config);
        final result = oauth.parseCallback(
          'divine://oauth/callback?code=auth_code_123',
        );

        expect(result, isA<CallbackSuccess>());
        expect((result as CallbackSuccess).code, 'auth_code_123');
      });

      test('extracts error from failed callback', () {
        final oauth = KeycastOAuth(config: config);
        final result = oauth.parseCallback(
          'divine://oauth/callback?error=access_denied&error_description=User%20denied',
        );

        expect(result, isA<CallbackError>());
        final error = result as CallbackError;
        expect(error.error, 'access_denied');
        expect(error.description, 'User denied');
      });

      test('returns error for missing code and error', () {
        final oauth = KeycastOAuth(config: config);
        final result = oauth.parseCallback('divine://oauth/callback');

        expect(result, isA<CallbackError>());
        expect((result as CallbackError).error, 'invalid_response');
      });
    });

    group('exchangeCode', () {
      test('exchanges code for tokens', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(),
              'https://login.divine.video/api/oauth/token');
          expect(request.method, 'POST');

          final body = jsonDecode(request.body);
          expect(body['grant_type'], 'authorization_code');
          expect(body['code'], 'auth_code');
          expect(body['code_verifier'], 'test_verifier');

          return http.Response(
            jsonEncode({
              'bunker_url': 'bunker://abc123',
              'access_token': 'access_token_xyz',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final response = await oauth.exchangeCode(
          code: 'auth_code',
          verifier: 'test_verifier',
        );

        expect(response.bunkerUrl, 'bunker://abc123');
        expect(response.accessToken, 'access_token_xyz');
        expect(response.expiresIn, 3600);
      });

      test('throws OAuthException on error response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'invalid_grant',
              'error_description': 'Code expired',
            }),
            400,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);

        expect(
          () => oauth.exchangeCode(code: 'bad_code', verifier: 'verifier'),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}

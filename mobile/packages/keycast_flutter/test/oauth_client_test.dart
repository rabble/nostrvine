// ABOUTME: Tests for KeycastOAuth client - OAuth flow handling
// ABOUTME: Verifies URL building, callback parsing, token exchange (mocked HTTP)

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/src/models/keycast_session.dart';
import 'package:keycast_flutter/src/oauth/callback_result.dart';
import 'package:keycast_flutter/src/oauth/headless_models.dart';
import 'package:keycast_flutter/src/oauth/oauth_client.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';
import 'package:keycast_flutter/src/storage/keycast_storage.dart';

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
        final (url, _) = await oauth.getAuthorizationUrl(
          defaultRegister: false,
        );

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
          expect(
            request.url.toString(),
            'https://login.divine.video/api/oauth/token',
          );
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

    group('getSession', () {
      test('returns stored session when valid and not expired', () async {
        final storage = MemoryKeycastStorage();
        final session = KeycastSession(
          bunkerUrl: 'bunker://test123',
          accessToken: 'token123',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
        await storage.write('keycast_session', jsonEncode(session.toJson()));

        final oauth = KeycastOAuth(config: config, storage: storage);
        final result = await oauth.getSession();

        expect(result, isNotNull);
        expect(result!.bunkerUrl, 'bunker://test123');
        expect(result.accessToken, 'token123');
      });

      test('returns null when session is expired', () async {
        final storage = MemoryKeycastStorage();
        final session = KeycastSession(
          bunkerUrl: 'bunker://test123',
          accessToken: 'token123',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        await storage.write('keycast_session', jsonEncode(session.toJson()));

        final oauth = KeycastOAuth(config: config, storage: storage);
        final result = await oauth.getSession();

        expect(result, isNull);
      });

      test('returns null when no session stored', () async {
        final storage = MemoryKeycastStorage();
        final oauth = KeycastOAuth(config: config, storage: storage);
        final result = await oauth.getSession();

        expect(result, isNull);
      });

      test('returns null when JSON parsing fails', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_session', 'invalid json {{{');

        final oauth = KeycastOAuth(config: config, storage: storage);
        final result = await oauth.getSession();

        expect(result, isNull);
      });
    });

    group('logout', () {
      test('deletes session and handle from storage', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_session', 'session_data');
        await storage.write('keycast_auth_handle', 'handle_data');

        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        await oauth.logout();

        expect(await storage.read('keycast_session'), isNull);
        expect(await storage.read('keycast_auth_handle'), isNull);
      });

      test('makes POST request to logout endpoint', () async {
        var logoutCalled = false;
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/auth/logout') {
            expect(request.method, 'POST');
            logoutCalled = true;
          }
          return http.Response('', 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.logout();

        // The POST request is fire-and-forget (unawaited), so wait for microtasks
        await Future<void>.delayed(Duration.zero);

        expect(logoutCalled, isTrue);
      });
    });

    group('getAuthorizationUrl - additional', () {
      test('includes authorization_handle when stored', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_auth_handle', 'stored_handle_123');

        final oauth = KeycastOAuth(config: config, storage: storage);
        final (url, _) = await oauth.getAuthorizationUrl();

        final uri = Uri.parse(url);
        expect(
          uri.queryParameters['authorization_handle'],
          'stored_handle_123',
        );
      });

      test('includes prompt parameter when provided', () async {
        final oauth = KeycastOAuth(config: config);
        final (url, _) = await oauth.getAuthorizationUrl(prompt: 'login');

        final uri = Uri.parse(url);
        expect(uri.queryParameters['prompt'], 'login');
      });

      test('prefers explicit authorizationHandle over stored', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_auth_handle', 'stored_handle');

        final oauth = KeycastOAuth(config: config, storage: storage);
        final (url, _) = await oauth.getAuthorizationUrl(
          authorizationHandle: 'explicit_handle',
        );

        final uri = Uri.parse(url);
        expect(uri.queryParameters['authorization_handle'], 'explicit_handle');
      });
    });

    group('headlessRegister', () {
      test('returns success result on 200 response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/headless/register');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'abc123pubkey',
              'verification_required': true,
              'device_code': 'device_code_123',
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, verifier) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isTrue);
        expect(result.pubkey, 'abc123pubkey');
        expect(result.deviceCode, 'device_code_123');
        expect(verifier, isNotEmpty);
      });

      test('returns success result on 201 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'newpubkey',
              'verification_required': true,
            }),
            201,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isTrue);
      });

      test('includes nsec in body when provided', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['nsec'], contains('nsec1'));
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'byok_pubkey',
              'verification_required': true,
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
          nsec:
              'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5',
        );
      });

      test('includes state parameter when provided', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['state'], 'my_state_value');
          return http.Response(
            jsonEncode({
              'success': true,
              'pubkey': 'pubkey',
              'verification_required': true,
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
          state: 'my_state_value',
        );
      });

      test('returns error on 404 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('not available'));
      });

      test('returns error on 500+ server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Server error'));
        expect(result.error, contains('500'));
      });

      test('returns error on invalid JSON response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not valid json {{{', 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Invalid server response'));
      });

      test('returns error with error/message fields from response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'email_taken',
              'error_description': 'Email already registered',
            }),
            400,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('email_taken'));
      });

      test('returns error on SocketException', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Connection refused');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Cannot connect to server'));
      });

      test('returns error on other network errors', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Some other error');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessRegister(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Network error'));
      });
    });

    group('headlessLogin', () {
      test('returns success result on 200 response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/headless/login');
          expect(request.method, 'POST');
          return http.Response(
            jsonEncode({
              'success': true,
              'code': 'auth_code_123',
              'pubkey': 'user_pubkey',
            }),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, verifier) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isTrue);
        expect(result.code, 'auth_code_123');
        expect(result.pubkey, 'user_pubkey');
        expect(verifier, isNotEmpty);
      });

      test('includes state parameter when provided', () async {
        final mockClient = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['state'], 'login_state');
          return http.Response(
            jsonEncode({'success': true, 'code': 'code123'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
          state: 'login_state',
        );
      });

      test('returns error on 404 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, 'endpoint_not_found');
      });

      test('returns error on 500+ server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 503);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, 'server_error');
        expect(result.errorDescription, contains('503'));
      });

      test('returns error on invalid JSON response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not valid json', 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, 'invalid_response');
      });

      test('returns error with error fields from response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'invalid_credentials',
              'error_description': 'Wrong password',
            }),
            401,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, 'invalid_credentials');
        expect(result.errorDescription, 'Wrong password');
      });

      test('returns error on SocketException', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Connection refused');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.error, 'connection_error');
      });

      test('returns error on other network errors', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Timeout');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final (result, _) = await oauth.headlessLogin(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result.success, isFalse);
        expect(result.errorDescription, contains('Network error'));
      });
    });

    group('pollForCode', () {
      test('returns complete with code on 200 with code', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/oauth/poll');
          expect(request.url.queryParameters['device_code'], 'device123');
          return http.Response(jsonEncode({'code': 'auth_code_456'}), 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.complete);
        expect(result.code, 'auth_code_456');
      });

      test('returns pending on 200 without code', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({}), 200);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.pending);
      });

      test('returns pending on 202 status', () async {
        final mockClient = MockClient((request) async {
          return http.Response('', 202);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.pending);
      });

      test('returns error with JSON error on non-200/202', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'expired_token',
              'error_description': 'Device code expired',
            }),
            400,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.error);
        expect(result.error, contains('expired_token'));
      });

      test('returns error with HTTP status on invalid JSON', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not json', 400);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.error);
        expect(result.error, 'HTTP 400');
      });

      test('returns error on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network failure');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.pollForCode('device123');

        expect(result.status, PollStatus.error);
        expect(result.error, contains('Network error'));
      });
    });

    group('sendPasswordResetEmail', () {
      test('returns success on 200 response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/auth/forgot-password');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'test@example.com');
          return http.Response(
            jsonEncode({'success': true, 'message': 'Email sent'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.sendPasswordResetEmail('test@example.com');

        expect(result.success, isTrue);
        expect(result.message, 'Email sent');
      });

      test('returns success on 201 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'success': true}), 201);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.sendPasswordResetEmail('test@example.com');

        expect(result.success, isTrue);
      });

      test('returns error with error/message from response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'user_not_found',
              'message': 'No user with that email',
            }),
            404,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.sendPasswordResetEmail('test@example.com');

        expect(result.success, isFalse);
        expect(result.error, contains('user_not_found'));
      });

      test('returns error on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Connection timeout');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.sendPasswordResetEmail('test@example.com');

        expect(result.success, isFalse);
        expect(result.error, contains('Network error'));
      });
    });

    group('resetPassword', () {
      test('returns success on 200 response', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/auth/reset-password');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], 'reset_token_123');
          expect(body['new_password'], 'newpassword456');
          return http.Response(
            jsonEncode({'success': true, 'message': 'Password reset'}),
            200,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resetPassword(
          token: 'reset_token_123',
          newPassword: 'newpassword456',
        );

        expect(result.success, isTrue);
        expect(result.message, 'Password reset');
      });

      test('returns success on 201 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'success': true}), 201);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resetPassword(
          token: 'token',
          newPassword: 'password',
        );

        expect(result.success, isTrue);
      });

      test('returns error with message from response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Token expired'}), 400);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resetPassword(
          token: 'expired_token',
          newPassword: 'password',
        );

        expect(result.success, isFalse);
        expect(result.message, 'Token expired');
      });

      test('returns error on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Server unreachable');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.resetPassword(
          token: 'token',
          newPassword: 'password',
        );

        expect(result.success, isFalse);
        expect(result.message, contains('Network error'));
      });
    });

    group('deleteAccount', () {
      test('returns success and clears storage on 200', () async {
        final storage = MemoryKeycastStorage();
        await storage.write('keycast_session', 'session_data');
        await storage.write('keycast_auth_handle', 'handle_data');

        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/user/account');
          expect(request.method, 'DELETE');
          expect(request.headers['Authorization'], 'Bearer test_token');
          return http.Response(
            jsonEncode({'success': true, 'message': 'Account deleted'}),
            200,
          );
        });

        final oauth = KeycastOAuth(
          config: config,
          httpClient: mockClient,
          storage: storage,
        );
        final result = await oauth.deleteAccount('test_token');

        expect(result.success, isTrue);
        expect(result.message, 'Account deleted');
        expect(await storage.read('keycast_session'), isNull);
        expect(await storage.read('keycast_auth_handle'), isNull);
      });

      test('returns error on 401 unauthorized', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('invalid_token');

        expect(result.success, isFalse);
        expect(result.error, contains('Unauthorized'));
      });

      test('returns error on 404 not found', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('not found'));
      });

      test('returns error on 500+ server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Error', 502);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('Server error'));
        expect(result.error, contains('502'));
      });

      test('returns error with JSON error on other status', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'deletion_pending',
              'message': 'Account deletion already in progress',
            }),
            409,
          );
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('deletion_pending'));
      });

      test('returns error with HTTP status on invalid JSON', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not json response', 422);
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, 'HTTP 422');
      });

      test('returns error on SocketException', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Connection refused');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('Cannot connect to server'));
      });

      test('returns error on other network errors', () async {
        final mockClient = MockClient((request) async {
          throw Exception('DNS resolution failed');
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        final result = await oauth.deleteAccount('token');

        expect(result.success, isFalse);
        expect(result.error, contains('Network error'));
      });
    });

    group('close', () {
      test('closes the HTTP client', () {
        var closeCalled = false;
        final mockClient = _CloseTrackingClient(() {
          closeCalled = true;
        });

        final oauth = KeycastOAuth(config: config, httpClient: mockClient);
        oauth.close();

        expect(closeCalled, isTrue);
      });
    });
  });
}

/// Helper client that tracks when close() is called
class _CloseTrackingClient extends http.BaseClient {
  final void Function() onClose;

  _CloseTrackingClient(this.onClose);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnimplementedError();
  }

  @override
  void close() {
    onClose();
  }
}

// ABOUTME: Tests for KeycastRpc client - Nostr signing via RPC
// ABOUTME: Verifies all RPC methods with mocked HTTP, error handling, auth headers

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/src/rpc/keycast_rpc.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';
import 'package:keycast_flutter/src/models/keycast_session.dart';
import 'package:keycast_flutter/src/models/exceptions.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('KeycastRpc', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient((request) async {
        throw Exception('Unexpected request: ${request.url}');
      });
    });

    group('fromSession factory', () {
      test('creates RPC client from valid session', () {
        final config = OAuthConfig(
          serverUrl: 'https://login.divine.video',
          clientId: 'test',
          redirectUri: 'divine://callback',
        );
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'valid_token',
          expiresAt: DateTime.now().add(Duration(hours: 1)),
        );

        final rpc = KeycastRpc.fromSession(config, session);
        expect(rpc, isNotNull);
      });

      test('throws SessionExpiredException for expired session', () {
        final config = OAuthConfig(
          serverUrl: 'https://login.divine.video',
          clientId: 'test',
          redirectUri: 'divine://callback',
        );
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(Duration(hours: 1)),
        );

        expect(
          () => KeycastRpc.fromSession(config, session),
          throwsA(isA<SessionExpiredException>()),
        );
      });

      test('throws SessionExpiredException for null accessToken', () {
        final config = OAuthConfig(
          serverUrl: 'https://login.divine.video',
          clientId: 'test',
          redirectUri: 'divine://callback',
        );
        final session = KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: null,
        );

        expect(
          () => KeycastRpc.fromSession(config, session),
          throwsA(isA<SessionExpiredException>()),
        );
      });
    });

    group('getPublicKey', () {
      test('returns hex pubkey from RPC', () async {
        mockClient = MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test_token');
          expect(request.headers['Content-Type'], 'application/json');

          final body = jsonDecode(request.body);
          expect(body['method'], 'get_public_key');
          expect(body['params'], []);

          return http.Response(
            jsonEncode({
              'result':
                  '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
            }),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final pubkey = await rpc.getPublicKey();
        expect(
          pubkey,
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
        );
      });
    });

    group('signEvent', () {
      test('returns signed event from RPC', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'sign_event');
          expect(body['params'], isNotEmpty);

          return http.Response(
            jsonEncode({
              'result': {
                'id':
                    'abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
                'pubkey':
                    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
                'created_at': 1234567890,
                'kind': 1,
                'tags': [],
                'content': 'test content',
                'sig':
                    'sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123abc456sig123ab',
              },
            }),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final event = Event(
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
          1,
          [],
          'test content',
        );

        final signed = await rpc.signEvent(event);
        expect(signed, isNotNull);
        expect(signed!.sig, isNotEmpty);
      });
    });

    group('nip44Encrypt', () {
      test('returns encrypted text from RPC', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip44_encrypt');
          expect(body['params'].length, 2);

          return http.Response(
            jsonEncode({'result': 'encrypted_ciphertext_base64'}),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final ciphertext = await rpc.nip44Encrypt(
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
          'hello world',
        );
        expect(ciphertext, 'encrypted_ciphertext_base64');
      });
    });

    group('nip44Decrypt', () {
      test('returns decrypted text from RPC', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip44_decrypt');
          expect(body['params'].length, 2);

          return http.Response(
            jsonEncode({'result': 'decrypted plaintext'}),
            200,
          );
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final plaintext = await rpc.nip44Decrypt(
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
          'encrypted_ciphertext',
        );
        expect(plaintext, 'decrypted plaintext');
      });
    });

    group('nip04 encrypt/decrypt', () {
      test('encrypt calls correct RPC method', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip04_encrypt');
          return http.Response(jsonEncode({'result': 'nip04_ciphertext'}), 200);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final result = await rpc.encrypt('pubkey', 'plaintext');
        expect(result, 'nip04_ciphertext');
      });

      test('decrypt calls correct RPC method', () async {
        mockClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], 'nip04_decrypt');
          return http.Response(jsonEncode({'result': 'nip04_plaintext'}), 200);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        final result = await rpc.decrypt('pubkey', 'ciphertext');
        expect(result, 'nip04_plaintext');
      });
    });

    group('error handling', () {
      test('throws RpcException on error response', () async {
        mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'signing_failed'}), 200);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        expect(() => rpc.getPublicKey(), throwsA(isA<RpcException>()));
      });

      test('throws RpcException on HTTP error', () async {
        mockClient = MockClient((request) async {
          return http.Response('Server error', 500);
        });

        final rpc = KeycastRpc(
          nostrApi: 'https://login.divine.video/api/nostr',
          accessToken: 'test_token',
          httpClient: mockClient,
        );

        expect(() => rpc.getPublicKey(), throwsA(isA<RpcException>()));
      });
    });
  });
}

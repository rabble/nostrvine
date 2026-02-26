// ABOUTME: Live integration test for NIP-98 auth against relay.divine.video
// ABOUTME: Generates a real keypair, signs a proper event, and verifies
// the relay accepts our event format

@Tags(['integration'])
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';

/// Runs curl to make an HTTP request (bypasses Flutter's HTTP interception).
Future<(int, String)> curlGet(String url, String authHeader) async {
  final result = await Process.run('curl', [
    '-s',
    '-w',
    r'\n%{http_code}',
    '-H',
    'Authorization: $authHeader',
    '-H',
    'Accept: application/json',
    url,
  ]);
  final output = (result.stdout as String).trim();
  final lines = output.split('\n');
  final statusCode = int.parse(lines.last);
  final body = lines.length > 1
      ? lines.sublist(0, lines.length - 1).join('\n')
      : '';
  return (statusCode, body);
}

void main() {
  group('NIP-98 live relay test', () {
    late String privateKey;
    late String publicKey;

    setUp(() {
      privateKey = generatePrivateKey();
      publicKey = getPublicKey(privateKey);
    });

    /// Creates a signed NIP-98 auth event and returns the base64 token.
    String createSignedToken({
      required String url,
      required String method,
      bool includePayload = true,
    }) {
      final tags = <List<String>>[
        ['u', url],
        ['method', method],
      ];

      if (includePayload) {
        final payloadHash = sha256.convert(utf8.encode('')).toString();
        tags.add(['payload', payloadHash]);
      }

      final event = Event(publicKey, 27235, tags, '');
      event.sign(privateKey);
      expect(event.isSigned, isTrue, reason: 'Event must be signed');

      return base64Encode(utf8.encode(jsonEncode(event.toJson())));
    }

    test('WITH payload tag, query params in u tag -> accepted', () async {
      final url =
          'https://relay.divine.video/api/users/$publicKey/notifications'
          '?limit=1';
      final token = createSignedToken(url: url, method: 'GET');

      final (status, body) = await curlGet(url, 'Nostr $token');

      print('WITH payload, query params in u tag: $status $body');

      // 200 = empty notifications, 404 = user not found -> format accepted
      // 401 = auth format rejected
      expect(
        status,
        anyOf(200, 404),
        reason: 'Format should be accepted, got $status: $body',
      );
    });

    test('WITHOUT payload tag -> check relay behavior', () async {
      final url =
          'https://relay.divine.video/api/users/$publicKey/notifications';
      final token = createSignedToken(
        url: url,
        method: 'GET',
        includePayload: false,
      );

      final (status, body) = await curlGet('$url?limit=1', 'Nostr $token');

      print('WITHOUT payload tag: $status $body');
    });

    test('WITH query params in u tag -> check relay behavior', () async {
      final baseUrl =
          'https://relay.divine.video/api/users/$publicKey/notifications';
      final urlWithQuery = '$baseUrl?limit=1';
      final token = createSignedToken(url: urlWithQuery, method: 'GET');

      final (status, body) = await curlGet(urlWithQuery, 'Nostr $token');

      print('WITH query params in u tag: $status $body');
    });
  });
}

// ABOUTME: NIP-98 relay acceptance tests against the local funnelcake-api stack
// ABOUTME: Verifies the server accepts valid tokens and rejects invalid ones
//
// Requires the local Docker stack (port 47777).
// Run: flutter test test/manual/nip98_relay_acceptance_test.dart
// Start stack: mise run local_up (from repo root)
//
// Covers the acceptance criteria from issue #3052:
//   - Valid NIP-98 token accepted end-to-end
//   - Payload hash tag required for body-bearing requests
//   - Query parameters must be included in the u tag
//   - Expired created_at, wrong signature, mismatched method/url → 401

// Permanent: a manual, Docker-dependent real-network acceptance test that nulls
// HttpOverrides.global; VGV merged-isolate tests must keep flutter_test's HTTP
// mock intact.
@Tags(['skip_very_good_optimization', 'integration'])
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';

// Local-stack constants (funnelcake-proxy mapped to host port 47777).
const _localHost = 'localhost';
const _localRelayPort = 47777;
const _baseUrl = 'http://$_localHost:$_localRelayPort';
const _localStackUnavailableMessage =
    'Local stack is not running. Start with `mise run local_up`, then rerun '
    '`flutter test test/manual/nip98_relay_acceptance_test.dart`.';

void main() {
  late bool stackAvailable;
  late final HttpOverrides? previousHttpOverrides;

  setUpAll(() async {
    previousHttpOverrides = HttpOverrides.current;
    // flutter_test's binding stubs every HttpClient request to status 400 (to
    // catch accidental network use in unit tests). This is an intentional
    // real-network acceptance test, so opt out and let HttpClient do real I/O.
    HttpOverrides.global = null;

    stackAvailable = await _isPortOpen(_localHost, _localRelayPort);
  });

  tearDownAll(() {
    HttpOverrides.global = previousHttpOverrides;
  });

  group(
    'NIP-98 relay acceptance '
    '(POST /api/users/{pubkey}/notifications/read)',
    () {
      test('valid token with payload hash is accepted', () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final privKey = generatePrivateKey();
        final pubkey = getPublicKey(privKey);
        final url = '$_baseUrl/api/users/$pubkey/notifications/read';
        final body = _buildMarkReadBody();

        final authHeader = _buildNip98Token(
          privateKey: privKey,
          url: url,
          method: 'POST',
          body: body,
        );

        final status = await _postStatus(
          url: url,
          body: body,
          authHeader: authHeader,
        );

        expect(
          status,
          equals(HttpStatus.ok),
          reason: 'Valid NIP-98 token must be accepted by the relay.',
        );
      });

      test(
        'request without Authorization header is rejected with 401',
        () async {
          if (_skipIfStackUnavailable(stackAvailable)) return;

          final privKey = generatePrivateKey();
          final pubkey = getPublicKey(privKey);
          final url = '$_baseUrl/api/users/$pubkey/notifications/read';
          final body = _buildMarkReadBody();

          final status = await _postStatus(url: url, body: body);

          expect(status, equals(HttpStatus.unauthorized));
        },
      );

      test('expired created_at (>60 s) is rejected with 401', () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final privKey = generatePrivateKey();
        final pubkey = getPublicKey(privKey);
        final url = '$_baseUrl/api/users/$pubkey/notifications/read';
        final body = _buildMarkReadBody();

        // NIP-98: created_at must be within 60 s. Use 70 s ago.
        final staleTimestamp = DateTime.now().subtract(
          const Duration(seconds: 70),
        );
        final authHeader = _buildNip98Token(
          privateKey: privKey,
          url: url,
          method: 'POST',
          body: body,
          createdAt: staleTimestamp,
        );

        final status = await _postStatus(
          url: url,
          body: body,
          authHeader: authHeader,
        );

        expect(status, equals(HttpStatus.unauthorized));
      });

      test(
        'wrong method tag (GET instead of POST) is rejected with 401',
        () async {
          if (_skipIfStackUnavailable(stackAvailable)) return;

          final privKey = generatePrivateKey();
          final pubkey = getPublicKey(privKey);
          final url = '$_baseUrl/api/users/$pubkey/notifications/read';
          final body = _buildMarkReadBody();

          // Sign for GET (no payload tag) but send as POST.
          final authHeader = _buildNip98Token(
            privateKey: privKey,
            url: url,
            method: 'GET',
          );

          final status = await _postStatus(
            url: url,
            body: body,
            authHeader: authHeader,
          );

          expect(status, equals(HttpStatus.unauthorized));
        },
      );

      test(
        'POST body without payload hash tag is rejected with 401',
        () async {
          if (_skipIfStackUnavailable(stackAvailable)) return;

          final privKey = generatePrivateKey();
          final pubkey = getPublicKey(privKey);
          final url = '$_baseUrl/api/users/$pubkey/notifications/read';
          final body = _buildMarkReadBody();

          final authHeader = _buildNip98Token(
            privateKey: privKey,
            url: url,
            method: 'POST',
            body: body,
            includePayloadTag: false,
          );

          final status = await _postStatus(
            url: url,
            body: body,
            authHeader: authHeader,
          );

          expect(status, equals(HttpStatus.unauthorized));
        },
      );

      test('URL mismatch is rejected with 401', () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final privKey = generatePrivateKey();
        final pubkey = getPublicKey(privKey);
        final actualUrl = '$_baseUrl/api/users/$pubkey/notifications/read';
        // Sign for a different path.
        final signedUrl = '$_baseUrl/api/users/$pubkey/other-endpoint';
        final body = _buildMarkReadBody();

        final authHeader = _buildNip98Token(
          privateKey: privKey,
          url: signedUrl,
          method: 'POST',
          body: body,
        );

        final status = await _postStatus(
          url: actualUrl,
          body: body,
          authHeader: authHeader,
        );

        expect(status, equals(HttpStatus.unauthorized));
      });

      test('corrupted signature is rejected with 401', () async {
        if (_skipIfStackUnavailable(stackAvailable)) return;

        final privKey = generatePrivateKey();
        final pubkey = getPublicKey(privKey);
        final url = '$_baseUrl/api/users/$pubkey/notifications/read';
        final body = _buildMarkReadBody();

        final valid = _buildNip98Token(
          privateKey: privKey,
          url: url,
          method: 'POST',
          body: body,
        );
        final corrupted = _corruptSignature(valid);

        final status = await _postStatus(
          url: url,
          body: body,
          authHeader: corrupted,
        );

        expect(status, equals(HttpStatus.unauthorized));
      });
    },
  );

  group(
    'NIP-98 relay acceptance '
    '(GET /api/users/{pubkey}/notifications?...) — query-parameter URL',
    () {
      test(
        'u tag with full URL including query parameters is accepted',
        () async {
          if (_skipIfStackUnavailable(stackAvailable)) return;

          final privKey = generatePrivateKey();
          final pubkey = getPublicKey(privKey);
          final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final urlWithQuery =
              '$_baseUrl/api/users/$pubkey/notifications'
              '?limit=1&before=$before';

          // Per NIP-98 spec, u tag must contain the full URL including query
          // string. Fragment is excluded because it is never sent over HTTP.
          final authHeader = _buildNip98Token(
            privateKey: privKey,
            url: urlWithQuery,
            method: 'GET',
          );

          final status = await _getStatus(
            url: urlWithQuery,
            authHeader: authHeader,
          );

          expect(
            status,
            equals(HttpStatus.ok),
            reason:
                'NIP-98 token signed with full URL (including query params) '
                'must be accepted.',
          );
        },
      );

      test(
        'u tag without query string is rejected when URL has query params',
        () async {
          if (_skipIfStackUnavailable(stackAvailable)) return;

          final privKey = generatePrivateKey();
          final pubkey = getPublicKey(privKey);
          final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final urlWithQuery =
              '$_baseUrl/api/users/$pubkey/notifications'
              '?limit=1&before=$before';
          // Sign only the base path — query params stripped from u tag.
          final urlWithoutQuery = '$_baseUrl/api/users/$pubkey/notifications';

          final authHeader = _buildNip98Token(
            privateKey: privKey,
            url: urlWithoutQuery,
            method: 'GET',
          );

          final status = await _getStatus(
            url: urlWithQuery,
            authHeader: authHeader,
          );

          expect(
            status,
            equals(HttpStatus.unauthorized),
            reason:
                'u tag missing query string must not match the actual request '
                'URL — relay must reject with 401.',
          );
        },
      );
    },
  );
}

bool _skipIfStackUnavailable(bool stackAvailable) {
  if (stackAvailable) return false;

  markTestSkipped(_localStackUnavailableMessage);
  return true;
}

// ---------------------------------------------------------------------------
// NIP-98 token builder
// ---------------------------------------------------------------------------

/// Builds a `Nostr <base64>` Authorization header value for [url] and [method].
///
/// [body] is hashed and added as a `payload` tag for POST/PUT/PATCH requests.
/// [createdAt] defaults to now; pass a past value to produce a stale token.
String _buildNip98Token({
  required String privateKey,
  required String url,
  required String method,
  String? body,
  DateTime? createdAt,
  bool includePayloadTag = true,
}) {
  final pubKey = getPublicKey(privateKey);
  final ts = ((createdAt ?? DateTime.now()).millisecondsSinceEpoch / 1000)
      .round();

  final tags = <List<String>>[
    ['u', url],
    ['method', method],
    ['created_at', ts.toString()],
  ];

  final uppercaseMethod = method.toUpperCase();
  if (includePayloadTag &&
      body != null &&
      (uppercaseMethod == 'POST' ||
          uppercaseMethod == 'PUT' ||
          uppercaseMethod == 'PATCH')) {
    final payloadHash = sha256.convert(utf8.encode(body));
    tags.add(['payload', payloadHash.toString()]);
  }

  final event = Event(pubKey, 27235, tags, '', createdAt: ts);
  event.sign(privateKey);

  final eventJson = jsonEncode(event.toJson());
  final token = base64Encode(utf8.encode(eventJson));
  return 'Nostr $token';
}

/// Returns the JSON body for a mark-all-read request.
String _buildMarkReadBody() => jsonEncode({'notification_ids': <String>[]});

/// Flip one hex character in the Schnorr signature, producing a token whose
/// signature verification will fail while the rest of the structure remains
/// valid.
String _corruptSignature(String authHeader) {
  final base64Part = authHeader.substring('Nostr '.length);
  final decoded = utf8.decode(base64Decode(base64Part));
  final json = jsonDecode(decoded) as Map<String, dynamic>;
  final sig = json['sig'] as String;
  final last = sig[sig.length - 1];
  json['sig'] = '${sig.substring(0, sig.length - 1)}${last == 'a' ? 'b' : 'a'}';
  return 'Nostr ${base64Encode(utf8.encode(jsonEncode(json)))}';
}

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

Future<int> _getStatus({
  required String url,
  String? authHeader,
}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('Accept', 'application/json');
    if (authHeader != null) {
      request.headers.set('Authorization', authHeader);
    }
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close();
  }
}

Future<int> _postStatus({
  required String url,
  String? body,
  String? authHeader,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(Uri.parse(url));
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    if (authHeader != null) {
      request.headers.set('Authorization', authHeader);
    }
    if (body != null) {
      request.write(body);
    }
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close();
  }
}

/// Returns `true` when [host]:[port] accepts a TCP connection within 2 s.
Future<bool> _isPortOpen(String host, int port) async {
  try {
    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 2),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

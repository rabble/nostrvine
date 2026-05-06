// ABOUTME: Unit tests for redactHttpHeadersForLogs via openvine re-export (#3360).
// ABOUTME: Authorization and Nostr NIP-98 style headers must not leak in logs.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/sensitive_http_headers_for_logs.dart';

/// Issue #3360 / plan §5 — header redaction: `Authorization`, `Nostr` prefix.
void main() {
  group('redactHttpHeadersForLogs', () {
    group('AC #3360 — Authorization and Nostr', () {
      test('redacts Bearer Authorization regardless of length', () {
        final longToken = List.filled(400, 'Z').join();
        final out = redactHttpHeadersForLogs({
          'Authorization': 'Bearer $longToken',
          'Content-Type': 'application/json',
        });
        expect(out['Authorization'], redactedSensitiveLogPlaceholder);
        expect(out['Authorization'], isNot(contains(longToken)));
        expect(out['Content-Type'], 'application/json');
      });

      test('redacts Nostr-prefixed Authorization with long base64 payload', () {
        final payload = base64Encode(utf8.encode('${'x' * 300}payload'));
        final raw = 'Nostr $payload';
        final out = redactHttpHeadersForLogs({'Authorization': raw});
        expect(out['Authorization'], 'Nostr $redactedSensitiveLogPlaceholder');
        expect(out['Authorization'], isNot(contains(payload)));
        expect(out['Authorization']!.length, lessThan(raw.length));
      });

      test(
        'redacts Nostr-prefixed Authorization leaving label (short payload)',
        () {
          final out = redactHttpHeadersForLogs({
            'authorization': 'Nostr c29tZV9wYXlsb2Fk',
          });
          expect(
            out['authorization'],
            'Nostr $redactedSensitiveLogPlaceholder',
          );
          expect(out['authorization'], isNot(contains('c29tZV9wYXlsb2Fk')));
        },
      );

      test('treats leading whitespace before Nostr prefix', () {
        final out = redactHttpHeadersForLogs({
          'Authorization': '  Nostr payloadhere',
        });
        expect(out['Authorization'], 'Nostr $redactedSensitiveLogPlaceholder');
      });

      test('only touches Authorization keys (case-insensitive)', () {
        final out = redactHttpHeadersForLogs({
          'X-Custom-Auth': 'keep-me',
          'AUTHORIZATION': 'Basic secret',
        });
        expect(out['X-Custom-Auth'], 'keep-me');
        expect(out['AUTHORIZATION'], redactedSensitiveLogPlaceholder);
      });
    });
  });
}

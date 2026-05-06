// ABOUTME: Unit tests for nostr_sdk redactHttpHeadersForLogs (#3360).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/utils/redact_http_headers_for_logs.dart';

void main() {
  group('redactHttpHeadersForLogs', () {
    test('redacts Authorization bearer-style values', () {
      final out = redactHttpHeadersForLogs({
        'Authorization': 'Bearer super_secret_token',
        'Content-Type': 'application/json',
      });
      expect(out['Authorization'], redactedSensitiveLogPlaceholder);
      expect(out['Content-Type'], 'application/json');
    });

    test('redacts long Bearer token entirely', () {
      final longToken = List.filled(400, 'Z').join();
      final out = redactHttpHeadersForLogs({
        'Authorization': 'Bearer $longToken',
      });
      expect(out['Authorization'], redactedSensitiveLogPlaceholder);
      expect(out['Authorization'], isNot(contains(longToken)));
    });

    test('redacts Nostr-prefixed Authorization leaving label', () {
      final out = redactHttpHeadersForLogs({
        'authorization': 'Nostr c29tZV9wYXlsb2Fk',
      });
      expect(out['authorization'], 'Nostr $redactedSensitiveLogPlaceholder');
      expect(out['authorization'], isNot(contains('c29tZV9wYXlsb2Fk')));
    });

    test('redacts long Nostr base64 payload', () {
      final payload = base64Encode(utf8.encode('${'x' * 300}payload'));
      final raw = 'Nostr $payload';
      final out = redactHttpHeadersForLogs({'Authorization': raw});
      expect(out['Authorization'], 'Nostr $redactedSensitiveLogPlaceholder');
      expect(out['Authorization'], isNot(contains(payload)));
    });

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
}

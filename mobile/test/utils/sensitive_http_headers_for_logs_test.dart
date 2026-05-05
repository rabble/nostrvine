import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/sensitive_http_headers_for_logs.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';

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

    test('redacts Nostr-prefixed Authorization leaving label', () {
      final out = redactHttpHeadersForLogs({
        'authorization': 'Nostr c29tZV9wYXlsb2Fk',
      });
      expect(out['authorization'], 'Nostr $redactedSensitiveLogPlaceholder');
      expect(out['authorization'], isNot(contains('c29tZV9wYXlsb2Fk')));
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

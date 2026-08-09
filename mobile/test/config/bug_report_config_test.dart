// ABOUTME: Pins sanitizeDiagnosticText against both failure directions:
// ABOUTME: missed credentials in serialized payloads, and shredded user prose.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/bug_report_config.dart';

void main() {
  group('sanitizeDiagnosticText', () {
    group('redacts credentials', () {
      // Serialized shapes are how credentials actually reach the log buffer,
      // so a quote between the key and the separator must not defeat the rule.
      const cases = <String, String>{
        'json password': '{"password":"hunter2"}',
        'json token': '{"token":"eyJhbGciOi"}',
        'json suffixed key': '{"access_token":"eyJhbGciOi"}',
        'json bearer header': '{"Authorization":"Bearer eyJhbGciOi"}',
        'dart map bearer header': "{'Authorization': 'Bearer eyJhbGciOi'}",
        'basic header': 'Authorization: Basic YWJjOmRlZmc=',
        'bearer header': 'Authorization: Bearer eyJhbGciOi',
        'colon separated': 'password: hunter2',
        'equals separated': 'secret=abc123',
        'underscored key': 'secret_key: abc123',
        'nip46 bunker secret': 'bunker://relay.example?secret=deadbeef',
      };

      for (final entry in cases.entries) {
        test(entry.key, () {
          final sanitized = sanitizeDiagnosticText(entry.value);

          expect(sanitized, contains('[REDACTED]'));
          for (final leaked in [
            'hunter2',
            'eyJhbGciOi',
            'abc123',
            'deadbeef',
            'YWJjOmRlZmc=',
          ]) {
            expect(sanitized, isNot(contains(leaked)));
          }
        });
      }
    });

    group('preserves ordinary prose', () {
      // These are real bug-report sentences. A keyword alone is not a secret,
      // so redacting the following word would destroy the reported symptom.
      const cases = <String>[
        'Password reset failed',
        'my password reset email never arrives',
        'the login token expired instantly and I got logged out',
        'Secret DMs are not decrypting',
        'Token refresh scheduled\nnext line here',
      ];

      for (final input in cases) {
        test(input.replaceAll('\n', ' / '), () {
          expect(sanitizeDiagnosticText(input), equals(input));
        });
      }
    });

    test('still redacts nostr private keys', () {
      const nsec =
          'nsec1qqqsyrhq4p4d8hf40q7tlujzw87hqhz9axhfnm35s2a3u3rrnwsq9sp5p6';
      const ncryptsec = 'ncryptsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq';

      expect(sanitizeDiagnosticText('key $nsec'), isNot(contains(nsec)));
      expect(
        sanitizeDiagnosticText('key $ncryptsec'),
        isNot(contains(ncryptsec)),
      );
    });
  });
}

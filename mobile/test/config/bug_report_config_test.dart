// ABOUTME: Pins sanitizeDiagnosticText against all three failure directions:
// ABOUTME: missed credentials, partially-redacted secrets, and shredded prose.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/bug_report_config.dart';

/// Fragments that must never survive sanitization. Asserting on these rather
/// than only on the presence of `[REDACTED]` is what catches *partial*
/// redaction: half a secret next to a redaction marker is worse than no
/// redaction, because the marker reads as proof the value was handled.
const _secretFragments = [
  'hunter2',
  'eyJhbGciOi',
  'abc123',
  'deadbeef',
  'YWJjOmRlZmc=',
  'correct horse battery staple',
  'beta gamma',
  'alpha',
  'Alice',
];

void main() {
  group('sanitizeDiagnosticText', () {
    group('redacts the whole credential value', () {
      // Serialized shapes are how credentials actually reach the log buffer,
      // so a quote between the key and the separator must not defeat the rule,
      // and a quoted value must be consumed to its closing quote.
      const cases = <String, String>{
        'quoted multi-word value':
            '{"password":"correct horse battery staple"}',
        'quoted value with comma': '{"password":"alpha,beta"}',
        'quoted value with escaped double quote':
            r'{"password":"alpha\"beta gamma"}',
        'quoted value with escaped single quote':
            r"{'password': 'alpha\'beta gamma'}",
        'quoted scheme-prefixed value': '{"token":"Bearer eyJhbGciOi"}',
        'unquoted scheme-prefixed value': 'Auth token: Bearer eyJhbGciOi',
        'fat arrow separator': 'password => hunter2',
        'json api key': '{"api_key":"abc123"}',
        'camel case api key': "{'apiKey': 'abc123'}",
        'hyphenated api key': '{"x-api-key":"abc123"}',
        'json private key': '{"private_key":"abc123"}',
        'underscored secret key': 'secret_key: abc123',
        'screaming snake compound key': 'AWS_SECRET_ACCESS_KEY=deadbeef',
        'underscored compound key': 'password_confirmation: hunter2',
        'camel case compound key': 'passwordHash: hunter2',
        'camel case json key': '{"tokenValue":"eyJhbGciOi"}',
        'enumerated word at end of key': 'clientSecret: deadbeef',
        'json access token': '{"access_token":"eyJhbGciOi"}',
        'json refresh token': '{"refresh_token":"eyJhbGciOi"}',
        'json bearer header': '{"Authorization":"Bearer eyJhbGciOi"}',
        'dart map bearer header': "{'Authorization': 'Bearer eyJhbGciOi'}",
        'basic header': 'Authorization: Basic YWJjOmRlZmc=',
        'bearer header': 'Authorization: Bearer eyJhbGciOi',
        'header with no scheme word': 'Authorization: abc123def',
        'colon separated': 'password: hunter2',
        'equals separated': 'secret=abc123',
        'nip46 bunker secret': 'bunker://relay.example?secret=deadbeef',
      };

      for (final entry in cases.entries) {
        test(entry.key, () {
          final sanitized = sanitizeDiagnosticText(entry.value);

          expect(sanitized, contains('[REDACTED]'));
          for (final fragment in _secretFragments) {
            expect(
              sanitized,
              isNot(contains(fragment)),
              reason: 'leaked "$fragment" from ${entry.value}',
            );
          }
        });
      }
    });

    test('an unbalanced quote costs one word, not the rest of the report', () {
      // A quoted branch that tolerated a missing closing quote would run to
      // the end of the payload, so a user typing `password: "test1` into
      // steps-to-reproduce would silently delete every field printed after it.
      const payload =
          '1. enter password: "test1\n'
          '[10:00] [INFO] feed loaded 42 videos\n'
          '[10:01] [ERROR] upload failed: connection reset';

      final sanitized = sanitizeDiagnosticText(payload);

      expect(sanitized, contains('[REDACTED]'));
      expect(sanitized, isNot(contains('test1')));
      expect(sanitized, contains('feed loaded 42 videos'));
      expect(sanitized, contains('upload failed: connection reset'));
    });

    group('preserves diagnostic signal', () {
      // Keys that merely start with a credential word, and prose that merely
      // uses one. Redacting these costs the reported symptom for no privacy
      // gain - the failure mode that makes a support ticket useless.
      const cases = <String>[
        '{"tokenization":"failed"}',
        '{"passwordless":true}',
        '{"secretary":"Alice"}',
        'Tokenization: failed',
        'Password reset failed',
        'my password reset email never arrives',
        'the login token expired instantly and I got logged out',
        'Secret DMs are not decrypting',
        'Token refresh scheduled',
      ];

      for (final input in cases) {
        test(input, () {
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

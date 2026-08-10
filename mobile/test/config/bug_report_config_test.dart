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
  'eyJabcdefghijk',
  'eyJdefghijkl',
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
        'json token array': '{"token":["eyJabcdefghijk","eyJdefghijkl"]}',
        'authorization header array':
            '"Authorization": ["Bearer eyJabcdefghijk"]',
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
        'pascal case compound key': 'PasswordHash: hunter2',
        'pascal case json key': '{"TokenValue":"eyJhbGciOi"}',
        'enumerated word at end of key': 'clientSecret: deadbeef',
        'passphrase alias': 'passphrase=hunter2',
        'plural password key': 'passwords=hunter2',
        'passcode alias': 'passcode: hunter2',
        'pwd alias': 'pwd=hunter2',
        'plural token key': '{"tokens":["eyJabcdefghijk"]}',
        'plural secret key': 'secrets: hunter2',
        'plural api key': 'apiKeys: abc123',
        'generic signing key': 'signing_key: abc123',
        'generic encryption key': 'encryption_key=abc123',
        'screaming snake generic key': 'ENCRYPTION_KEY=deadbeef',
        'generic hyphenated key': 'master-key=hunter2',
        'generic camel case key': 'recoveryKey=abc123',
        'camel case session key': 'sessionKey: abc123',
        'camel case json key name': '{"signingKey":"abc123"}',
        'run-together api key': 'apikey: abc123',
        // A 64-char hex value is deliberately not redacted, so for hex-form
        // private keys the key *name* is the only thing standing between the
        // secret and a public ticket. `privateKeyHex` and `rawKeyHex` are the
        // spellings this repo actually uses, 122 and 112 times respectively.
        'camel case key with suffix': 'privateKeyHex: aabbccdd',
        'nested camel case key with suffix': 'senderPrivateKeyHex: aabbccdd',
        'raw camel case key with suffix': 'rawKeyHex: aabbccdd',
        // Plurals hide a credential exactly as well as singulars, and the
        // enumerated words already accept `s`. Without the same `s` on the two
        // `key` rules, `privateKey` is covered and `privateKeys` is not.
        'plural generic key': 'signing_keys: abc123',
        'plural camel case key': 'sessionKeys: abc123',
        'plural camel case private key': 'privateKeys: ["aabbccdd"]',
        'plural screaming snake generic key': 'ENCRYPTION_KEYS=deadbeef',
        // A braced value must be consumed to its closing brace for the same
        // reason a bracketed one is: otherwise the rule redacts `{"` and
        // leaves the secret sitting next to the `[REDACTED]` marker.
        'json object value': '{"token":{"value":"eyJhbGciOi"}}',
        'json object secret value': '{"secret":{"nested":"hunter2"}}',
        'acronym-prefixed key': 'AESKey: abc123',
        'hmac key': 'HMACKey=deadbeef',
        'pwd compound key': 'pwdHash: deadbeef',
        'pascal pwd compound key': 'PwdValue=hunter2',
        'yaml doubled single quote': "password: 'alpha''beta gamma'",
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

    test('a long compound key cannot be made to backtrack exponentially', () {
      // An ambiguous segment class (`(?:[_-]\w+)*`, where `\w` also matches
      // `_`) parses the same key 2^n ways and explores all of them before
      // failing for want of a separator. That runs on the UI thread, per log
      // entry, over text that can come from a remote profile name or an
      // attacker-typed report field.
      //
      // 28 segments is chosen so a reintroduced ambiguity fails this in ~17s
      // (measured) rather than hanging the suite, which is what a larger
      // exponent would do. Unambiguous classes run it in ~0ms.
      final stopwatch = Stopwatch()..start();
      for (final key in ['token${'_a' * 28}', 'token${'Aa' * 28}']) {
        sanitizeDiagnosticText(key);
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    group('preserves diagnostic signal', () {
      // Keys that merely start with a credential word, and prose that merely
      // uses one. Redacting these costs the reported symptom for no privacy
      // gain - the failure mode that makes a support ticket useless.
      const cases = <String>[
        // The signed-in public key is deliberately kept: support needs it to
        // connect a report to an account, and it is public by construction.
        'pubkey: npubxyz123',
        '**User Pubkey:** npub1abcdef',
        '{"user_pubkey":"abc123def"}',
        'pub_key: npub1abc',
        'public_key: npub1abc',
        'publicKey: npub1abc',
        'PublicKey: npub1abc',
        'recipientPublicKey: npub1abc',
        'theirPubKey: npub1abc',
        'pubkeyHex: abc123def',
        'user_pubkeyHex: abc123def',
        // Plural public-key spellings are the most common identifiers in this
        // repo (`pubkeys` alone appears ~900 times); the `s` on the key rules
        // must not reach past the public-key guards.
        'pubkeys: [npub1abc]',
        'participantPubkeys: [npub1abc]',
        'publicKeys: [npub1abc]',
        'pub_keys: [npub1abc]',
        'physicalKeys: {KeyA}',
        // Bare `key` is an ordinary English word. These are real in-repo
        // strings: an l10n error message, a model's toString, and Flutter key
        // events - none of them carry a credential.
        'Failed to import key: SomeError at 0',
        'ClipChromaKey(key: green, backgroundVideoPath: x)',
        'KeyEvent: KeyDownEvent',
        // Flutter's KeyEvent.toString() prints these; never credentials.
        'KeyDownEvent(physicalKey: keyA, logicalKey: keyA, character: x)',
        'keyLabel: a',
        'KeyValue: 42',
        'Cache key: video_123',
        'monkey: banana',
        'hotkey: ctrl',
        'keyboard: qwerty',
        '{"secretaryName":"Alice"}',
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

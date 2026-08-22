// ABOUTME: Tests for pubkeyForLogs, the npub+hex renderer used by log sinks.
// ABOUTME: Pins the no-truncation contract and the non-throwing fallbacks.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';

void main() {
  group('pubkeyForLogs', () {
    const hex =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
    const npub =
        'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';

    group('valid hex pubkey', () {
      test('renders the full npub followed by the full hex', () {
        expect(pubkeyForLogs(hex), equals('$npub ($hex)'));
      });

      test('carries both identifiers whole', () {
        final rendered = pubkeyForLogs(hex);

        expect(rendered, contains(hex));
        expect(rendered, contains(npub));
      });

      test('accepts uppercase hex and renders the canonical npub', () {
        expect(pubkeyForLogs(hex.toUpperCase()), contains(npub));
      });
    });

    group('values that cannot be encoded', () {
      test('returns a marker for null', () {
        expect(pubkeyForLogs(null), equals('<null>'));
      });

      test('returns a marker for an empty string', () {
        expect(pubkeyForLogs(''), equals('<empty>'));
      });

      test('returns an npub unchanged rather than double-encoding it', () {
        expect(pubkeyForLogs(npub), equals(npub));
      });

      test('returns a short hex unchanged and whole', () {
        expect(pubkeyForLogs('3bf0c63f'), equals('3bf0c63f'));
      });

      test('returns a non-hex value unchanged and whole', () {
        expect(pubkeyForLogs('not-a-pubkey'), equals('not-a-pubkey'));
      });

      test('returns a 64-char non-hex value unchanged and whole', () {
        final notHex = 'z' * 64;

        expect(pubkeyForLogs(notHex), equals(notHex));
      });
    });

    group('log-sink safety', () {
      test('never throws for arbitrary input', () {
        const inputs = <String?>[
          null,
          '',
          ' ',
          '0',
          'npub1invalid',
          'nsec1definitelynotapubkey',
          '////',
        ];

        for (final input in inputs) {
          expect(() => pubkeyForLogs(input), returnsNormally, reason: '$input');
        }
      });

      test('a fallback value is never shortened', () {
        final long = 'q' * 200;

        expect(pubkeyForLogs(long), equals(long));
      });
    });

    group('round trip', () {
      test('the rendered npub decodes back to the hex it was built from', () {
        final rendered = pubkeyForLogs(hex);
        final encoded = rendered.split(' ').first;

        expect(Nip19.decode(encoded), equals(hex));
      });
    });
  });
}

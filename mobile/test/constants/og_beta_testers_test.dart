// ABOUTME: Verifies the frozen OG beta tester roster and its lookup helper.
// ABOUTME: Guards roster shape so a bad regeneration cannot ship silently.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/og_beta_testers.dart';

void main() {
  group('ogBetaTesterPubkeys', () {
    test('contains only lowercase 64-character hex pubkeys', () {
      final hex = RegExp(r'^[0-9a-f]{64}$');
      final malformed = ogBetaTesterPubkeys.where(
        (pubkey) => !hex.hasMatch(pubkey),
      );

      expect(malformed, isEmpty);
    });

    test('contains no duplicates', () {
      expect(
        ogBetaTesterPubkeys.toSet(),
        hasLength(ogBetaTesterPubkeys.length),
      );
    });

    test('is sorted so regenerated rosters produce reviewable diffs', () {
      final sorted = ogBetaTesterPubkeys.toList()..sort();

      expect(ogBetaTesterPubkeys, equals(sorted));
    });
  });

  group('isOgBetaTester', () {
    test('returns true for a pubkey on the roster', () {
      expect(isOgBetaTesterPubkey(ogBetaTesterPubkeys.first), isTrue);
      expect(isOgBetaTesterPubkey(ogBetaTesterPubkeys.last), isTrue);
    });

    test('returns false for a pubkey that is not on the roster', () {
      expect(isOgBetaTesterPubkey('f' * 64), isFalse);
    });

    test('matches regardless of case', () {
      expect(
        isOgBetaTesterPubkey(ogBetaTesterPubkeys.first.toUpperCase()),
        isTrue,
      );
    });

    test('tolerates surrounding whitespace', () {
      expect(isOgBetaTesterPubkey('  ${ogBetaTesterPubkeys.first}  '), isTrue);
    });

    test('returns false for an empty or blank pubkey', () {
      expect(isOgBetaTesterPubkey(''), isFalse);
      expect(isOgBetaTesterPubkey('   '), isFalse);
    });
  });
}

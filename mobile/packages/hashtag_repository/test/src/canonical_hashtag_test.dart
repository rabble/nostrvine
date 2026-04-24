// ABOUTME: Unit tests for canonical hashtag normalization (divine-web parity).

import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';

void main() {
  group('normalizeHashtagLabel', () {
    test('matches divine-web: trim, leading #, lower case', () {
      expect(normalizeHashtagLabel('  #Vine  '), 'vine');
      expect(normalizeHashtagLabel('##openvine'), 'openvine');
      expect(normalizeHashtagLabel('#'), '');
      expect(normalizeHashtagLabel('Nostr'), 'nostr');
    });
  });

  group('formatHashtagForDisplay', () {
    test('adds single hash and handles empty', () {
      expect(formatHashtagForDisplay('vine'), '#vine');
      expect(formatHashtagForDisplay(''), '#');
    });

    test('strips existing leading hashes before prefixing', () {
      expect(formatHashtagForDisplay('#dup'), '#dup');
      expect(formatHashtagForDisplay('##dup'), '#dup');
    });
  });
}

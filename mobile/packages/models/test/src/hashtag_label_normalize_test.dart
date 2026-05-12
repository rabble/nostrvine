import 'package:models/src/hashtag_label_normalize.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeHashtagLabel', () {
    test('trim, leading hash marks, lower case', () {
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

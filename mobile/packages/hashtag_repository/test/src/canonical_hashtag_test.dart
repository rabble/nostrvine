import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:test/test.dart';

void main() {
  group('canonical hashtag API (re-exported from models)', () {
    test('normalizeHashtagLabel is available via package export', () {
      expect(normalizeHashtagLabel('  #Tag  '), 'tag');
    });

    test('formatHashtagForDisplay is available via package export', () {
      expect(formatHashtagForDisplay('tag'), '#tag');
    });
  });
}

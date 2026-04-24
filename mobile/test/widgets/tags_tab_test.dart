import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/tags_tab.dart';

void main() {
  group('hashtagDiscoveryMatchesFilter', () {
    test('empty query matches any hashtag', () {
      expect(hashtagDiscoveryMatchesFilter('cats', ''), isTrue);
      expect(hashtagDiscoveryMatchesFilter('cats', '   '), isTrue);
    });

    test('matches substring case-insensitively', () {
      expect(hashtagDiscoveryMatchesFilter('Cats', 'cat'), isTrue);
      expect(hashtagDiscoveryMatchesFilter('vine', 'VIN'), isTrue);
    });

    test('non-matching query returns false', () {
      expect(hashtagDiscoveryMatchesFilter('cats', 'dog'), isFalse);
    });
  });
}

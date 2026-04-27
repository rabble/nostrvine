import 'package:flutter_test/flutter_test.dart';

/// Returns whether [hashtag] should appear when the user types [query]
/// (trimmed, case-insensitive substring match; empty query matches all).
bool hashtagDiscoveryMatchesFilter(String hashtag, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return hashtag.toLowerCase().contains(q);
}

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

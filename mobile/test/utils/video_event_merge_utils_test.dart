// ABOUTME: Unit tests for shared profile/enrichment tag merge (#3384).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/video_event_merge_utils.dart';

void main() {
  group('mergeVideoRawTagsPrimaryWins', () {
    test('primary wins on ordinary keys; views uses max', () {
      final merged = mergeVideoRawTagsPrimaryWins(
        {'d': 'x', 'title': 'Nostr', 'views': '0'},
        {'d': 'x', 'views': '100', 'k': 'rest-only'},
      );
      expect(merged['title'], equals('Nostr'));
      expect(merged['k'], equals('rest-only'));
      expect(merged['views'], equals('100'));
    });
  });

  group('mergeNullableEngagementMax', () {
    test('null handling and max with zero', () {
      expect(mergeNullableEngagementMax(null, null), isNull);
      expect(mergeNullableEngagementMax(0, 9), equals(9));
      expect(mergeNullableEngagementMax(9, 0), equals(9));
    });
  });
}

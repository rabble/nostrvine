// ABOUTME: Regression coverage for the extractEngagementCountTags helper.
// ABOUTME: Verifies the extraction contract for loops/likes/reposts/views/comments
// ABOUTME: tags that must be preserved when video metadata is edited.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_metadata_update_service.dart';

void main() {
  group('extractEngagementCountTags()', () {
    test('extracts all five engagement tag types', () {
      final tags = [
        ['loops', '850000'],
        ['likes', '12000'],
        ['reposts', '3400'],
        ['views', '1000000'],
        ['comments', '4200'],
        ['title', 'Should be ignored'],
        ['t', 'hashtag'],
      ];
      final result = extractEngagementCountTags(tags);
      expect(result, hasLength(5));
      expect(result.map((t) => t[0]).toSet(), {
        'loops',
        'likes',
        'reposts',
        'views',
        'comments',
      });
    });

    test('preserves tag values exactly', () {
      final tags = [
        ['loops', '42'],
        ['comments', '7'],
      ];
      final result = extractEngagementCountTags(tags);
      expect(result, contains(equals(['loops', '42'])));
      expect(result, contains(equals(['comments', '7'])));
    });

    test('skips tags with no value', () {
      final tags = [
        ['loops'],
        ['likes', '5'],
      ];
      expect(extractEngagementCountTags(tags), hasLength(1));
    });

    test('returns empty list when no engagement tags are present', () {
      final tags = [
        ['d', 'abc'],
        ['title', 'My Video'],
      ];
      expect(extractEngagementCountTags(tags), isEmpty);
    });
  });
}

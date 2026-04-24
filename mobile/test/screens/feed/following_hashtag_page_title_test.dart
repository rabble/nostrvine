import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/following_hashtag_page_title.dart';

void main() {
  group('followingHashtagTitleForLabels', () {
    test('empty set yields empty string', () {
      expect(followingHashtagTitleForLabels({}), '');
    });

    test('single label is formatted with hash', () {
      expect(followingHashtagTitleForLabels({'cats'}), '#cats');
    });

    test('two labels joined with space', () {
      expect(
        followingHashtagTitleForLabels({'b', 'a'}),
        '#a #b',
      );
    });

    test('more than two shows +N', () {
      expect(
        followingHashtagTitleForLabels({'c', 'a', 'b'}),
        '#a #b +1',
      );
    });
  });
}

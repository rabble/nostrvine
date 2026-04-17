// ABOUTME: Tests feed auto-advance next/paginate/wrap decisions.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/feed_auto_advance_policy.dart';

void main() {
  group('decideFeedAutoAdvance', () {
    test('returns noop for an empty feed', () {
      final instruction = decideFeedAutoAdvance(
        currentIndex: 0,
        itemCount: 0,
        hasMore: false,
        isLoadingMore: false,
      );

      expect(instruction, FeedAutoAdvanceInstruction.noop);
    });

    test('returns next when another loaded item exists', () {
      final instruction = decideFeedAutoAdvance(
        currentIndex: 0,
        itemCount: 3,
        hasMore: true,
        isLoadingMore: false,
      );

      expect(instruction, FeedAutoAdvanceInstruction.next);
    });

    test('returns paginate at the end when more content is available', () {
      final instruction = decideFeedAutoAdvance(
        currentIndex: 2,
        itemCount: 3,
        hasMore: true,
        isLoadingMore: false,
      );

      expect(instruction, FeedAutoAdvanceInstruction.paginate);
    });

    test('returns wrap when the feed is exhausted', () {
      final instruction = decideFeedAutoAdvance(
        currentIndex: 2,
        itemCount: 3,
        hasMore: false,
        isLoadingMore: false,
      );

      expect(instruction, FeedAutoAdvanceInstruction.wrap);
    });

    test('returns noop while a load more is already in flight', () {
      final instruction = decideFeedAutoAdvance(
        currentIndex: 2,
        itemCount: 3,
        hasMore: true,
        isLoadingMore: true,
      );

      expect(instruction, FeedAutoAdvanceInstruction.noop);
    });
  });
}

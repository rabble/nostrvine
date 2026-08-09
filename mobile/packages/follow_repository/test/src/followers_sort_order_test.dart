// ABOUTME: Unit tests for FollowersSortOrder
// ABOUTME: Tests how each order rearranges the repository's newest-first list

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/src/followers_sort_order.dart';

void main() {
  group(FollowersSortOrder, () {
    // As FollowRepository hands it over: newest first, undated tail last.
    const newestFirst = ['newest', 'middle', 'oldest', 'undatedA', 'undatedB'];

    group('apply', () {
      test('leaves the list untouched for newestFirst', () {
        expect(
          FollowersSortOrder.newestFirst.apply(newestFirst, datedCount: 3),
          same(newestFirst),
        );
      });

      test('flips the dated prefix for oldestFirst', () {
        expect(
          FollowersSortOrder.oldestFirst.apply(newestFirst, datedCount: 3),
          equals(['oldest', 'middle', 'newest', 'undatedA', 'undatedB']),
        );
      });

      test('keeps undated followers last in both directions', () {
        final flipped = FollowersSortOrder.oldestFirst.apply(
          newestFirst,
          datedCount: 3,
        );

        // "We don't know when" must not read as "a long time ago" and jump
        // the queue when the user asks for the oldest follower first.
        expect(flipped.sublist(3), equals(['undatedA', 'undatedB']));
      });

      test('leaves an all-undated list alone', () {
        expect(
          FollowersSortOrder.oldestFirst.apply(newestFirst, datedCount: 0),
          equals(newestFirst),
        );
      });

      test('flips the whole list when every follower is dated', () {
        expect(
          FollowersSortOrder.oldestFirst.apply(
            const ['a', 'b', 'c'],
            datedCount: 3,
          ),
          equals(['c', 'b', 'a']),
        );
      });

      test('clamps a datedCount that overruns the list', () {
        expect(
          FollowersSortOrder.oldestFirst.apply(
            const ['a', 'b'],
            datedCount: 7,
          ),
          equals(['b', 'a']),
        );
      });

      test('clamps a negative datedCount', () {
        expect(
          FollowersSortOrder.oldestFirst.apply(
            const ['a', 'b'],
            datedCount: -1,
          ),
          equals(['a', 'b']),
        );
      });

      test('handles an empty list', () {
        expect(
          FollowersSortOrder.oldestFirst.apply(const [], datedCount: 0),
          isEmpty,
        );
      });
    });
  });
}

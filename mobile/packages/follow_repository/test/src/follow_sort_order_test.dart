// ABOUTME: Unit tests for FollowSortOrder
// ABOUTME: Tests how each order rearranges the followers and following lists

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/src/follow_sort_order.dart';

void main() {
  group(FollowSortOrder, () {
    group('fromNewestFirst', () {
      // As FollowRepository hands it over: newest first, undated tail last.
      const newestFirst = [
        'newest',
        'middle',
        'oldest',
        'undatedA',
        'undatedB',
      ];

      test('leaves the order untouched for newestFirst', () {
        expect(
          FollowSortOrder.newestFirst.fromNewestFirst(
            newestFirst,
            datedCount: 3,
          ),
          equals(newestFirst),
        );
      });

      test('hands back a copy rather than the caller list', () {
        expect(
          FollowSortOrder.newestFirst.fromNewestFirst(
            newestFirst,
            datedCount: 3,
          ),
          isNot(same(newestFirst)),
        );
      });

      test('flips the dated prefix for oldestFirst', () {
        expect(
          FollowSortOrder.oldestFirst.fromNewestFirst(
            newestFirst,
            datedCount: 3,
          ),
          equals(['oldest', 'middle', 'newest', 'undatedA', 'undatedB']),
        );
      });

      test('keeps undated followers last in both directions', () {
        final flipped = FollowSortOrder.oldestFirst.fromNewestFirst(
          newestFirst,
          datedCount: 3,
        );

        // "We don't know when" must not read as "a long time ago" and jump
        // the queue when the user asks for the oldest follower first.
        expect(flipped.sublist(3), equals(['undatedA', 'undatedB']));
      });

      test('leaves an all-undated list alone', () {
        expect(
          FollowSortOrder.oldestFirst.fromNewestFirst(
            newestFirst,
            datedCount: 0,
          ),
          equals(newestFirst),
        );
      });

      test('flips the whole list when every follower is dated', () {
        expect(
          FollowSortOrder.oldestFirst.fromNewestFirst(
            const ['a', 'b', 'c'],
            datedCount: 3,
          ),
          equals(['c', 'b', 'a']),
        );
      });

      test('clamps a datedCount that overruns the list', () {
        expect(
          FollowSortOrder.oldestFirst.fromNewestFirst(
            const ['a', 'b'],
            datedCount: 7,
          ),
          equals(['b', 'a']),
        );
      });

      test('clamps a negative datedCount', () {
        expect(
          FollowSortOrder.oldestFirst.fromNewestFirst(
            const ['a', 'b'],
            datedCount: -1,
          ),
          equals(['a', 'b']),
        );
      });

      test('handles an empty list', () {
        expect(
          FollowSortOrder.oldestFirst.fromNewestFirst(const [], datedCount: 0),
          isEmpty,
        );
      });
    });

    group('fromFollowOrder', () {
      // As FollowRepository hands it over: the contact list's `p` tags
      // verbatim, so the follow the user added first leads.
      const followOrder = ['first', 'second', 'third'];

      test('leaves the order untouched for oldestFirst', () {
        expect(
          FollowSortOrder.oldestFirst.fromFollowOrder(followOrder),
          equals(followOrder),
        );
      });

      test('hands back a copy rather than the caller list', () {
        expect(
          FollowSortOrder.oldestFirst.fromFollowOrder(followOrder),
          isNot(same(followOrder)),
        );
      });

      test('reverses follow order for newestFirst', () {
        expect(
          FollowSortOrder.newestFirst.fromFollowOrder(followOrder),
          equals(['third', 'second', 'first']),
        );
      });

      test('does not mutate the list it was given', () {
        final source = [...followOrder];

        FollowSortOrder.newestFirst.fromFollowOrder(source);

        expect(source, equals(followOrder));
      });

      test('handles an empty list', () {
        expect(FollowSortOrder.newestFirst.fromFollowOrder(const []), isEmpty);
      });
    });
  });
}

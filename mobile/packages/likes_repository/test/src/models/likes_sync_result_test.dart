import 'package:likes_repository/src/models/likes_sync_result.dart';
import 'package:test/test.dart';

void main() {
  group('LikesSyncResult', () {
    group('constructor', () {
      test('creates result with required fields', () {
        const result = LikesSyncResult(
          orderedEventIds: ['event1', 'event2'],
          eventIdToReactionId: {
            'event1': 'reaction1',
            'event2': 'reaction2',
          },
        );

        expect(result.orderedEventIds, equals(['event1', 'event2']));
        expect(result.eventIdToReactionId['event1'], equals('reaction1'));
        expect(result.eventIdToReactionId['event2'], equals('reaction2'));
      });
    });

    group('empty', () {
      test('creates empty result', () {
        const result = LikesSyncResult.empty();

        expect(result.orderedEventIds, isEmpty);
        expect(result.eventIdToReactionId, isEmpty);
      });
    });

    group('count', () {
      test('returns zero for empty result', () {
        const result = LikesSyncResult.empty();
        expect(result.count, equals(0));
      });

      test('returns number of liked events', () {
        const result = LikesSyncResult(
          orderedEventIds: ['event1', 'event2', 'event3'],
          eventIdToReactionId: {
            'event1': 'reaction1',
            'event2': 'reaction2',
            'event3': 'reaction3',
          },
        );

        expect(result.count, equals(3));
      });
    });

    group('isEmpty', () {
      test('returns true for empty result', () {
        const result = LikesSyncResult.empty();
        expect(result.isEmpty, isTrue);
      });

      test('returns false for non-empty result', () {
        const result = LikesSyncResult(
          orderedEventIds: ['event1'],
          eventIdToReactionId: {'event1': 'reaction1'},
        );

        expect(result.isEmpty, isFalse);
      });
    });

    group('equality', () {
      test('equal results are equal', () {
        const result1 = LikesSyncResult(
          orderedEventIds: ['event1'],
          eventIdToReactionId: {'event1': 'reaction1'},
        );
        const result2 = LikesSyncResult(
          orderedEventIds: ['event1'],
          eventIdToReactionId: {'event1': 'reaction1'},
        );

        expect(result1, equals(result2));
        expect(result1.props, equals(result2.props));
      });

      test('different results are not equal', () {
        const result1 = LikesSyncResult(
          orderedEventIds: ['event1'],
          eventIdToReactionId: {'event1': 'reaction1'},
        );
        const result2 = LikesSyncResult(
          orderedEventIds: ['event2'],
          eventIdToReactionId: {'event2': 'reaction2'},
        );

        expect(result1, isNot(equals(result2)));
      });
    });
  });
}

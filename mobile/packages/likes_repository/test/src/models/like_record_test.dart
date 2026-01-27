import 'package:likes_repository/likes_repository.dart';
import 'package:test/test.dart';

void main() {
  group('LikeRecord', () {
    group('constructor', () {
      test('creates record with required fields', () {
        final now = DateTime.now();
        final record = LikeRecord(
          targetEventId: 'target1',
          reactionEventId: 'reaction1',
          createdAt: now,
        );

        expect(record.targetEventId, equals('target1'));
        expect(record.reactionEventId, equals('reaction1'));
        expect(record.createdAt, equals(now));
      });
    });

    group('equality', () {
      test('equal records are equal', () {
        final now = DateTime.now();
        final record1 = LikeRecord(
          targetEventId: 'target1',
          reactionEventId: 'reaction1',
          createdAt: now,
        );
        final record2 = LikeRecord(
          targetEventId: 'target1',
          reactionEventId: 'reaction1',
          createdAt: now,
        );

        expect(record1, equals(record2));
      });

      test('different records are not equal', () {
        final now = DateTime.now();
        final record1 = LikeRecord(
          targetEventId: 'target1',
          reactionEventId: 'reaction1',
          createdAt: now,
        );
        final record2 = LikeRecord(
          targetEventId: 'target2',
          reactionEventId: 'reaction1',
          createdAt: now,
        );

        expect(record1, isNot(equals(record2)));
      });
    });

    group('copyWith', () {
      test('copies with targetEventId', () {
        final now = DateTime.now();
        final record = LikeRecord(
          targetEventId: 'target1',
          reactionEventId: 'reaction1',
          createdAt: now,
        );

        final copied = record.copyWith(targetEventId: 'target2');

        expect(copied.targetEventId, equals('target2'));
        expect(copied.reactionEventId, equals('reaction1'));
        expect(copied.createdAt, equals(now));
      });

      test('copies with reactionEventId', () {
        final now = DateTime.now();
        final record = LikeRecord(
          targetEventId: 'target1',
          reactionEventId: 'reaction1',
          createdAt: now,
        );

        final copied = record.copyWith(reactionEventId: 'reaction2');

        expect(copied.targetEventId, equals('target1'));
        expect(copied.reactionEventId, equals('reaction2'));
        expect(copied.createdAt, equals(now));
      });

      test('copies with createdAt', () {
        final now = DateTime.now();
        final later = now.add(const Duration(hours: 1));
        final record = LikeRecord(
          targetEventId: 'target1',
          reactionEventId: 'reaction1',
          createdAt: now,
        );

        final copied = record.copyWith(createdAt: later);

        expect(copied.targetEventId, equals('target1'));
        expect(copied.reactionEventId, equals('reaction1'));
        expect(copied.createdAt, equals(later));
      });

      test('copies with no arguments returns equivalent record', () {
        final now = DateTime.now();
        final record = LikeRecord(
          targetEventId: 'target1',
          reactionEventId: 'reaction1',
          createdAt: now,
        );

        final copied = record.copyWith();

        expect(copied.targetEventId, equals('target1'));
        expect(copied.reactionEventId, equals('reaction1'));
        expect(copied.createdAt, equals(now));
      });
    });

    group('toString', () {
      test('returns expected format', () {
        final now = DateTime.now();
        final record = LikeRecord(
          targetEventId: 'target1',
          reactionEventId: 'reaction1',
          createdAt: now,
        );

        final str = record.toString();

        expect(str, contains('LikeRecord'));
        expect(str, contains('target1'));
        expect(str, contains('reaction1'));
      });
    });
  });
}

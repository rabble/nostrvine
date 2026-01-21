import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

void main() {
  group('RepostRecord', () {
    test('creates instance with required fields', () {
      final now = DateTime.now();
      final record = RepostRecord(
        addressableId: '34236:author:dtag',
        repostEventId: 'event_id',
        originalAuthorPubkey: 'author',
        createdAt: now,
      );

      expect(record.addressableId, equals('34236:author:dtag'));
      expect(record.repostEventId, equals('event_id'));
      expect(record.originalAuthorPubkey, equals('author'));
      expect(record.createdAt, equals(now));
    });

    test('copyWith creates new instance with updated fields', () {
      final now = DateTime.now();
      final record = RepostRecord(
        addressableId: '34236:author:dtag',
        repostEventId: 'event_id',
        originalAuthorPubkey: 'author',
        createdAt: now,
      );

      final updated = record.copyWith(repostEventId: 'new_event_id');

      expect(updated.addressableId, equals('34236:author:dtag'));
      expect(updated.repostEventId, equals('new_event_id'));
      expect(updated.originalAuthorPubkey, equals('author'));
      expect(updated.createdAt, equals(now));
      expect(record.copyWith(), equals(record));
    });

    test('equality works correctly', () {
      final now = DateTime.now();
      final record1 = RepostRecord(
        addressableId: '34236:author:dtag',
        repostEventId: 'event_id',
        originalAuthorPubkey: 'author',
        createdAt: now,
      );
      final record2 = RepostRecord(
        addressableId: '34236:author:dtag',
        repostEventId: 'event_id',
        originalAuthorPubkey: 'author',
        createdAt: now,
      );
      final record3 = RepostRecord(
        addressableId: '34236:author:different',
        repostEventId: 'event_id',
        originalAuthorPubkey: 'author',
        createdAt: now,
      );

      expect(record1, equals(record2));
      expect(record1, isNot(equals(record3)));
    });

    test('toString returns meaningful representation', () {
      final record = RepostRecord(
        addressableId: '34236:author:dtag',
        repostEventId: 'event_id',
        originalAuthorPubkey: 'author',
        createdAt: DateTime(2024),
      );

      final str = record.toString();
      expect(str, contains('RepostRecord'));
      expect(str, contains('34236:author:dtag'));
      expect(str, contains('event_id'));
    });
  });
}

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(BulkVideoStatsEntry, () {
    group('constructor', () {
      test('creates instance with required fields', () {
        const entry = BulkVideoStatsEntry(
          eventId: 'abc123',
          reactions: 10,
          comments: 5,
          reposts: 2,
        );

        expect(entry.eventId, equals('abc123'));
        expect(entry.reactions, equals(10));
        expect(entry.comments, equals(5));
        expect(entry.reposts, equals(2));
        expect(entry.loops, isNull);
        expect(entry.views, isNull);
      });

      test('creates instance with all fields', () {
        const entry = BulkVideoStatsEntry(
          eventId: 'abc123',
          reactions: 10,
          comments: 5,
          reposts: 2,
          loops: 1000,
          views: 500,
        );

        expect(entry.loops, equals(1000));
        expect(entry.views, equals(500));
      });
    });

    group('fromJson', () {
      test('parses with event_id key', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'abc123',
          'reactions': 10,
          'comments': 5,
          'reposts': 2,
        });

        expect(entry.eventId, equals('abc123'));
        expect(entry.reactions, equals(10));
      });

      test('parses with id key as fallback', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'id': 'abc123',
          'reactions': 10,
          'comments': 5,
          'reposts': 2,
        });

        expect(entry.eventId, equals('abc123'));
      });

      test('finds likes under various keys', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'likes': 42,
          'comments': 0,
          'reposts': 0,
        });

        expect(entry.reactions, equals(42));
      });

      test('finds likes under total_likes', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'total_likes': 42,
        });

        expect(entry.reactions, equals(42));
      });

      test('finds comments under comment_count', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'comment_count': 15,
        });

        expect(entry.comments, equals(15));
      });

      test('finds loops under various keys', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'total_loops': 5000,
        });

        expect(entry.loops, equals(5000));
      });

      test('finds views under view_count', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'view_count': 200,
        });

        expect(entry.views, equals(200));
      });

      test('handles string values with commas', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'reactions': '1,000',
          'loops': '5,000',
        });

        expect(entry.reactions, equals(1000));
        expect(entry.loops, equals(5000));
      });

      test('handles nested stats', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'stats': {
            'reactions': 10,
            'comments': 5,
            'loops': 100,
          },
        });

        expect(entry.reactions, equals(10));
        expect(entry.comments, equals(5));
        expect(entry.loops, equals(100));
      });

      test('defaults to 0 when no matching key found', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
        });

        expect(entry.reactions, equals(0));
        expect(entry.comments, equals(0));
        expect(entry.reposts, equals(0));
        expect(entry.loops, isNull);
        expect(entry.views, isNull);
      });

      test('handles empty JSON', () {
        final entry = BulkVideoStatsEntry.fromJson(
          const <String, dynamic>{},
        );

        expect(entry.eventId, isEmpty);
        expect(entry.reactions, equals(0));
      });
    });

    group('equality', () {
      test('two entries with same eventId are equal', () {
        const a = BulkVideoStatsEntry(
          eventId: 'abc',
          reactions: 1,
          comments: 0,
          reposts: 0,
        );
        const b = BulkVideoStatsEntry(
          eventId: 'abc',
          reactions: 99,
          comments: 99,
          reposts: 99,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('two entries with different eventIds are not equal', () {
        const a = BulkVideoStatsEntry(
          eventId: 'abc',
          reactions: 1,
          comments: 0,
          reposts: 0,
        );
        const b = BulkVideoStatsEntry(
          eventId: 'def',
          reactions: 1,
          comments: 0,
          reposts: 0,
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const entry = BulkVideoStatsEntry(
          eventId: 'abc123',
          reactions: 10,
          comments: 5,
          reposts: 2,
        );

        expect(
          entry.toString(),
          equals(
            'BulkVideoStatsEntry(eventId: abc123, '
            'reactions: 10, comments: 5)',
          ),
        );
      });
    });
  });
}

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(PaginatedPubkeys, () {
    group('constructor', () {
      test('creates instance with required fields', () {
        const result = PaginatedPubkeys(pubkeys: ['abc', 'def']);

        expect(result.pubkeys, equals(['abc', 'def']));
        expect(result.total, equals(0));
        expect(result.hasMore, isFalse);
      });

      test('creates instance with all fields', () {
        const result = PaginatedPubkeys(
          pubkeys: ['abc'],
          total: 100,
          hasMore: true,
        );

        expect(result.pubkeys, hasLength(1));
        expect(result.total, equals(100));
        expect(result.hasMore, isTrue);
      });
    });

    group('empty', () {
      test('has no pubkeys and defaults', () {
        expect(PaginatedPubkeys.empty.pubkeys, isEmpty);
        expect(PaginatedPubkeys.empty.total, equals(0));
        expect(PaginatedPubkeys.empty.hasMore, isFalse);
      });
    });

    group('fromJson', () {
      test('parses followers key', () {
        final result = PaginatedPubkeys.fromJson(const {
          'followers': ['abc', 'def'],
          'total': 50,
          'has_more': true,
        });

        expect(result.pubkeys, equals(['abc', 'def']));
        expect(result.total, equals(50));
        expect(result.hasMore, isTrue);
      });

      test('parses following key', () {
        final result = PaginatedPubkeys.fromJson(const {
          'following': ['abc'],
          'total': 10,
          'has_more': false,
        });

        expect(result.pubkeys, equals(['abc']));
        expect(result.total, equals(10));
        expect(result.hasMore, isFalse);
      });

      test('parses pubkeys key as fallback', () {
        final result = PaginatedPubkeys.fromJson(const {
          'pubkeys': ['xyz'],
          'total': 1,
        });

        expect(result.pubkeys, equals(['xyz']));
        expect(result.total, equals(1));
      });

      test('defaults total to list length when missing', () {
        final result = PaginatedPubkeys.fromJson(const {
          'followers': ['a', 'b', 'c'],
        });

        expect(result.pubkeys, hasLength(3));
        expect(result.total, equals(3));
      });

      test('handles empty JSON', () {
        final result = PaginatedPubkeys.fromJson(
          const <String, dynamic>{},
        );

        expect(result.pubkeys, isEmpty);
        expect(result.total, equals(0));
        expect(result.hasMore, isFalse);
      });

      test('prioritizes following over followers', () {
        final result = PaginatedPubkeys.fromJson(const {
          'following': ['a'],
          'followers': ['b', 'c'],
        });

        expect(result.pubkeys, equals(['a']));
      });
    });

    group('equality', () {
      test('equal when same pubkeys, total, and hasMore', () {
        const a = PaginatedPubkeys(
          pubkeys: ['abc', 'def'],
          total: 2,
        );
        const b = PaginatedPubkeys(
          pubkeys: ['abc', 'def'],
          total: 2,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when different pubkeys', () {
        const a = PaginatedPubkeys(pubkeys: ['abc']);
        const b = PaginatedPubkeys(pubkeys: ['def']);

        expect(a, isNot(equals(b)));
      });

      test('not equal when different total', () {
        const a = PaginatedPubkeys(
          pubkeys: ['abc'],
          total: 1,
        );
        const b = PaginatedPubkeys(
          pubkeys: ['abc'],
          total: 99,
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const result = PaginatedPubkeys(
          pubkeys: ['abc', 'def'],
          total: 50,
          hasMore: true,
        );

        expect(
          result.toString(),
          equals(
            'PaginatedPubkeys(count: 2, '
            'total: 50, hasMore: true)',
          ),
        );
      });
    });
  });
}

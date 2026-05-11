// ABOUTME: Unit tests for FollowingSnapshot
// ABOUTME: Tests serialization, equality, hashCode, and toString

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/src/following_snapshot.dart';

void main() {
  group(FollowingSnapshot, () {
    const pubkeys = ['aabbcc', 'ddeeff'];
    const snapshot = FollowingSnapshot(pubkeys: pubkeys, count: 42);

    group('fromJson', () {
      test('round-trips through toJson and fromJson', () {
        final json = snapshot.toJson();
        final restored = FollowingSnapshot.fromJson(json);

        expect(restored.pubkeys, equals(pubkeys));
        expect(restored.count, equals(42));
      });

      test('falls back to pubkeys.length when count is absent', () {
        const json = '{"pubkeys":["aabbcc","ddeeff"]}';
        final restored = FollowingSnapshot.fromJson(json);

        expect(restored.count, equals(2));
      });

      test('handles missing pubkeys field', () {
        const json = '{"count":5}';
        final restored = FollowingSnapshot.fromJson(json);

        expect(restored.pubkeys, isEmpty);
        expect(restored.count, equals(5));
      });
    });

    group('toJson', () {
      test('serializes pubkeys and count', () {
        final json = snapshot.toJson();

        expect(json, contains('"pubkeys"'));
        expect(json, contains('"count":42'));
        expect(json, contains('"aabbcc"'));
        expect(json, contains('"ddeeff"'));
      });
    });

    group('operator ==', () {
      test('equal snapshots are equal', () {
        const a = FollowingSnapshot(pubkeys: pubkeys, count: 42);
        const b = FollowingSnapshot(pubkeys: pubkeys, count: 42);

        expect(a, equals(b));
      });

      test('identical instance is equal to itself', () {
        expect(snapshot, equals(snapshot));
      });

      test('different count is not equal', () {
        const other = FollowingSnapshot(pubkeys: pubkeys, count: 99);

        expect(snapshot, isNot(equals(other)));
      });

      test('different pubkeys are not equal', () {
        const other = FollowingSnapshot(pubkeys: ['xx'], count: 42);

        expect(snapshot, isNot(equals(other)));
      });

      test('different pubkey values are not equal', () {
        const other = FollowingSnapshot(
          pubkeys: ['aabbcc', 'zzzzzz'],
          count: 42,
        );

        expect(snapshot, isNot(equals(other)));
      });

      test('not equal to unrelated object', () {
        expect(snapshot == ('unrelated' as Object), isFalse);
      });
    });

    group('hashCode', () {
      test('equal snapshots have equal hashCodes', () {
        const a = FollowingSnapshot(pubkeys: pubkeys, count: 42);
        const b = FollowingSnapshot(pubkeys: pubkeys, count: 42);

        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('toString', () {
      test('contains count and pubkeys length', () {
        final result = snapshot.toString();

        expect(result, contains('count: 42'));
        expect(result, contains('pubkeys: 2'));
      });
    });
  });
}

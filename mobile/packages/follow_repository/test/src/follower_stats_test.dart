// ABOUTME: Unit tests for FollowerStats data class.
// ABOUTME: Covers equality, hashCode, and toString.

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';

void main() {
  group(FollowerStats, () {
    test('supports value equality', () {
      const a = FollowerStats(followers: 10, following: 5);
      const b = FollowerStats(followers: 10, following: 5);

      expect(a, equals(b));
    });

    test('is not equal when followers differ', () {
      const a = FollowerStats(followers: 10, following: 5);
      const b = FollowerStats(followers: 20, following: 5);

      expect(a, isNot(equals(b)));
    });

    test('is not equal when following differs', () {
      const a = FollowerStats(followers: 10, following: 5);
      const b = FollowerStats(followers: 10, following: 15);

      expect(a, isNot(equals(b)));
    });

    test('is not equal to objects of other types', () {
      const stats = FollowerStats(followers: 10, following: 5);

      expect(stats, isNot(equals('not a FollowerStats')));
    });

    test('identical instances are equal', () {
      const stats = FollowerStats(followers: 10, following: 5);

      expect(stats == stats, isTrue);
    });

    test('has consistent hashCode for equal instances', () {
      const a = FollowerStats(followers: 10, following: 5);
      const b = FollowerStats(followers: 10, following: 5);

      expect(a.hashCode, equals(b.hashCode));
    });

    test('has different hashCode for different instances', () {
      const a = FollowerStats(followers: 10, following: 5);
      const b = FollowerStats(followers: 20, following: 15);

      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('toString returns formatted string', () {
      const stats = FollowerStats(followers: 42, following: 7);

      expect(
        stats.toString(),
        equals('FollowerStats(followers: 42, following: 7)'),
      );
    });

    test('zero constant has 0 followers and 0 following', () {
      expect(FollowerStats.zero.followers, equals(0));
      expect(FollowerStats.zero.following, equals(0));
    });
  });
}

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(SocialCounts, () {
    group('constructor', () {
      test('creates instance with required fields', () {
        const counts = SocialCounts(
          pubkey: 'abc123',
          followerCount: 100,
          followingCount: 50,
        );

        expect(counts.pubkey, equals('abc123'));
        expect(counts.followerCount, equals(100));
        expect(counts.followingCount, equals(50));
      });
    });

    group('fromJson', () {
      test('parses all fields', () {
        final counts = SocialCounts.fromJson(const {
          'pubkey': 'abc123',
          'follower_count': 100,
          'following_count': 50,
        });

        expect(counts.pubkey, equals('abc123'));
        expect(counts.followerCount, equals(100));
        expect(counts.followingCount, equals(50));
      });

      test('handles missing fields with defaults', () {
        final counts = SocialCounts.fromJson(
          const <String, dynamic>{},
        );

        expect(counts.pubkey, isEmpty);
        expect(counts.followerCount, equals(0));
        expect(counts.followingCount, equals(0));
      });

      test('handles null pubkey', () {
        final counts = SocialCounts.fromJson(const {
          'pubkey': null,
          'follower_count': 10,
          'following_count': 5,
        });

        expect(counts.pubkey, isEmpty);
      });
    });

    group('equality', () {
      test('two counts with same pubkey are equal', () {
        const a = SocialCounts(
          pubkey: 'abc',
          followerCount: 1,
          followingCount: 2,
        );
        const b = SocialCounts(
          pubkey: 'abc',
          followerCount: 99,
          followingCount: 99,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('two counts with different pubkeys are not equal', () {
        const a = SocialCounts(
          pubkey: 'abc',
          followerCount: 1,
          followingCount: 2,
        );
        const b = SocialCounts(
          pubkey: 'def',
          followerCount: 1,
          followingCount: 2,
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const counts = SocialCounts(
          pubkey: 'abc',
          followerCount: 100,
          followingCount: 50,
        );

        expect(
          counts.toString(),
          equals(
            'SocialCounts(pubkey: abc, followers: 100, '
            'following: 50)',
          ),
        );
      });
    });
  });
}

// ABOUTME: Tests for UserProfileResult sealed class and its sub-models.

import 'package:models/models.dart';
import 'package:test/test.dart';

const _pubkey =
    'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

void main() {
  group('UserProfileData', () {
    test('fromJson parses all fields', () {
      final data = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
        'display_name': 'Alice',
        'about': 'Bio',
        'picture': 'https://example.com/pic.jpg',
        'banner': 'https://example.com/banner.jpg',
        'nip05': 'alice@example.com',
        'lud16': 'alice@walletofsatoshi.com',
        'website': 'https://example.com',
      });

      expect(data.pubkey, equals(_pubkey));
      expect(data.name, equals('alice'));
      expect(data.displayName, equals('Alice'));
      expect(data.about, equals('Bio'));
      expect(data.picture, equals('https://example.com/pic.jpg'));
      expect(data.banner, equals('https://example.com/banner.jpg'));
      expect(data.nip05, equals('alice@example.com'));
      expect(data.lud16, equals('alice@walletofsatoshi.com'));
      expect(data.website, equals('https://example.com'));
    });

    test('fromJson handles missing optional fields', () {
      final data = UserProfileData.fromJson(_pubkey, const {});

      expect(data.pubkey, equals(_pubkey));
      expect(data.name, isNull);
      expect(data.displayName, isNull);
    });

    test('equality', () {
      final a = UserProfileData.fromJson(_pubkey, const {'name': 'alice'});
      final b = UserProfileData.fromJson(_pubkey, const {'name': 'alice'});

      expect(a, equals(b));
    });
  });

  group('ProfileSocialData', () {
    test('fromJson parses counts', () {
      final data = ProfileSocialData.fromJson(const {
        'follower_count': 42,
        'following_count': 10,
      });

      expect(data.followerCount, equals(42));
      expect(data.followingCount, equals(10));
    });

    test('fromJson handles string numbers', () {
      final data = ProfileSocialData.fromJson(const {
        'follower_count': '100',
        'following_count': '50',
      });

      expect(data.followerCount, equals(100));
      expect(data.followingCount, equals(50));
    });

    test('fromJson defaults missing values to 0', () {
      final data = ProfileSocialData.fromJson(const {});

      expect(data.followerCount, equals(0));
      expect(data.followingCount, equals(0));
    });
  });

  group('ProfileStatsData', () {
    test('fromJson parses counts', () {
      final data = ProfileStatsData.fromJson(const {
        'video_count': 5,
        'reaction_count': 20,
      });

      expect(data.videoCount, equals(5));
      expect(data.reactionCount, equals(20));
    });
  });

  group('ProfileEngagementData', () {
    test('fromJson parses values including fractional loops', () {
      final data = ProfileEngagementData.fromJson(const {
        'total_reactions': 100,
        'total_loops': 50.5,
        'total_views': 200,
      });

      expect(data.totalReactions, equals(100));
      expect(data.totalLoops, equals(50.5));
      expect(data.totalViews, equals(200));
    });
  });

  group('UserProfileFound', () {
    test('holds profile and optional sub-models', () {
      final profile = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
      });
      const social = ProfileSocialData(followerCount: 10, followingCount: 5);

      final result = UserProfileFound(profile: profile, social: social);

      expect(result.profile.name, equals('alice'));
      expect(result.social?.followerCount, equals(10));
      expect(result.stats, isNull);
      expect(result.engagement, isNull);
    });

    test('equality', () {
      final profile = UserProfileData.fromJson(_pubkey, const {
        'name': 'alice',
      });
      final a = UserProfileFound(profile: profile);
      final b = UserProfileFound(profile: profile);

      expect(a, equals(b));
    });
  });

  group('UserProfileNotPublished', () {
    test('holds pubkey and optional sub-models', () {
      const social = ProfileSocialData(followerCount: 3, followingCount: 1);

      const result = UserProfileNotPublished(pubkey: _pubkey, social: social);

      expect(result.pubkey, equals(_pubkey));
      expect(result.social?.followerCount, equals(3));
      expect(result.stats, isNull);
    });

    test('equality', () {
      const a = UserProfileNotPublished(pubkey: _pubkey);
      const b = UserProfileNotPublished(pubkey: _pubkey);

      expect(a, equals(b));
    });
  });

  group('pattern matching', () {
    test('switch on UserProfileFound works exhaustively', () {
      final UserProfileResult result = UserProfileFound(
        profile: UserProfileData.fromJson(_pubkey, const {'name': 'alice'}),
      );

      final name = switch (result) {
        UserProfileFound(:final profile) => profile.name,
        UserProfileNotPublished() => null,
      };

      expect(name, equals('alice'));
    });

    test('switch on UserProfileNotPublished works exhaustively', () {
      const UserProfileResult result = UserProfileNotPublished(pubkey: _pubkey);

      final matched = switch (result) {
        UserProfileFound() => false,
        UserProfileNotPublished() => true,
      };

      expect(matched, isTrue);
    });
  });
}

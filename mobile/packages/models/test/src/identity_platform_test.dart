import 'package:models/src/identity_platform.dart';
import 'package:test/test.dart';

void main() {
  group(IdentityPlatform, () {
    group('fromTagPrefix', () {
      test('parses github', () {
        expect(
          IdentityPlatform.fromTagPrefix('github'),
          equals(IdentityPlatform.github),
        );
      });
      test('maps x to twitter', () {
        expect(
          IdentityPlatform.fromTagPrefix('x'),
          equals(IdentityPlatform.twitter),
        );
      });
      test('parses bluesky', () {
        expect(
          IdentityPlatform.fromTagPrefix('bluesky'),
          equals(IdentityPlatform.bluesky),
        );
      });
      test('returns null for unknown platform', () {
        expect(IdentityPlatform.fromTagPrefix('myspace'), isNull);
      });
      test('is case-insensitive', () {
        expect(
          IdentityPlatform.fromTagPrefix('GitHub'),
          equals(IdentityPlatform.github),
        );
      });
    });

    group('canonicalProfileUrl', () {
      test('builds github URL', () {
        expect(
          IdentityPlatform.github.canonicalProfileUrl('rabble').toString(),
          equals('https://github.com/rabble'),
        );
      });
      test('builds twitter URL', () {
        expect(
          IdentityPlatform.twitter.canonicalProfileUrl('rabble').toString(),
          equals('https://x.com/rabble'),
        );
      });
      test('builds bluesky URL with handle', () {
        expect(
          IdentityPlatform.bluesky
              .canonicalProfileUrl('rabble.bsky.social')
              .toString(),
          equals('https://bsky.app/profile/rabble.bsky.social'),
        );
      });
      test('builds mastodon URL with user@host identity', () {
        expect(
          IdentityPlatform.mastodon
              .canonicalProfileUrl('rabble@mastodon.social')
              .toString(),
          equals('https://mastodon.social/@rabble'),
        );
      });
      test('builds telegram URL', () {
        expect(
          IdentityPlatform.telegram.canonicalProfileUrl('rabble').toString(),
          equals('https://t.me/rabble'),
        );
      });
      test('builds youtube URL', () {
        expect(
          IdentityPlatform.youtube.canonicalProfileUrl('rabble').toString(),
          equals('https://youtube.com/@rabble'),
        );
      });
      test('builds tiktok URL', () {
        expect(
          IdentityPlatform.tiktok.canonicalProfileUrl('rabble').toString(),
          equals('https://tiktok.com/@rabble'),
        );
      });
      test('builds discord URL with username', () {
        expect(
          IdentityPlatform.discord.canonicalProfileUrl('rabble').toString(),
          equals('https://discord.com/users/rabble'),
        );
      });
    });

    group('displayName', () {
      test('humanizes github', () {
        expect(IdentityPlatform.github.displayName, equals('GitHub'));
      });
      test('twitter displays as X', () {
        expect(IdentityPlatform.twitter.displayName, equals('X'));
      });
    });
  });
}

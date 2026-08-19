// ABOUTME: Tests public profile URL construction for verified identity claims.
// ABOUTME: Covers platform-specific forms and identities without public URLs.

import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group(platformProfileUrl, () {
    test('builds a GitHub profile URL', () {
      expect(
        platformProfileUrl('github', 'octocat'),
        Uri.parse('https://github.com/octocat'),
      );
    });

    test('builds an X profile URL', () {
      expect(
        platformProfileUrl(' Twitter ', ' jack '),
        Uri.parse('https://x.com/jack'),
      );
    });

    test('builds a Bluesky profile URL', () {
      expect(
        platformProfileUrl('bluesky', 'alice.bsky.social'),
        Uri.parse('https://bsky.app/profile/alice.bsky.social'),
      );
    });

    test('builds TikTok profile URLs for bare and prefixed handles', () {
      expect(
        platformProfileUrl('tiktok', 'alice'),
        Uri.parse('https://www.tiktok.com/@alice'),
      );
      expect(
        platformProfileUrl('tiktok', '@alice'),
        Uri.parse('https://www.tiktok.com/@alice'),
      );
    });

    test('builds Telegram profile URLs for bare and prefixed handles', () {
      expect(
        platformProfileUrl('telegram', 'alice'),
        Uri.parse('https://t.me/alice'),
      );
      expect(
        platformProfileUrl('telegram', '@alice'),
        Uri.parse('https://t.me/alice'),
      );
    });

    test('builds a YouTube channel URL for a channel ID', () {
      expect(
        platformProfileUrl('youtube', 'UC_x5XG1OV2P6uZZ5FSM9Ttw'),
        Uri.parse('https://www.youtube.com/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw'),
      );
    });

    test('builds YouTube handle URLs without duplicating at signs', () {
      expect(
        platformProfileUrl('youtube', 'alice'),
        Uri.parse('https://www.youtube.com/@alice'),
      );
      expect(
        platformProfileUrl('youtube', '@alice'),
        Uri.parse('https://www.youtube.com/@alice'),
      );
    });

    test('builds a Mastodon URL from an at-prefixed username', () {
      expect(
        platformProfileUrl('mastodon', 'fosstodon.org/@alice'),
        Uri.parse('https://fosstodon.org/@alice'),
      );
    });

    test('adds the Mastodon username at sign when omitted', () {
      expect(
        platformProfileUrl('mastodon', 'fosstodon.org/alice'),
        Uri.parse('https://fosstodon.org/@alice'),
      );
    });

    test('rejects malformed Mastodon identities', () {
      expect(platformProfileUrl('mastodon', 'alice'), isNull);
      expect(platformProfileUrl('mastodon', '/@alice'), isNull);
      expect(
        platformProfileUrl('mastodon', 'https://example.com/@alice'),
        isNull,
      );
      expect(platformProfileUrl('mastodon', 'example.com/'), isNull);
    });

    test('returns null for identities without a public profile URL', () {
      expect(platformProfileUrl('discord', 'alice'), isNull);
      expect(platformProfileUrl('unknown', 'alice'), isNull);
      expect(platformProfileUrl('github', '  '), isNull);
    });
  });
}

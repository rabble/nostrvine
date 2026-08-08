// ABOUTME: Tests for the bundled preloaded Nostr app catalog.
// ABOUTME: Verifies shared first-party app lookups used for deep links.

import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:test/test.dart';

void main() {
  group('divineBadgesNostrApp', () {
    test('returns the bundled Divine Badges entry', () {
      expect(divineBadgesNostrApp.id, 'bundled-badges');
      expect(divineBadgesNostrApp.slug, 'badges');
      expect(divineBadgesNostrApp.launchUrl, 'https://badges.divine.video/me');
    });
  });
}

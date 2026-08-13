// ABOUTME: Regression tests for oauthConfigProvider hostname selection.
// ABOUTME: Ensures production stays pinned to the canonical login origin.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group('oauthConfigProvider', () {
    test('uses the canonical login hostname in production', () {
      final container = ProviderContainer(
        overrides: [
          currentEnvironmentProvider.overrideWithValue(
            EnvironmentConfig.production,
          ),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(oauthConfigProvider);

      expect(config.serverUrl, 'https://login.divine.video');
      expect(
        config.authorizeUrl,
        'https://login.divine.video/api/oauth/authorize',
      );
      expect(config.tokenUrl, 'https://login.divine.video/api/oauth/token');
      // Feeds ProfileRepository.keycastNip05Url. The availability probe is
      // fail-open, so a malformed value here yields silently-claimable
      // usernames rather than a visible error.
      expect(
        config.nip05Url,
        equals(defaultKeycastNip05Url),
        reason: 'production must keep the shipped repository default',
      );
    });

    test('keeps local oauth on the emulator localhost endpoint', () {
      final container = ProviderContainer(
        overrides: [
          currentEnvironmentProvider.overrideWithValue(
            const EnvironmentConfig(environment: AppEnvironment.local),
          ),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(oauthConfigProvider);

      expect(config.serverUrl, 'http://$localHost:$localKeycastPort');
      expect(
        config.authorizeUrl,
        'http://$localHost:$localKeycastPort/api/oauth/authorize',
      );
      expect(
        config.tokenUrl,
        'http://$localHost:$localKeycastPort/api/oauth/token',
      );
      // LOCAL now checks username availability against the local_stack
      // Keycast rather than production. Keycast keys its username namespace
      // on the request Host and rejects 127.0.0.1, so this must resolve
      // through localHost.
      expect(
        config.nip05Url,
        'http://$localHost:$localKeycastPort/.well-known/nostr.json',
      );
    });
  });
}

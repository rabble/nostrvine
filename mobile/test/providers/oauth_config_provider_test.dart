// ABOUTME: Regression tests for oauthConfigProvider hostname selection.
// ABOUTME: Ensures production stays pinned to the canonical login origin.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';

void main() {
  group('oauthConfigProvider', () {
    test('uses the canonical login hostname in production', () {
      final container = ProviderContainer(
        overrides: [
          currentEnvironmentProvider.overrideWithValue(
            const EnvironmentConfig(environment: AppEnvironment.production),
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
    });
  });
}

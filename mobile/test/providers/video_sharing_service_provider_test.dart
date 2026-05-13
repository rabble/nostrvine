// ABOUTME: Tests for the video sharing service provider readiness gate.
// ABOUTME: Verifies sharing providers tolerate auth-before-Nostr-ready states.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockDmRepository extends Mock implements DmRepository {}

void main() {
  test(
    'returns null instead of throwing when profile repository is unavailable',
    () {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(_MockNostrClient()),
          authServiceProvider.overrideWithValue(_MockAuthService()),
          profileRepositoryProvider.overrideWithValue(null),
          dmRepositoryProvider.overrideWithValue(_MockDmRepository()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(videoSharingServiceProvider), isNull);
    },
  );
}

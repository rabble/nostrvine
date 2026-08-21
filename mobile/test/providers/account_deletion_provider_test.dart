// ABOUTME: Tests for account deletion Riverpod provider
// ABOUTME: Verifies provider initialization and dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('accountDeletionServiceProvider', () {
    test('should create AccountDeletionService instance', () {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(_MockNostrClient()),
          authServiceProvider.overrideWithValue(_MockAuthService()),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(accountDeletionServiceProvider);

      expect(service, isA<AccountDeletionService>());
    });
  });
}

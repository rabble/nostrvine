// Tests for isNostrReadyProvider
// Verifies the periodic timer polling behaviour that detects when
// NostrClient.hasKeys transitions from false → true.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('isNostrReadyProvider', () {
    late _MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockAuthService = _MockAuthService();
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          authServiceProvider.overrideWithValue(mockAuthService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        ],
      );
    }

    test('returns false when not authenticated', () {
      when(() => mockAuthService.isAuthenticated).thenReturn(false);
      when(() => mockNostrClient.hasKeys).thenReturn(false);

      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(isNostrReadyProvider), isFalse);
    });

    test('returns true when authenticated and hasKeys is true', () {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockNostrClient.hasKeys).thenReturn(true);

      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(isNostrReadyProvider), isTrue);
    });

    test('returns false initially when hasKeys is false', () {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockNostrClient.hasKeys).thenReturn(false);

      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(isNostrReadyProvider), isFalse);
    });

    test(
      'transitions to true after hasKeys becomes true via timer polling',
      () {
        fakeAsync((async) {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(() => mockNostrClient.hasKeys).thenReturn(false);

          final container = createContainer();
          addTearDown(container.dispose);

          expect(container.read(isNostrReadyProvider), isFalse);

          // Simulate NostrClient finishing initialization
          when(() => mockNostrClient.hasKeys).thenReturn(true);

          // Advance past one timer tick (50ms) so the callback fires
          async.elapse(const Duration(milliseconds: 50));

          expect(container.read(isNostrReadyProvider), isTrue);
        });
      },
    );

    test(
      'transitions to true even after long delay (simulates debugger pause)',
      () {
        fakeAsync((async) {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(() => mockNostrClient.hasKeys).thenReturn(false);

          final container = createContainer();
          addTearDown(container.dispose);

          expect(container.read(isNostrReadyProvider), isFalse);

          // Simulate a debugger pause — timer keeps ticking but hasKeys
          // stays false for 5 seconds
          async.elapse(const Duration(seconds: 5));
          expect(container.read(isNostrReadyProvider), isFalse);

          // Now hasKeys becomes true
          when(() => mockNostrClient.hasKeys).thenReturn(true);

          // Next tick detects it
          async.elapse(const Duration(milliseconds: 50));

          expect(container.read(isNostrReadyProvider), isTrue);
        });
      },
    );

    test('timer is cancelled on dispose', () {
      fakeAsync((async) {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        final container = createContainer();

        // Read to activate the timer
        container.read(isNostrReadyProvider);

        // Dispose should cancel the timer without errors
        container.dispose();

        // Advancing time after dispose must not throw
        expect(
          () => async.elapse(const Duration(milliseconds: 200)),
          returnsNormally,
        );
      });
    });

    test('profileRepositoryProvider is null when isNostrReady is false', () {
      final container = ProviderContainer(
        overrides: [isNostrReadyProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      expect(container.read(profileRepositoryProvider), isNull);
    });
  });
}

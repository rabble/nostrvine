// ABOUTME: Tests for ageVerificationServiceProvider to verify keepAlive behavior
// ABOUTME: Specifically tests that verification state persists across provider rebuilds

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  const pubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const pubkeyB =
      '2222222222222222222222222222222222222222222222222222222222222222';

  group('ageVerificationServiceProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ageVerificationServiceProvider consults isProtectedMinorProvider (needs
    // sharedPreferencesProvider and an auth state) and scopes verification to
    // the active account's pubkey (#7816). Pin auth to unauthenticated so the
    // protected-minor signal resolves to false without a network fetch, and
    // supply a mock AuthService pubkey so per-account writes persist.
    Future<ProviderContainer> buildContainer() async {
      final prefs = await SharedPreferences.getInstance();
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('provider should have keepAlive configuration', () async {
      // This test verifies the provider is configured with keepAlive: true
      // which prevents automatic disposal when widgets stop watching.
      //
      // Bug scenario: If autoDispose, the service would be disposed when all
      // watchers dispose, and a new instance would be created when watched again.
      // The new instance starts with _isAdultContentVerified = null (defaulting to false)
      // until initialize() completes loading from SharedPreferences.

      // The fix is to use keepAlive: true, which we verify via the generated code
      // by checking that the provider returns the same instance across multiple reads
      // within the same container lifecycle.

      final container = await buildContainer();

      // Get the service and verify adult content
      final service = container.read(ageVerificationServiceProvider);
      await service.initialize();
      await service.setAdultContentVerified(true);

      expect(
        service.isAdultContentVerified,
        true,
        reason: 'Service should be verified after setAdultContentVerified',
      );

      // Read multiple times - should always return same instance with keepAlive
      final service2 = container.read(ageVerificationServiceProvider);
      final service3 = container.read(ageVerificationServiceProvider);

      expect(identical(service, service2), true);
      expect(identical(service2, service3), true);
      expect(
        service3.isAdultContentVerified,
        true,
        reason: 'Verification state should be retained across reads',
      );
    });

    test('should maintain verification state without race condition', () async {
      // This test specifically targets the race condition bug:
      // When provider is recreated (autoDispose), initialize() is called but not awaited.
      // Checking isAdultContentVerified IMMEDIATELY after provider creation
      // returns false because initialize() hasn't completed loading from SharedPreferences.

      // First, set up verification in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'adult_content_verified_$pubkey': true,
        'adult_content_verification_date_$pubkey':
            DateTime.now().millisecondsSinceEpoch,
      });

      final container = await buildContainer();

      final service = container.read(ageVerificationServiceProvider);

      // With the buggy implementation (no await on initialize), this would fail
      // because _isAdultContentVerified is still null (defaults to false)
      // before initialize() completes.
      //
      // With keepAlive: true, the service is created once and persists,
      // so we need to explicitly wait for initialization.
      await service.initialize();

      expect(
        service.isAdultContentVerified,
        true,
        reason: 'Verification status should be loaded from SharedPreferences',
      );
    });

    test('should be a singleton across multiple reads', () async {
      final container = await buildContainer();

      final service1 = container.read(ageVerificationServiceProvider);
      final service2 = container.read(ageVerificationServiceProvider);
      final service3 = container.read(ageVerificationServiceProvider);

      expect(identical(service1, service2), true);
      expect(identical(service2, service3), true);
    });

    test('verification state survives widget lifecycle changes', () async {
      // Simulates: User verifies age -> widget disposes -> widget rebuilds -> state should persist

      final container = await buildContainer();

      // User verifies age
      final service = container.read(ageVerificationServiceProvider);
      await service.initialize();
      await service.setAdultContentVerified(true);

      // Simulate widget lifecycle: In a real app, widgets that watch this provider
      // may dispose and rebuild. With autoDispose, this would create new instances.
      // With keepAlive, the same instance persists.

      // Even after many reads (simulating widget rebuilds), state should persist
      for (var i = 0; i < 10; i++) {
        final s = container.read(ageVerificationServiceProvider);
        expect(
          s.isAdultContentVerified,
          true,
          reason: 'Verification should persist across reads (iteration $i)',
        );
      }
    });

    test('same service reads the newly active account after a switch', () async {
      final prefs = await SharedPreferences.getInstance();
      final authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
        ],
      );
      addTearDown(container.dispose);

      final serviceA = container.read(ageVerificationServiceProvider);
      await serviceA.initialize();
      await serviceA.setAdultContentVerified(true);
      expect(serviceA.isAdultContentVerified, isTrue);

      // Account swap: the service reads through the live pubkey accessor, so it
      // does not need a provider rebuild or an asynchronous cache reload.
      when(() => authService.currentPublicKeyHex).thenReturn(pubkeyB);
      container.updateOverrides([
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(authService),
        currentAuthStateProvider.overrideWithValue(AuthState.authenticating),
      ]);

      final serviceB = container.read(ageVerificationServiceProvider);
      await serviceB.initialize();

      expect(
        identical(serviceA, serviceB),
        isTrue,
        reason: 'account swap must not require a service rebuild',
      );
      expect(
        serviceB.isAdultContentVerified,
        isFalse,
        reason: 'the switched-in account must not inherit prior verification',
      );
    });
  });
}

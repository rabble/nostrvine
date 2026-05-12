// Tests for isNostrReadyProvider.
// Verifies that the provider observes NostrClient.ready (a one-shot future
// completed by initialize()) instead of polling hasKeys with a periodic
// timer (#3352).

import 'dart:async';

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
    late Completer<void> readyCompleter;

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockAuthService = _MockAuthService();
      readyCompleter = Completer<void>();
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
      when(
        () => mockNostrClient.ready,
      ).thenAnswer((_) => readyCompleter.future);
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
      'transitions to true after NostrClient.ready completes (no time advance)',
      () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        final container = createContainer();
        addTearDown(container.dispose);

        expect(container.read(isNostrReadyProvider), isFalse);

        // Simulate NostrClient.initialize() completing — flip hasKeys true
        // then complete the ready future. The provider must invalidate
        // and re-read without any wall-clock time advance.
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        readyCompleter.complete();
        // Yield to the microtask queue so the `.then(...)` callback runs.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(isNostrReadyProvider), isTrue);
      },
    );

    test(
      'late ready completion after provider rebuild is a no-op (smoke)',
      () async {
        // Smoke-coverage for the stale-late-completion regime: once the
        // provider rebuilds (here triggered by `ref.invalidate` on the
        // upstream nostrServiceProvider), the `.then` callback's
        // `ref.mounted` short-circuit must fire before the `identical(...)`
        // check, so a late `readyCompleter.complete()` must not throw.
        //
        // This does NOT exercise the `identical(...)` guard in isolation —
        // doing that would require swapping the `nostrServiceProvider`
        // override mid-test to a different mock client, which the current
        // ProviderContainer API does not support cleanly. The orderly
        // account-switch case is covered by integration tests against
        // NostrService's own rebuild path.
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrClient),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
        );
        addTearDown(container.dispose);

        container.read(isNostrReadyProvider);

        // Force the provider to rebuild, invalidating the `ref` captured
        // in the `.then` callback.
        container.invalidate(nostrServiceProvider);

        // Late completion on the captured ref — must be a no-op.
        readyCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // No exception, no crash.
      },
    );

    test('cancellation on dispose does not throw', () {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockNostrClient.hasKeys).thenReturn(false);

      final container = createContainer();

      container.read(isNostrReadyProvider);

      // Dispose should leave no dangling timers — completing the ready
      // future after dispose must not throw.
      container.dispose();
      readyCompleter.complete();

      // No expectations — the test passes if no exception leaks.
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

// ABOUTME: Tests featuredTabViewerIsMinorProvider (#7675) — the middle-path gate
// ABOUTME: for age-restricted featured tabs. Mirrors the #176/#182 fail-CLOSED
// ABOUTME: posture: an unresolved Keycast check hides age-restricted tabs only
// ABOUTME: where a Keycast verdict could apply, staying permissive for pure
// ABOUTME: self-custody accounts Keycast can never answer for.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/protected_minor_sticky_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pubkey = 'a' * 64;

  late SharedPreferences prefs;
  late _MockAuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    authService = _MockAuthService();
    when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
    when(
      () => authService.authenticationSource,
    ).thenReturn(AuthenticationSource.divineOAuth);
  });

  ProviderContainer containerWith({
    required AuthState authState,
    Future<ProtectedMinorStatus> Function()? status,
  }) {
    final container = ProviderContainer(
      overrides: [
        currentAuthStateProvider.overrideWithValue(authState),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authServiceProvider.overrideWithValue(authService),
        if (status != null)
          protectedMinorStatusProvider.overrideWith((ref) => status()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('featuredTabViewerIsMinorProvider', () {
    test('gates a trusted protected-minor verdict (tabs hidden)', () async {
      final container = containerWith(
        authState: AuthState.authenticated,
        status: () async => ProtectedMinorStatus.protected(),
      );
      await container.read(protectedMinorStatusProvider.future);

      expect(container.read(featuredTabViewerIsMinorProvider), isTrue);
    });

    test(
      'does not gate a trusted not-protected verdict (tabs shown)',
      () async {
        final container = containerWith(
          authState: AuthState.authenticated,
          status: () async => ProtectedMinorStatus.notProtected(),
        );
        await container.read(protectedMinorStatusProvider.future);

        expect(container.read(featuredTabViewerIsMinorProvider), isFalse);
      },
    );

    test(
      'gates an unresolved check on a could-be-checked account (tabs hidden)',
      () {
        // Load-bearing: this is the #7675 gap the middle path closes. An OAuth
        // account whose Keycast verdict is unresolved (cold start, offline,
        // suppressed) must hide age-restricted tabs. The prior fail-OPEN
        // isProtectedMinorProvider backing returned false here — showing the
        // tabs to a possible minor.
        final container = containerWith(
          authState: AuthState.authenticated,
          status: () => Completer<ProtectedMinorStatus>().future,
        );

        expect(container.read(featuredTabViewerIsMinorProvider), isTrue);
      },
    );

    test(
      'does not gate an unresolved check on a pure self-custody account '
      '(tabs shown)',
      () {
        // The middle path must not over-block: a self-custody account Keycast
        // can never produce a verdict for stays permissive even while the
        // check is unresolved.
        when(
          () => authService.authenticationSource,
        ).thenReturn(AuthenticationSource.importedKeys);
        final container = containerWith(
          authState: AuthState.authenticated,
          status: () => Completer<ProtectedMinorStatus>().future,
        );

        expect(container.read(featuredTabViewerIsMinorProvider), isFalse);
      },
    );

    test(
      'gates an unresolved check on a previously-Keycast self-custody account '
      '(tabs hidden)',
      () async {
        // A self-held key that was Keycast-custodial on this device can still
        // receive a verdict, so an unresolved check must fail closed here. This
        // pins the sticky wasKeycastAccountFor branch, distinct from the OAuth
        // branch above — and shares the importedKeys source with the permissive
        // test, proving the gate keys off the Keycast marker, not the source.
        await ProtectedMinorStickyStore(
          prefs: prefs,
        ).markKeycastAccount(pubkey);
        when(
          () => authService.authenticationSource,
        ).thenReturn(AuthenticationSource.importedKeys);
        final container = containerWith(
          authState: AuthState.authenticated,
          status: () => Completer<ProtectedMinorStatus>().future,
        );

        expect(container.read(featuredTabViewerIsMinorProvider), isTrue);
      },
    );
  });
}

// ABOUTME: Tests isDmRestrictedProvider (#176) — the fail-CLOSED DM-restriction
// ABOUTME: seam: only a positive not-protected verdict (trusted live or
// ABOUTME: persisted) lifts the restriction; every absent answer restricts.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
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
    AuthenticationSource authSource = AuthenticationSource.divineOAuth,
  }) {
    when(() => authService.authenticationSource).thenReturn(authSource);
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

  test('Keycast account is restricted while unresolved with no verdict', () {
    // Cold start / keycast outage / suppressed check on a never-seen Keycast
    // account: fail closed. The restricted party can trivially produce this
    // state (airplane mode, cleared storage), so it must not lift the gate.
    final container = containerWith(
      authState: AuthState.authenticated,
      status: () => Completer<ProtectedMinorStatus>().future,
    );

    expect(container.read(isDmRestrictedProvider), isTrue);
  });

  test(
    'non-Keycast account is unrestricted when Keycast verdict is absent',
    () {
      // Self-custody accounts are outside Keycast's verified-minor signal. An
      // absent Keycast verdict for them is structurally inapplicable, not a
      // suppressible signal.
      final container = containerWith(
        authState: AuthState.authenticated,
        authSource: AuthenticationSource.importedKeys,
        status: () => Completer<ProtectedMinorStatus>().future,
      );

      expect(container.read(isDmRestrictedProvider), isFalse);
    },
  );

  test('unauthenticated with no verdict persisted is restricted', () {
    final container = containerWith(authState: AuthState.unauthenticated);

    expect(container.read(isDmRestrictedProvider), isTrue);
  });

  test('a trusted not-protected answer lifts the restriction', () async {
    final container = containerWith(
      authState: AuthState.authenticated,
      status: () async => ProtectedMinorStatus.notProtected(),
    );
    await container.read(protectedMinorStatusProvider.future);

    expect(container.read(isDmRestrictedProvider), isFalse);
  });

  test('a trusted protected answer restricts', () async {
    final container = containerWith(
      authState: AuthState.authenticated,
      status: () async => ProtectedMinorStatus.protected(),
    );
    await container.read(protectedMinorStatusProvider.future);

    expect(container.read(isDmRestrictedProvider), isTrue);
  });

  test('a trusted verdict persists and relaxes the next cold start', () async {
    final first = containerWith(
      authState: AuthState.authenticated,
      status: () async => ProtectedMinorStatus.notProtected(),
    );
    await first.read(protectedMinorStatusProvider.future);
    expect(first.read(isDmRestrictedProvider), isFalse);

    // Next session: status unresolved (e.g. offline), but the persisted
    // positive not-protected verdict keeps an adult unrestricted.
    final second = containerWith(
      authState: AuthState.authenticated,
      status: () => Completer<ProtectedMinorStatus>().future,
    );
    expect(second.read(isDmRestrictedProvider), isFalse);
  });

  test('sticky protected survives an unresolved recheck (token gap)', () async {
    final store = ProtectedMinorStickyStore(prefs: prefs);
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());

    final container = containerWith(
      authState: AuthState.authenticated,
      status: () => Completer<ProtectedMinorStatus>().future,
    );

    expect(container.read(isDmRestrictedProvider), isTrue);
  });

  test(
    'ever-Keycast pubkey remains restricted after imported-key reauth',
    () async {
      final store = ProtectedMinorStickyStore(prefs: prefs);
      await store.markKeycastAccount(pubkey);

      final container = containerWith(
        authState: AuthState.authenticated,
        authSource: AuthenticationSource.importedKeys,
        status: () => Completer<ProtectedMinorStatus>().future,
      );

      expect(container.read(isDmRestrictedProvider), isTrue);
    },
  );

  test('an unknown resolution falls back to the persisted verdict', () async {
    final store = ProtectedMinorStickyStore(prefs: prefs);
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.notProtected());

    final container = containerWith(
      authState: AuthState.authenticated,
      status: () async => ProtectedMinorStatus.unknown(),
    );
    await container.read(protectedMinorStatusProvider.future);

    expect(container.read(isDmRestrictedProvider), isFalse);
  });

  test('an unknown resolution never creates a relaxing verdict', () async {
    final container = containerWith(
      authState: AuthState.authenticated,
      status: () async => ProtectedMinorStatus.unknown(),
    );
    await container.read(protectedMinorStatusProvider.future);

    expect(container.read(isDmRestrictedProvider), isTrue);
    final store = ProtectedMinorStickyStore(prefs: prefs);
    expect(store.lastKnownFor(pubkey), isNull);
  });

  // The fail direction per auth source with no verdict anywhere (live status
  // unresolved, nothing persisted). Keycast-backed or not-yet-known sources
  // fail closed; pure self-custody sources Keycast can never answer for are
  // unrestricted (#6300). Pinning every source stops a refactor from silently
  // moving one in either direction.
  group('per-auth-source fail direction with an absent verdict', () {
    for (final source in AuthenticationSource.values) {
      final expectRestricted = switch (source) {
        // `none` is the initial value while the source restores after the
        // pubkey on cold start: not yet known whether Keycast applies.
        AuthenticationSource.none => true,
        AuthenticationSource.divineOAuth => true,
        AuthenticationSource.automatic ||
        AuthenticationSource.importedKeys ||
        AuthenticationSource.bunker ||
        AuthenticationSource.amber ||
        AuthenticationSource.nip07 => false,
      };

      test(
        '$source -> ${expectRestricted ? 'restricted' : 'unrestricted'}',
        () {
          final container = containerWith(
            authState: AuthState.authenticated,
            authSource: source,
            status: () => Completer<ProtectedMinorStatus>().future,
          );

          expect(container.read(isDmRestrictedProvider), expectRestricted);
        },
      );
    }
  });

  // A pubkey previously seen by Keycast stays fail-closed under any
  // self-custody source, since the same pubkey can flip auth sources on one
  // device and Keycast may hold a verdict for it.
  group('ever-Keycast pubkey stays restricted under self-custody sources', () {
    for (final source in [
      AuthenticationSource.automatic,
      AuthenticationSource.importedKeys,
      AuthenticationSource.bunker,
      AuthenticationSource.amber,
      AuthenticationSource.nip07,
    ]) {
      test('$source with Keycast marker -> restricted', () async {
        final store = ProtectedMinorStickyStore(prefs: prefs);
        await store.markKeycastAccount(pubkey);

        final container = containerWith(
          authState: AuthState.authenticated,
          authSource: source,
          status: () => Completer<ProtectedMinorStatus>().future,
        );

        expect(container.read(isDmRestrictedProvider), isTrue);
      });
    }
  });
}

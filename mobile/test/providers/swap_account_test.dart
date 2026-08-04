// ABOUTME: Tests swapAccount orchestration — build, sign in, swap; roll back
// ABOUTME: (dispose the new container, leave the old) when sign-in fails.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
// Override lives in riverpod's misc barrel; flutter_riverpod does not
// re-export the type name even though it accepts List<Override>.
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

bool _isDisposed(ProviderContainer c) {
  try {
    c.read(sharedPreferencesProvider);
    return false;
    // A disposed ProviderContainer throws StateError on read — that is exactly
    // the disposal signal these tests assert on, so catching it is intentional.
    // ignore: avoid_catching_errors
  } on StateError {
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DeviceScope deviceScope;
  late AccountSwitchController controller;
  late _FakeSecureKeyStorage keyStorage;
  late _FakeAuthService currentAuthService;

  const leavingHex =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const targetHex =
      '1111111111111111111111111111111111111111111111111111111111111111';
  // A third identity, belonging to neither account. A preserve case built on
  // the target's own npub cannot fail: both the retarget branch and the
  // preserve branch emit the same string.
  const strangerHex =
      '3333333333333333333333333333333333333333333333333333333333333333';
  final leavingNpub = NostrKeyUtils.encodePubKey(leavingHex);
  final targetNpub = NostrKeyUtils.encodePubKey(targetHex);
  final strangerNpub = NostrKeyUtils.encodePubKey(strangerHex);

  final account = KnownAccount(
    pubkeyHex: targetHex,
    authSource: AuthenticationSource.automatic,
    addedAt: DateTime(2026),
    lastUsedAt: DateTime(2026),
  );

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    controller = AccountSwitchController();
    keyStorage = _FakeSecureKeyStorage();
    currentAuthService = _FakeAuthService();
    deviceScope = DeviceScope(
      database: database,
      sharedPreferences: prefs,
      switchController: controller,
      accountOverrides: [
        secureKeyStorageProvider.overrideWithValue(keyStorage),
      ],
    );
  });

  tearDown(() => database.close());

  group('accountSwitchInitialLocation', () {
    test('retargets the leaving account own-profile route', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$leavingNpub',
          currentNpub: leavingNpub,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub',
      );
    });

    test('retargets the relative own-profile route', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/me',
          currentNpub: leavingNpub,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub',
      );
    });

    test('retargets own-profile video routes and preserves URI metadata', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$leavingNpub/7?source=notification#clip',
          currentNpub: leavingNpub,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub/7?source=notification#clip',
      );
    });

    test('preserves another user profile', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$strangerNpub',
          currentNpub: leavingNpub,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$strangerNpub',
      );
    });

    test('preserves a profile route when the leaving identity is unknown', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$leavingNpub',
          currentNpub: null,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$leavingNpub',
      );
    });

    test('preserves a non-profile route that carries the leaving npub', () {
      // Two segments, so this reaches the identity clause that `/settings`
      // exits before — it pins the first-segment guard, not the length guard.
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile-view/$leavingNpub',
          currentNpub: leavingNpub,
          targetPubkeyHex: targetHex,
        ),
        '/profile-view/$leavingNpub',
      );
    });

    test('preserves a single-segment route', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/settings',
          currentNpub: leavingNpub,
          targetPubkeyHex: targetHex,
        ),
        '/settings',
      );
    });

    test('returns null when there is no current location', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: null,
          currentNpub: leavingNpub,
          targetPubkeyHex: targetHex,
        ),
        isNull,
      );
    });
  });

  Future<ProviderContainer> pumpHost(
    WidgetTester tester, {
    List<Override> accountOverrides = const [],
    Widget Function(ProviderContainer container)? childBuilder,
  }) async {
    final initial = buildAccountContainer(
      deviceScope,
      accountOverrides: accountOverrides,
    );
    await tester.pumpWidget(
      ContainerSwapHost(
        initialContainer: initial,
        controller: controller,
        child: childBuilder?.call(initial) ?? const SizedBox(),
      ),
    );
    return initial;
  }

  /// Switches away from [from] and reports the location [swapAccount] seeded
  /// into the container it built for the target account.
  ///
  /// The router has to be both created in the container and mounted in a
  /// `Router` widget. `_currentRouterLocation` gates on
  /// `container.exists(goRouterProvider)`, and `currentConfiguration` stays
  /// `RouteMatchList.empty` until a `Router` attaches and parses the initial
  /// location — without either, it returns null and the whole retarget path
  /// goes inert.
  Future<String?> seededLocationSwitchingFrom(
    WidgetTester tester,
    String from,
  ) async {
    final auth = _MockAuthService();
    when(() => auth.currentNpub).thenReturn(leavingNpub);
    final router = GoRouter(
      initialLocation: from,
      routes: [
        GoRoute(
          path: ProfileScreenRouter.pathWithNpub,
          builder: (_, _) => const SizedBox(),
        ),
        GoRoute(
          path: ProfileScreenRouter.pathWithIndex,
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpHost(
      tester,
      accountOverrides: [
        goRouterProvider.overrideWithValue(router),
        authServiceProvider.overrideWithValue(auth),
      ],
      childBuilder: (container) =>
          MaterialApp.router(routerConfig: container.read(goRouterProvider)),
    );

    String? seeded;
    await swapAccount(
      deviceScope: deviceScope,
      controller: controller,
      currentAuthService: currentAuthService,
      account: account,
      signIn: (container, _) async {
        seeded = container.read(routerInitialLocationProvider);
      },
    );
    await tester.pump();
    return seeded;
  }

  testWidgets('seeds the swapped-in container with the retargeted route', (
    tester,
  ) async {
    expect(
      await seededLocationSwitchingFrom(
        tester,
        ProfileScreenRouter.pathForNpub(leavingNpub),
      ),
      ProfileScreenRouter.pathForNpub(targetNpub),
    );
  });

  testWidgets('seeds another user profile route unchanged', (tester) async {
    expect(
      await seededLocationSwitchingFrom(
        tester,
        ProfileScreenRouter.pathForNpub(strangerNpub),
      ),
      ProfileScreenRouter.pathForNpub(strangerNpub),
    );
  });

  testWidgets('signs in a fresh container and swaps it in', (tester) async {
    final initial = await pumpHost(tester);
    ProviderContainer? signedInto;

    await swapAccount(
      deviceScope: deviceScope,
      controller: controller,
      currentAuthService: currentAuthService,
      account: account,
      signIn: (container, acct) async {
        signedInto = container;
        expect(acct, equals(account));
      },
    );
    await tester.pump();

    // Signed into a freshly-built container, not the initial one.
    expect(signedInto, isNotNull);
    expect(signedInto, isNot(same(initial)));
    // The new container is live; the old one was disposed by the swap.
    expect(_isDisposed(signedInto!), isFalse);
    expect(_isDisposed(initial), isTrue);
  });

  testWidgets('rolls back when sign-in fails', (tester) async {
    final initial = await pumpHost(tester);
    ProviderContainer? attempted;
    keyStorage.primary = _FakeSecureKeyContainer(
      npub: 'npub_previous',
      publicKeyHex:
          '2222222222222222222222222222222222222222222222222222222222222222',
    );

    await expectLater(
      swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (container, acct) async {
          attempted = container;
          throw Exception('signer unreachable');
        },
      ),
      throwsException,
    );
    await tester.pump();

    // The half-built container is disposed; the current account is untouched.
    expect(attempted, isNotNull);
    expect(_isDisposed(attempted!), isTrue);
    expect(_isDisposed(initial), isFalse);
    expect(keyStorage.restoredPrimary, same(keyStorage.primary));
    // A sign-in that got far enough to fail already restored the target
    // account's signer keys and auth source over the shared slots. Disposing
    // its container does not undo that — the leaving account's own keys have
    // to go back, or it reads the wrong signer at the next launch.
    expect(currentAuthService.calls, equals(['archive', 'restore']));
  });

  testWidgets('archives the leaving account before signing the new one in', (
    tester,
  ) async {
    await pumpHost(tester);

    await swapAccount(
      deviceScope: deviceScope,
      controller: controller,
      currentAuthService: currentAuthService,
      account: account,
      signIn: (_, _) async => currentAuthService.calls.add('signIn'),
    );
    await tester.pump();

    // Signing the incoming account in overwrites the shared signer slots, so
    // the leaving account's credentials must already be in its own archive.
    expect(currentAuthService.calls, equals(['archive', 'signIn']));
  });

  testWidgets('aborts before building anything when the archive fails', (
    tester,
  ) async {
    final initial = await pumpHost(tester);
    currentAuthService.archiveError = Exception('keychain unavailable');
    var signInAttempted = false;

    await expectLater(
      swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (_, _) async => signInAttempted = true,
      ),
      throwsException,
    );
    await tester.pump();

    // Carrying on past a failed archive would let the incoming sign-in wipe
    // the shared slots the archive was meant to copy, destroying the leaving
    // account's session for a log line.
    expect(signInAttempted, isFalse);
    expect(_isDisposed(initial), isFalse);
  });

  testWidgets('surfaces the sign-in failure even when the rollback throws', (
    tester,
  ) async {
    await pumpHost(tester);
    keyStorage.primary = _FakeSecureKeyContainer(
      npub: 'npub_previous',
      publicKeyHex:
          '2222222222222222222222222222222222222222222222222222222222222222',
    );
    keyStorage.restoreError = Exception('primary restore failed');

    // The caller dispatches on this type to offer a fresh sign-in, so a
    // rollback failure must not replace it with its own.
    await expectLater(
      swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (_, _) async => throw _FakeSignInException(),
      ),
      throwsA(isA<_FakeSignInException>()),
    );
    await tester.pump();

    // The signer restore is ordered ahead of the throwing primary restore, so
    // it still ran.
    expect(currentAuthService.calls, equals(['archive', 'restore']));
  });
}

class _FakeSignInException implements Exception {}

class _FakeAuthService implements AuthService {
  final calls = <String>[];

  /// Set to make the pre-swap archive fail, as a keychain write would.
  Object? archiveError;

  @override
  Future<void> archiveCurrentSignerInfo() async {
    calls.add('archive');
    final error = archiveError;
    if (error != null) throw error;
  }

  @override
  Future<void> restoreSignerInfoForCurrentAccount() async =>
      calls.add('restore');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureKeyStorage extends SecureKeyStorage {
  SecureKeyContainer? primary;
  SecureKeyContainer? restoredPrimary;

  /// Set to make the rollback's primary restore fail. The real one can: it
  /// hands the snapshot to `storeKey`, which reaches into the private key.
  Object? restoreError;

  @override
  Future<SecureKeyContainer?> getKeyContainer({String? biometricPrompt}) async {
    return primary;
  }

  @override
  Future<void> restorePrimaryKeyContainer(
    SecureKeyContainer? keyContainer, {
    String? biometricPrompt,
  }) async {
    final error = restoreError;
    if (error != null) throw error;
    restoredPrimary = keyContainer;
    primary = keyContainer;
  }
}

class _FakeSecureKeyContainer implements SecureKeyContainer {
  _FakeSecureKeyContainer({required this.npub, required this.publicKeyHex});

  @override
  final String npub;

  @override
  final String publicKeyHex;

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ABOUTME: Tests swapAccount orchestration — build, sign in, swap; roll back
// ABOUTME: (dispose the new container, leave the old) when sign-in fails.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final account = KnownAccount(
    pubkeyHex:
        '1111111111111111111111111111111111111111111111111111111111111111',
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
    const leavingHex =
        '2222222222222222222222222222222222222222222222222222222222222222';
    const targetHex =
        '1111111111111111111111111111111111111111111111111111111111111111';
    final leavingNpub = NostrKeyUtils.encodePubKey(leavingHex);
    final targetNpub = NostrKeyUtils.encodePubKey(targetHex);

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

    test('preserves another user profile and non-profile routes', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$targetNpub',
          currentNpub: leavingNpub,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub',
      );
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/settings',
          currentNpub: leavingNpub,
          targetPubkeyHex: targetHex,
        ),
        '/settings',
      );
    });
  });

  Future<ProviderContainer> pumpHost(WidgetTester tester) async {
    final initial = buildAccountContainer(deviceScope);
    await tester.pumpWidget(
      ContainerSwapHost(
        initialContainer: initial,
        controller: controller,
        child: const SizedBox(),
      ),
    );
    return initial;
  }

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

// ABOUTME: Tests swapAccount orchestration — build, sign in, swap; roll back
// ABOUTME: (dispose the new container, leave the old) when sign-in fails.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/swap_account.dart';
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
    deviceScope = DeviceScope(
      database: database,
      sharedPreferences: prefs,
      secureStorage: const FlutterSecureStorage(),
    );
    controller = AccountSwitchController();
  });

  tearDown(() => database.close());

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

    await expectLater(
      swapAccount(
        deviceScope: deviceScope,
        controller: controller,
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
  });
}

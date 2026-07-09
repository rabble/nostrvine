// ABOUTME: Tests isKeyManagementRestrictedProvider (#182) — the fail-CLOSED gate
// ABOUTME: for nsec export + key import/change. Delegates to the #176 DM seam, so
// ABOUTME: an unresolved / suppressed protected-minor check must restrict.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
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

  test('restricted while the protected-minor check is unresolved', () {
    // Fail closed: a suppressed/cold-start check on a never-seen account must
    // hide the key-export/import affordances. This is exactly where the
    // fail-OPEN isProtectedMinorProvider would (wrongly) return false.
    final container = containerWith(
      authState: AuthState.authenticated,
      status: () => Completer<ProtectedMinorStatus>().future,
    );

    expect(container.read(isKeyManagementRestrictedProvider), isTrue);
  });

  test('restricted for a trusted protected-minor verdict', () async {
    final container = containerWith(
      authState: AuthState.authenticated,
      status: () async => ProtectedMinorStatus.protected(),
    );
    await container.read(protectedMinorStatusProvider.future);

    expect(container.read(isKeyManagementRestrictedProvider), isTrue);
  });

  test('unrestricted only for a trusted not-protected verdict', () async {
    final container = containerWith(
      authState: AuthState.authenticated,
      status: () async => ProtectedMinorStatus.notProtected(),
    );
    await container.read(protectedMinorStatusProvider.future);

    expect(container.read(isKeyManagementRestrictedProvider), isFalse);
  });
}

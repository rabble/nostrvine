// ABOUTME: Tests protectedMinorStatusProvider guard branches (#174):
// ABOUTME: unauthenticated -> not protected, debug override forces protected.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unauthenticated resolves to not-protected without any fetch', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final status = await container.read(protectedMinorStatusProvider.future);

    expect(status.isProtectedMinor, isFalse);
  });

  test('debug override forces protected when authenticated', () async {
    SharedPreferences.setMockInitialValues({'protected_minor_override': true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final status = await container.read(protectedMinorStatusProvider.future);

    expect(status.isProtectedMinor, isTrue);
  });
}

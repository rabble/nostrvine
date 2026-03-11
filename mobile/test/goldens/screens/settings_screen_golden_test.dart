// ABOUTME: Golden test for the reskinned settings screen
// ABOUTME: Verifies the approved dark-mode Figma-inspired top-of-screen layout

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('SettingsScreen Golden Tests', () {
    late _MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;

    setUpAll(() async {
      await loadAppFonts();
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'OpenVine',
        packageName: 'video.openvine.app',
        version: '1.0.4',
        buildNumber: '332',
        buildSignature: '',
        installerStore: 'test',
      );
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(false);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(
        () => mockAuthService.hasExpiredOAuthSession,
      ).thenReturn(false);
    });

    Widget createSettingsScreen() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        ],
        child: MaterialApp(
          theme: VineTheme.theme,
          home: const SettingsScreen(),
        ),
      );
    }

    testGoldens('SettingsScreen dark layout', (tester) async {
      await tester.pumpWidgetBuilder(
        createSettingsScreen(),
        surfaceSize: const Size(402, 874),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'settings_screen_dark');
    });
  });
}

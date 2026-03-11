// ABOUTME: Widget tests for the settings screen account summary block
// ABOUTME: Verifies the Figma-style top block across auth-related states

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('SettingsScreen account summary', () {
    late _MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
    });

    Future<void> pumpSettingsScreen(
      WidgetTester tester, {
      bool isAnonymous = false,
      bool hasExpiredOAuthSession = false,
    }) async {
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(isAnonymous);
      when(
        () => mockAuthService.hasExpiredOAuthSession,
      ).thenReturn(hasExpiredOAuthSession);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'authenticated users see the summary block and switch account row',
      (tester) async {
        await pumpSettingsScreen(tester);

        expect(find.text('Currently logged in'), findsOneWidget);
        expect(find.text('Switch Account'), findsOneWidget);
      },
    );

    testWidgets(
      'anonymous users see the local account summary and secure action',
      (tester) async {
        await pumpSettingsScreen(tester, isAnonymous: true);

        expect(find.text('Local account'), findsOneWidget);
        expect(find.text('Secure Your Account'), findsOneWidget);
      },
    );

    testWidgets(
      'expired sessions show recovery messaging in the account block',
      (tester) async {
        await pumpSettingsScreen(tester, hasExpiredOAuthSession: true);

        expect(find.text('Session expired'), findsOneWidget);
        expect(find.text('Session Expired'), findsOneWidget);
      },
    );
  });
}

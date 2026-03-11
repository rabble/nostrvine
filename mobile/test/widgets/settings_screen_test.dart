// ABOUTME: Widget tests for the Figma-reskinned settings screen layout
// ABOUTME: Verifies section grouping and preservation of key settings actions

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
  group('SettingsScreen', () {
    late _MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(false);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(
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

    Future<void> pumpSettingsScreen(
      WidgetTester tester, {
      AuthState authState = AuthState.authenticated,
      bool isAnonymous = false,
      bool hasExpiredOAuthSession = false,
    }) async {
      when(() => mockAuthService.authState).thenReturn(authState);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(authState));
      when(() => mockAuthService.isAuthenticated).thenReturn(
        authState == AuthState.authenticated,
      );
      when(() => mockAuthService.isAnonymous).thenReturn(isAnonymous);
      when(
        () => mockAuthService.hasExpiredOAuthSession,
      ).thenReturn(hasExpiredOAuthSession);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            currentAuthStateProvider.overrideWithValue(authState),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('groups rows using the new Figma-style sections', (
      tester,
    ) async {
      await pumpSettingsScreen(tester);

      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Safety & Privacy'), findsOneWidget);
      expect(find.text('PROFILE'), findsNothing);
      expect(find.text('NETWORK'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Nostr Settings'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nostr Settings'), findsOneWidget);
      expect(find.text('Relays'), findsOneWidget);
      expect(find.text('Media Servers'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Support'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Account Tools'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account Tools'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Danger Zone'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Danger Zone'), findsOneWidget);
      expect(find.textContaining('Version '), findsOneWidget);
    });

    testWidgets('keeps advanced and destructive actions reachable', (
      tester,
    ) async {
      await pumpSettingsScreen(tester);

      await tester.scrollUntilVisible(
        find.text('Developer Options'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Developer Options'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Key Management'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Key Management'), findsOneWidget);
      expect(find.text('Remove Keys from Device'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Delete Account and Data'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Account and Data'), findsOneWidget);
    });

    testWidgets('shows the settings app bar title', (tester) async {
      await pumpSettingsScreen(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}

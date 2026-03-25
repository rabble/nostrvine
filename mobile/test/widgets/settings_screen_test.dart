// ABOUTME: Widget test for settings hub screen
// ABOUTME: Verifies account header, auth-state tiles, and navigation structure

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/go_router.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(SettingsScreen, () {
    late _MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(false);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('abc123pubkey');
      when(
        () => mockAuthService.authState,
      ).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(
        () => mockAuthService.hasExpiredOAuthSession,
      ).thenReturn(false);
    });

    Widget buildSubject({
      AuthState authState = AuthState.authenticated,
      MockGoRouter? goRouter,
    }) {
      final app = ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          currentAuthStateProvider.overrideWith((ref) => authState),
          userProfileReactiveProvider.overrideWith(
            (ref, pubkey) => Stream.value(null),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      );

      if (goRouter == null) {
        return app;
      }

      return MockGoRouterProvider(goRouter: goRouter, child: app);
    }

    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders centered account header when authenticated', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders Switch account button when authenticated', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Switch account'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders navigation tiles', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);

      expect(find.text('Creator Analytics'), findsOneWidget);
      expect(find.text('Support Center'), findsOneWidget);

      // Tiles below the centered header may need scrolling
      for (final title in [
        'Notifications',
        'Content Preferences',
        'Moderation Controls',
        'Nostr Settings',
        'Apps',
        'App Permissions',
      ]) {
        await tester.scrollUntilVisible(
          find.text(title),
          100,
          scrollable: scrollable,
        );
        expect(find.text(title), findsOneWidget);
      }

      expect(
        find.text('Launch vetted Nostr apps in Divine'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('tapping App Permissions opens the permissions route', (
      tester,
    ) async {
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      await tester.scrollUntilVisible(
        find.text('App Permissions'),
        100,
        scrollable: scrollable,
      );
      await tester.tap(find.text('App Permissions'));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.push(AppsPermissionsScreen.path)).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('tapping Apps opens the directory route', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      await tester.scrollUntilVisible(
        find.text('Apps'),
        100,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Apps'));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.push(AppsDirectoryScreen.path)).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders Secure Your Account tile for anonymous users', (
      tester,
    ) async {
      when(() => mockAuthService.isAnonymous).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Secure Your Account'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders Session Expired tile when session expired', (
      tester,
    ) async {
      when(
        () => mockAuthService.hasExpiredOAuthSession,
      ).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Session Expired'), findsOneWidget);
      // Should NOT show Secure Your Account when session expired
      expect(find.text('Secure Your Account'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('hides Secure Your Account for non-anonymous users', (
      tester,
    ) async {
      when(() => mockAuthService.isAnonymous).thenReturn(false);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Secure Your Account'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('does not render account section when unauthenticated', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(authState: AuthState.unauthenticated),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsNothing);
      expect(find.text('Switch account'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}

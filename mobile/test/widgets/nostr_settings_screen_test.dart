import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(NostrSettingsScreen, () {
    late _MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
    });

    Widget buildSubject({bool advancedRelaySettingsEnabled = false}) {
      final router = GoRouter(
        initialLocation: NostrSettingsScreen.path,
        routes: [
          GoRoute(
            path: NostrSettingsScreen.path,
            builder: (context, state) => const NostrSettingsScreen(),
          ),
          GoRoute(
            path: WelcomeScreen.path,
            builder: (context, state) =>
                const SizedBox(key: Key('welcome-screen')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          currentAuthStateProvider.overrideWith(
            (ref) => AuthState.authenticated,
          ),
          isDeveloperModeEnabledProvider.overrideWithValue(false),
          isFeatureEnabledProvider(
            FeatureFlag.advancedRelaySettings,
          ).overrideWith((ref) => advancedRelaySettingsEnabled),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );
    }

    Future<void> pumpSubject(
      WidgetTester tester, {
      bool advancedRelaySettingsEnabled = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        buildSubject(
          advancedRelaySettingsEnabled: advancedRelaySettingsEnabled,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows Experimental Features tile and opens feature flags', (
      tester,
    ) async {
      await pumpSubject(tester);

      expect(find.text(l10n.settingsExperimentalFeatures), findsOneWidget);

      await tester.tap(find.text(l10n.settingsExperimentalFeatures));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureFlagScreen), findsOneWidget);
    });

    testWidgets('hides Relays and Relay Diagnostics tiles when '
        'advancedRelaySettings flag is off', (tester) async {
      await pumpSubject(tester);

      expect(find.text(l10n.nostrSettingsRelays), findsNothing);
      expect(find.text(l10n.nostrSettingsRelayDiagnostics), findsNothing);
    });

    testWidgets('shows Relays and Relay Diagnostics tiles when '
        'advancedRelaySettings flag is on', (tester) async {
      await pumpSubject(tester, advancedRelaySettingsEnabled: true);

      expect(find.text(l10n.nostrSettingsRelays), findsOneWidget);
      expect(find.text(l10n.nostrSettingsRelayDiagnostics), findsOneWidget);
    });

    testWidgets('shows NIP-05 address tile', (tester) async {
      await pumpSubject(tester);

      expect(find.text(l10n.nostrSettingsNip05Address), findsOneWidget);
      expect(find.text(l10n.nostrSettingsNip05AddressSubtitle), findsOneWidget);
    });

    testWidgets('dismisses progress overlay after removing keys succeeds', (
      tester,
    ) async {
      final signOut = Completer<void>();
      when(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).thenAnswer((_) => signOut.future);

      await pumpSubject(tester);

      await tester.tap(find.text(l10n.nostrSettingsRemoveKeys));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      signOut.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      verify(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).called(1);
    });

    testWidgets('removes local account and returns to welcome', (tester) async {
      when(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).thenAnswer((_) async {});

      await pumpSubject(tester);

      expect(find.text(l10n.nostrSettingsRemoveKeys), findsOneWidget);
      expect(find.text(l10n.nostrSettingsRemoveKeysSubtitle), findsOneWidget);

      await tester.tap(find.text(l10n.nostrSettingsRemoveKeys));
      await tester.pumpAndSettle();

      expect(find.text(l10n.deleteAccountRemoveKeysTitle), findsOneWidget);
      expect(find.text(l10n.deleteAccountRemoveKeysBody), findsOneWidget);

      await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
      await tester.pumpAndSettle();

      verify(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).called(1);
      expect(find.byKey(const Key('welcome-screen')), findsOneWidget);
    });

    testWidgets(
      'does not crash when navigation closes progress overlay first',
      (
        tester,
      ) async {
        final signOut = Completer<void>();
        when(
          () => mockAuthService.signOut(
            deleteKeys: true,
            abortOnKeyDeletionFailure: true,
          ),
        ).thenAnswer((_) => signOut.future);

        await pumpSubject(tester);

        await tester.tap(find.text(l10n.nostrSettingsRemoveKeys));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        Navigator.of(
          tester.element(find.byType(CircularProgressIndicator)),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);

        signOut.complete();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        verify(
          () => mockAuthService.signOut(
            deleteKeys: true,
            abortOnKeyDeletionFailure: true,
          ),
        ).called(1);
      },
    );

    testWidgets('dismisses progress overlay when key deletion fails', (
      tester,
    ) async {
      when(
        () => mockAuthService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      ).thenThrow(
        const SecureKeyStorageException(
          'Platform key deletion failed',
          code: 'platform_deletion_failed',
        ),
      );

      await pumpSubject(tester);

      await tester.tap(find.text(l10n.nostrSettingsRemoveKeys));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.deleteAccountRemoveKeysConfirm));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.nostrSettingsCouldNotRemoveKeys), findsOneWidget);
    });
  });
}

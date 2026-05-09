import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/nip05_settings_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/go_router.dart';

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

    Widget buildSubject({
      bool advancedRelaySettingsEnabled = false,
      MockGoRouter? goRouter,
    }) {
      final app = ProviderScope(
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
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrSettingsScreen(),
        ),
      );

      if (goRouter == null) {
        return app;
      }

      return MockGoRouterProvider(goRouter: goRouter, child: app);
    }

    testWidgets('shows Experimental Features tile and opens feature flags', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsExperimentalFeatures), findsOneWidget);

      await tester.tap(find.text(l10n.settingsExperimentalFeatures));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureFlagScreen), findsOneWidget);
    });

    testWidgets('hides Relays and Relay Diagnostics tiles when '
        'advancedRelaySettings flag is off', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.nostrSettingsRelays), findsNothing);
      expect(find.text(l10n.nostrSettingsRelayDiagnostics), findsNothing);
    });

    testWidgets('shows Relays and Relay Diagnostics tiles when '
        'advancedRelaySettings flag is on', (tester) async {
      await tester.pumpWidget(buildSubject(advancedRelaySettingsEnabled: true));
      await tester.pumpAndSettle();

      expect(find.text(l10n.nostrSettingsRelays), findsOneWidget);
      expect(find.text(l10n.nostrSettingsRelayDiagnostics), findsOneWidget);
    });

    testWidgets('shows NIP-05 address tile', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.nostrSettingsNip05Address), findsOneWidget);
      expect(find.text(l10n.nostrSettingsNip05AddressSubtitle), findsOneWidget);
    });

    testWidgets('opens NIP-05 settings via named route', (tester) async {
      final goRouter = MockGoRouter();
      when(
        () => goRouter.pushNamed(
          any(),
          pathParameters: any(named: 'pathParameters'),
          extra: any(named: 'extra'),
        ),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(goRouter: goRouter));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.nostrSettingsNip05Address));
      await tester.pumpAndSettle();

      verify(
        () => goRouter.pushNamed(
          Nip05SettingsScreen.routeName,
          pathParameters: any(named: 'pathParameters'),
          extra: any(named: 'extra'),
        ),
      ).called(1);
    });
  });
}

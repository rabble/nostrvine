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
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(NostrSettingsScreen, () {
    late _MockAuthService mockAuthService;
    late SharedPreferences sharedPreferences;
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
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NostrSettingsScreen(),
        ),
      );
    }

    testWidgets('shows Experimental Features tile and opens feature flags', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Experimental Features'), findsOneWidget);

      await tester.tap(find.text('Experimental Features'));
      await tester.pumpAndSettle();

      expect(find.byType(FeatureFlagScreen), findsOneWidget);
    });

    testWidgets('hides Relays and Relay Diagnostics tiles when '
        'advancedRelaySettings flag is off', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Relays'), findsNothing);
      expect(find.text('Relay Diagnostics'), findsNothing);
    });

    testWidgets('shows Relays and Relay Diagnostics tiles when '
        'advancedRelaySettings flag is on', (tester) async {
      await tester.pumpWidget(buildSubject(advancedRelaySettingsEnabled: true));
      await tester.pumpAndSettle();

      expect(find.text('Relays'), findsOneWidget);
      expect(find.text('Relay Diagnostics'), findsOneWidget);
    });
  });
}

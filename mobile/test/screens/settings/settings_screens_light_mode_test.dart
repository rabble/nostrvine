// ABOUTME: Pumps real settings screens under VineTheme.lightTheme and proves
// ABOUTME: they paint light tokens instead of silently resolving the dark fallback.
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/appearance_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

void main() {
  group('settings screens in light mode', () {
    late _MockAuthService authService;
    late _MockLocaleCubit localeCubit;
    late SharedPreferences preferences;

    setUp(() async {
      // The dark fallback is silent by design, so a light-mode leak is only
      // observable through this counter — reset it around every pump.
      VineThemeColors.debugFallbackCount = 0;
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      authService = _MockAuthService();
      localeCubit = _MockLocaleCubit();
      when(() => localeCubit.state).thenReturn(const LocaleState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.isAnonymous).thenReturn(false);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    });

    tearDown(() => VineThemeColors.debugFallbackCount = 0);

    testWidgets('SettingsScreen paints the light palette', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: MaterialApp(
            theme: VineTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<LocaleCubit>.value(
              value: localeCubit,
              child: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, VineTheme.lightColors.surface);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, VineTheme.lightColors.nav);

      expect(
        VineThemeColors.debugFallbackCount,
        0,
        reason:
            'A widget resolved context.vineColors from a context without the '
            'VineThemeColors extension and rendered dark tokens on a light '
            'page. Check for a nested Theme/MaterialApp that drops extensions.',
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('AppearanceSettingsScreen paints the light palette', (
      tester,
    ) async {
      final cubit = AppearanceCubit(AppearanceRepository(preferences));
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const AppearanceSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final title = tester.widget<Text>(
        find.text(l10n.appearanceSettingsLight),
      );
      expect(title.style?.color, VineTheme.lightColors.primaryText);
      expect(VineThemeColors.debugFallbackCount, 0);
    });

    testWidgets('the dark fallback stays reachable without the extension', (
      tester,
    ) async {
      // Guards the counter itself: if this stopped incrementing, the two
      // assertions above would pass for the wrong reason.
      final cubit = AppearanceCubit(AppearanceRepository(preferences));
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const AppearanceSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(VineThemeColors.debugFallbackCount, greaterThan(0));
    });
  });
}

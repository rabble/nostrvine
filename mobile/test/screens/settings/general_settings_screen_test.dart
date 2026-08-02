// ABOUTME: Widget tests for General Settings integrations section visibility.
// ABOUTME: Pins the Integrations header to at least one visible integration tile.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockAudioSharingPreferenceService extends Mock
    implements AudioSharingPreferenceService {}

void main() {
  group('GeneralSettingsScreen integrations section', () {
    late SharedPreferences sharedPreferences;
    late _MockAuthService authService;
    late _MockLocaleCubit localeCubit;
    late _MockAudioSharingPreferenceService audioSharingService;
    late FeedAspectRatioPreferenceService aspectRatioService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      aspectRatioService = FeedAspectRatioPreferenceService(sharedPreferences);
      authService = _MockAuthService();
      localeCubit = _MockLocaleCubit();
      audioSharingService = _MockAudioSharingPreferenceService();

      when(() => localeCubit.state).thenReturn(const LocaleState());
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.isRegistered).thenReturn(false);
      when(() => authService.isAnonymous).thenReturn(false);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);
      when(() => authService.getKnownAccounts()).thenAnswer((_) async => []);
      when(() => authService.currentPublicKeyHex).thenReturn(null);
      when(() => audioSharingService.isAudioSharingEnabled).thenReturn(false);
      when(
        () => audioSharingService.setAudioSharingEnabled(any()),
      ).thenAnswer((_) async {});
    });

    List<dynamic> baseOverrides() => [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      authServiceProvider.overrideWithValue(authService),
      currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
      audioSharingPreferenceServiceProvider.overrideWithValue(
        audioSharingService,
      ),
      feedAspectRatioPreferenceServiceProvider.overrideWithValue(
        aspectRatioService,
      ),
    ];

    Widget wrap(
      Widget child, {
      List<dynamic> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [...baseOverrides(), ...overrides],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<LocaleCubit>.value(
            value: localeCubit,
            child: child,
          ),
        ),
      );
    }

    Future<AppLocalizations> l10n() async {
      await AppLocalizations.delegate.load(const Locale('en'));
      return lookupAppLocalizations(const Locale('en'));
    }

    testWidgets(
      'hides the Integrations header when no integration tile is visible',
      (tester) async {
        final labels = await l10n();

        await tester.pumpWidget(wrap(const GeneralSettingsScreen()));
        await tester.pumpAndSettle();

        expect(
          find.text(labels.generalSettingsSectionIntegrations),
          findsNothing,
        );
        expect(
          find.text(labels.settingsBlueskyPublishing),
          findsNothing,
        );
        expect(find.text(labels.settingsCrosspostingTitle), findsNothing);
        // Viewing stays reachable so the screen is still useful.
        expect(
          find.text(labels.generalSettingsSectionViewing),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows the Integrations header when crossposting is eligible',
      (tester) async {
        final labels = await l10n();

        await tester.pumpWidget(
          wrap(
            const GeneralSettingsScreen(),
            overrides: [
              crosspostingEligibleProvider.overrideWithValue(true),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(labels.generalSettingsSectionIntegrations),
          findsOneWidget,
        );
        expect(find.text(labels.settingsCrosspostingTitle), findsOneWidget);
      },
    );

    testWidgets(
      'shows the Integrations header when Bluesky publishing is enabled',
      (tester) async {
        final labels = await l10n();

        await tester.pumpWidget(
          wrap(
            const GeneralSettingsScreen(),
            overrides: [
              isFeatureEnabledProvider(
                FeatureFlag.blueskyPublishing,
              ).overrideWithValue(true),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(labels.generalSettingsSectionIntegrations),
          findsOneWidget,
        );
        expect(
          find.text(labels.settingsBlueskyPublishing),
          findsOneWidget,
        );
      },
    );

    testWidgets('square-only switch flips the feed aspect ratio preference', (
      tester,
    ) async {
      final labels = await l10n();

      await tester.pumpWidget(wrap(const GeneralSettingsScreen()));
      await tester.pumpAndSettle();

      DivineSwitchTile squareOnlyTile() => tester.widget<DivineSwitchTile>(
        find.ancestor(
          of: find.text(labels.generalSettingsVideoShapeSquareOnly),
          matching: find.byType(DivineSwitchTile),
        ),
      );

      expect(squareOnlyTile().value, isFalse);

      await tester.tap(find.text(labels.generalSettingsVideoShapeSquareOnly));
      await tester.pumpAndSettle();

      expect(
        aspectRatioService.preference,
        FeedAspectRatioPreference.squareOnly,
      );
      expect(squareOnlyTile().value, isTrue);
    });
  });
}

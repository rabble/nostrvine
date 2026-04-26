// ABOUTME: Widget tests for the Settings information architecture.
// ABOUTME: Verifies General Settings and Content & Safety replace split content/moderation rows.

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockAudioSharingPreferenceService extends Mock
    implements AudioSharingPreferenceService {}

class _MockLanguagePreferenceService extends Mock
    implements LanguagePreferenceService {}

class _MockAccountLabelService extends Mock implements AccountLabelService {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {
  @override
  Set<String> get runtimeBlockedUsers => const {};
}

void main() {
  late SharedPreferences sharedPreferences;
  late _MockAuthService authService;
  late _MockLocaleCubit localeCubit;
  late _MockAudioSharingPreferenceService audioSharingService;
  late _MockLanguagePreferenceService languageService;
  late _MockAccountLabelService accountLabelService;
  late _MockAgeVerificationService ageVerificationService;
  late _MockContentFilterService contentFilterService;
  late _MockModerationLabelService moderationLabelService;
  late _MockFollowRepository followRepository;
  late _MockContentBlocklistRepository blocklistRepository;
  late DivineHostFilterService divineHostFilterService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    authService = _MockAuthService();
    localeCubit = _MockLocaleCubit();
    audioSharingService = _MockAudioSharingPreferenceService();
    languageService = _MockLanguagePreferenceService();
    accountLabelService = _MockAccountLabelService();
    ageVerificationService = _MockAgeVerificationService();
    contentFilterService = _MockContentFilterService();
    moderationLabelService = _MockModerationLabelService();
    followRepository = _MockFollowRepository();
    blocklistRepository = _MockContentBlocklistRepository();
    divineHostFilterService = DivineHostFilterService(sharedPreferences);

    when(() => localeCubit.state).thenReturn(const LocaleState());
    when(() => authService.isAuthenticated).thenReturn(false);
    when(() => authService.isAnonymous).thenReturn(false);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    when(() => authService.getKnownAccounts()).thenAnswer((_) async => []);
    when(() => authService.currentPublicKeyHex).thenReturn(null);

    when(() => audioSharingService.isAudioSharingEnabled).thenReturn(false);
    when(
      () => audioSharingService.setAudioSharingEnabled(any()),
    ).thenAnswer((_) async {});
    when(() => languageService.contentLanguage).thenReturn('en');
    when(() => languageService.isCustomLanguageSet).thenReturn(false);
    when(() => accountLabelService.accountLabels).thenReturn(<ContentLabel>{});
    when(() => accountLabelService.initialized).thenAnswer((_) async {});
    when(() => ageVerificationService.initialize()).thenAnswer((_) async {});
    when(() => ageVerificationService.isAdultContentVerified).thenReturn(false);
    when(() => contentFilterService.initialize()).thenAnswer((_) async {});
    for (final label in ContentLabel.values) {
      when(
        () => contentFilterService.getPreference(label),
      ).thenReturn(ContentFilterPreference.warn);
    }
    when(
      () => contentFilterService.lockAdultCategories(),
    ).thenAnswer((_) async {});
    when(
      () => moderationLabelService.isDivineLabelerSubscribed,
    ).thenReturn(true);
    when(
      () => moderationLabelService.isFollowingModerationEnabled,
    ).thenReturn(false);
    when(() => moderationLabelService.customLabelers).thenReturn(<String>{});
    when(
      () => moderationLabelService.addDivineLabeler(),
    ).thenAnswer((_) async {});
    when(
      () => moderationLabelService.removeDivineLabeler(),
    ).thenAnswer((_) async {});
    when(
      () => moderationLabelService.setFollowingModerationEnabled(
        any(),
        followedPubkeys: any(named: 'followedPubkeys'),
      ),
    ).thenAnswer((_) async {});
    when(() => followRepository.followingPubkeys).thenReturn(<String>[]);
    when(
      () => followRepository.followingStream,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
  });

  List<dynamic> baseOverrides() => [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    authServiceProvider.overrideWithValue(authService),
    currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
    audioSharingPreferenceServiceProvider.overrideWithValue(
      audioSharingService,
    ),
    languagePreferenceServiceProvider.overrideWithValue(languageService),
    accountLabelServiceProvider.overrideWithValue(accountLabelService),
    ageVerificationServiceProvider.overrideWithValue(ageVerificationService),
    contentFilterServiceProvider.overrideWithValue(contentFilterService),
    moderationLabelServiceProvider.overrideWithValue(moderationLabelService),
    followRepositoryProvider.overrideWithValue(followRepository),
    contentBlocklistRepositoryProvider.overrideWithValue(blocklistRepository),
    divineHostFilterServiceProvider.overrideWithValue(divineHostFilterService),
    feedAspectRatioPreferenceServiceProvider.overrideWithValue(
      FeedAspectRatioPreferenceService(sharedPreferences),
    ),
  ];

  Widget wrap(Widget child, {List<dynamic> overrides = const []}) {
    return ProviderScope(
      overrides: [...baseOverrides(), ...overrides],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: BlocProvider<LocaleCubit>.value(value: localeCubit, child: child),
      ),
    );
  }

  testWidgets('Settings hub uses General Settings and Content & Safety', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SettingsScreen(),
        overrides: [
          isFeatureEnabledProvider(
            FeatureFlag.blueskyPublishing,
          ).overrideWithValue(true),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('General Settings'), findsOneWidget);
    expect(find.text('Content & Safety'), findsOneWidget);
    expect(find.text('Content Preferences'), findsNothing);
    expect(find.text('Moderation Controls'), findsNothing);
    expect(find.text('Bluesky Publishing'), findsNothing);
  });

  testWidgets('General Settings contains integrations and viewing defaults', (
    tester,
  ) async {
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

    expect(find.text('General Settings'), findsOneWidget);
    expect(find.text('Bluesky Publishing'), findsOneWidget);
    expect(find.text('Closed Captions'), findsOneWidget);
    expect(find.text('Video Shape'), findsOneWidget);
    expect(find.text('App Language'), findsOneWidget);
    expect(find.text('Make my audio available for reuse'), findsOneWidget);

    final captionsToggle = find.byWidgetPredicate(
      (widget) =>
          widget is SwitchListTile &&
          widget.title is Text &&
          (widget.title! as Text).data == 'Closed Captions',
    );
    expect(captionsToggle, findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(GeneralSettingsScreen)),
      ).read(subtitleVisibilityProvider),
      isTrue,
    );

    await tester.tap(captionsToggle);
    await tester.pumpAndSettle();

    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(GeneralSettingsScreen)),
      ).read(subtitleVisibilityProvider),
      isFalse,
    );
  });

  testWidgets('Content & Safety exposes content filters and account labels', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const SafetySettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Content & Safety'), findsOneWidget);
    expect(find.text('Content Filters'), findsOneWidget);
    expect(find.text('Only show Divine-hosted videos'), findsOneWidget);
    expect(find.text('Divine'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Account Labels'), findsOneWidget);
  });

  testWidgets('Content Filters constrains menu content width on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const ContentFiltersScreen()));
    await tester.pumpAndSettle();

    final listViewWidth = tester.getSize(find.byType(ListView).first).width;
    expect(listViewWidth, moreOrLessEquals(600));
  });
}

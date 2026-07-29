// ABOUTME: Widget tests for the account-switch confirmation in Settings.
// ABOUTME: Covers the in-flight-upload warning that supersedes the drafts one.

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

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

  @override
  Stream<ContentPolicyState> get stateStream =>
      const Stream<ContentPolicyState>.empty();
}

class _MockVideoEventService extends Mock implements VideoEventService {
  @override
  int filterAdultContentFromExistingVideos() => 0;
}

void main() {
  const currentPubkey =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  const otherPubkey =
      'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';

  late SharedPreferences sharedPreferences;
  late _MockAuthService authService;
  late _MockLocaleCubit localeCubit;
  late _MockInviteStatusCubit inviteStatusCubit;
  late _MockBackgroundPublishBloc publishBloc;
  late _MockDraftStorageService draftStorageService;
  late _MockAudioSharingPreferenceService audioSharingService;
  late _MockLanguagePreferenceService languageService;
  late _MockAccountLabelService accountLabelService;
  late _MockAgeVerificationService ageVerificationService;
  late _MockContentFilterService contentFilterService;
  late _MockModerationLabelService moderationLabelService;
  late _MockFollowRepository followRepository;
  late _MockContentBlocklistRepository blocklistRepository;
  late _MockVideoEventService videoEventService;
  late DivineHostFilterService divineHostFilterService;

  DivineVideoDraft draftWithId(String id) => DivineVideoDraft.create(
    clips: const [],
    title: id,
    description: '',
    hashtags: const {},
    selectedApproach: 'test',
  ).copyWith(id: id);

  void seedPublishState(BackgroundPublishState state) {
    whenListen(
      publishBloc,
      const Stream<BackgroundPublishState>.empty(),
      initialState: state,
    );
  }

  setUpAll(() {
    registerFallbackValue(BackgroundPublishVanished(draftId: 'fallback'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    authService = _MockAuthService();
    localeCubit = _MockLocaleCubit();
    inviteStatusCubit = _MockInviteStatusCubit();
    publishBloc = _MockBackgroundPublishBloc();
    draftStorageService = _MockDraftStorageService();
    audioSharingService = _MockAudioSharingPreferenceService();
    languageService = _MockLanguagePreferenceService();
    accountLabelService = _MockAccountLabelService();
    ageVerificationService = _MockAgeVerificationService();
    contentFilterService = _MockContentFilterService();
    moderationLabelService = _MockModerationLabelService();
    followRepository = _MockFollowRepository();
    blocklistRepository = _MockContentBlocklistRepository();
    videoEventService = _MockVideoEventService();
    divineHostFilterService = DivineHostFilterService(sharedPreferences);

    when(() => localeCubit.state).thenReturn(const LocaleState());
    whenListen(
      inviteStatusCubit,
      const Stream<InviteStatusState>.empty(),
      initialState: const InviteStatusState(),
    );
    when(() => inviteStatusCubit.load()).thenAnswer((_) async {});
    seedPublishState(const BackgroundPublishState());

    when(() => authService.isAuthenticated).thenReturn(true);
    when(() => authService.isAnonymous).thenReturn(false);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    when(() => authService.currentPublicKeyHex).thenReturn(currentPubkey);
    when(() => authService.getKnownAccounts()).thenAnswer(
      (_) async => [
        KnownAccount(
          pubkeyHex: currentPubkey,
          authSource: AuthenticationSource.importedKeys,
          addedAt: DateTime(2026),
          lastUsedAt: DateTime(2026),
        ),
        KnownAccount(
          pubkeyHex: otherPubkey,
          authSource: AuthenticationSource.importedKeys,
          addedAt: DateTime(2026),
          lastUsedAt: DateTime(2026),
        ),
      ],
    );

    when(() => draftStorageService.getDraftCount()).thenAnswer((_) async => 0);

    when(() => audioSharingService.isAudioSharingEnabled).thenReturn(false);
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
      () => moderationLabelService.isDivineLabelerSubscribed,
    ).thenReturn(true);
    when(() => moderationLabelService.ensureLoaded()).thenAnswer((_) async {});
    when(
      () => moderationLabelService.isFollowingModerationEnabled,
    ).thenReturn(false);
    when(() => moderationLabelService.customLabelers).thenReturn(<String>{});
    when(() => followRepository.followingPubkeys).thenReturn(<String>[]);
    when(
      () => followRepository.followingStream,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authServiceProvider.overrideWithValue(authService),
        currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        // Null repository keeps userProfileReactiveProvider on an empty stream,
        // so the account header renders from fallbacks without any network.
        profileRepositoryProvider.overrideWithValue(null),
        draftStorageServiceProvider.overrideWithValue(draftStorageService),
        isFeatureEnabledProvider(
          FeatureFlag.accountSwitching,
        ).overrideWithValue(true),
        audioSharingPreferenceServiceProvider.overrideWithValue(
          audioSharingService,
        ),
        languagePreferenceServiceProvider.overrideWithValue(languageService),
        accountLabelServiceProvider.overrideWithValue(accountLabelService),
        ageVerificationServiceProvider.overrideWithValue(
          ageVerificationService,
        ),
        contentFilterServiceProvider.overrideWithValue(contentFilterService),
        moderationLabelServiceProvider.overrideWithValue(
          moderationLabelService,
        ),
        followRepositoryProvider.overrideWithValue(followRepository),
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
        videoEventServiceProvider.overrideWithValue(videoEventService),
        divineHostFilterServiceProvider.overrideWithValue(
          divineHostFilterService,
        ),
        feedAspectRatioPreferenceServiceProvider.overrideWithValue(
          FeedAspectRatioPreferenceService(sharedPreferences),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<LocaleCubit>.value(value: localeCubit),
            BlocProvider<InviteStatusCubit>.value(value: inviteStatusCubit),
            BlocProvider<BackgroundPublishBloc>.value(value: publishBloc),
          ],
          child: child,
        ),
      ),
    );
  }

  Future<AppLocalizations> pumpAndTapSwitch(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsScreen)),
    );
    await tester.tap(find.text(l10n.settingsSwitchAccount));
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('warns about an in-flight upload before switching', (
    tester,
  ) async {
    seedPublishState(
      BackgroundPublishState(
        uploads: [
          BackgroundUpload(draft: draftWithId('d1'), result: null, progress: 0),
        ],
      ),
    );

    final l10n = await pumpAndTapSwitch(tester);

    expect(find.text(l10n.settingsUploadInProgressTitle), findsOneWidget);
    expect(find.text(l10n.settingsUploadInProgressMessage(1)), findsOneWidget);
  });

  testWidgets('cancelling the warning leaves the upload untouched', (
    tester,
  ) async {
    seedPublishState(
      BackgroundPublishState(
        uploads: [
          BackgroundUpload(draft: draftWithId('d1'), result: null, progress: 0),
        ],
      ),
    );

    final l10n = await pumpAndTapSwitch(tester);
    await tester.tap(find.text(l10n.settingsCancel));
    await tester.pumpAndSettle();

    verifyNever(() => publishBloc.add(any()));
    expect(find.text(l10n.settingsUploadInProgressTitle), findsNothing);
  });

  testWidgets('switching anyway parks each in-flight upload as a draft', (
    tester,
  ) async {
    seedPublishState(
      BackgroundPublishState(
        uploads: [
          BackgroundUpload(draft: draftWithId('d1'), result: null, progress: 0),
          BackgroundUpload(draft: draftWithId('d2'), result: null, progress: 0),
          // Already finished — must not be parked or counted.
          BackgroundUpload(
            draft: draftWithId('d3'),
            result: const PublishError(PublishErrorKind.generic),
            progress: 1,
          ),
        ],
      ),
    );

    final l10n = await pumpAndTapSwitch(tester);
    expect(find.text(l10n.settingsUploadInProgressMessage(2)), findsOneWidget);

    await tester.tap(find.text(l10n.settingsSwitchAnyway));
    await tester.pumpAndSettle();

    final parked = verify(() => publishBloc.add(captureAny())).captured
        .cast<BackgroundPublishEvent>()
        .whereType<BackgroundPublishVanished>()
        .map((event) => event.draftId)
        .toList();
    expect(parked, equals(['d1', 'd2']));
  });

  testWidgets('falls back to the drafts warning when nothing is uploading', (
    tester,
  ) async {
    when(() => draftStorageService.getDraftCount()).thenAnswer((_) async => 2);

    final l10n = await pumpAndTapSwitch(tester);

    expect(find.text(l10n.settingsUnsavedDraftsTitle), findsOneWidget);
    expect(find.text(l10n.settingsUploadInProgressTitle), findsNothing);
  });
}

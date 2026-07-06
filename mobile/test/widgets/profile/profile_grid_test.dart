import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
import 'package:openvine/widgets/profile/profile_videos_grid_skeleton.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockBookmarkService extends Mock implements BookmarkService {}

class _MockProfileFeedCubit extends MockBloc<ProfileFeedEvent, ProfileFeedState>
    implements ProfileFeedCubit {}

class _MockMyProfileBloc extends MockBloc<MyProfileEvent, MyProfileState>
    implements MyProfileBloc {}

void main() {
  const userIdHex =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group(ProfileGridView, () {
    late _MockLikesRepository likesRepository;
    late _MockRepostsRepository repostsRepository;
    late _MockVideosRepository videosRepository;
    late _MockCommentsRepository commentsRepository;
    late _MockContentBlocklistRepository blocklistRepository;
    late _MockBookmarkService bookmarkService;
    late _MockProfileFeedCubit profileFeedCubit;
    late _MockMyProfileBloc myProfileBloc;
    late MockNostrClient nostrClient;

    setUpAll(() {
      registerFallbackValue(const MyProfileLoadRequested());
      registerFallbackValue(const ProfileFeedStarted());
    });

    setUp(() {
      likesRepository = _MockLikesRepository();
      repostsRepository = _MockRepostsRepository();
      videosRepository = _MockVideosRepository();
      commentsRepository = _MockCommentsRepository();
      blocklistRepository = _MockContentBlocklistRepository();
      bookmarkService = _MockBookmarkService();
      profileFeedCubit = _MockProfileFeedCubit();
      myProfileBloc = _MockMyProfileBloc();
      nostrClient = createMockNostrService();

      when(() => nostrClient.publicKey).thenReturn(userIdHex);
      when(
        likesRepository.watchLikedEventIds,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        repostsRepository.watchRepostedAddressableIds,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
      when(
        () => blocklistRepository.stateStream,
      ).thenAnswer((_) => const Stream<ContentPolicyState>.empty());
      when(
        () => blocklistRepository.currentState,
      ).thenReturn(ContentPolicyState.empty());
      when(() => blocklistRepository.isBlocked(any())).thenReturn(false);
      when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);
      when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(false);
      when(() => bookmarkService.globalBookmarks).thenReturn(const []);
      whenListen(
        profileFeedCubit,
        const Stream<ProfileFeedState>.empty(),
        initialState: const ProfileFeedState(status: ProfileFeedStatus.ready),
      );
      final profile = UserProfile(
        pubkey: userIdHex,
        displayName: 'Visible Profile',
        rawData: const {},
        createdAt: DateTime(2024),
        eventId:
            'profile1234567890123456789012345678901234567890123456789012345',
      );
      whenListen(
        myProfileBloc,
        const Stream<MyProfileState>.empty(),
        initialState: MyProfileUpdated(profile: profile),
      );
      when(
        () => myProfileBloc.state,
      ).thenReturn(MyProfileUpdated(profile: profile));
      when(() => myProfileBloc.pubkey).thenReturn(userIdHex);
      when(() => myProfileBloc.add(any())).thenAnswer((invocation) {
        final event = invocation.positionalArguments.first;
        if (event is MyProfileRefreshRequested) {
          event.completer?.complete();
        }
      });
    });

    Widget buildSubject({
      required bool isOwnProfile,
      bool isLoadingVideos = false,
      MockAuthService? mockAuthService,
    }) {
      return testMaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<MyProfileBloc>.value(value: myProfileBloc),
              BlocProvider<ProfileFeedCubit>.value(value: profileFeedCubit),
            ],
            child: ProfileGridView(
              key: const ValueKey('profile-grid'),
              userIdHex: userIdHex,
              isOwnProfile: isOwnProfile,
              videos: const [],
              isLoadingVideos: isLoadingVideos,
            ),
          ),
        ),
        mockNostrService: nostrClient,
        mockAuthService: mockAuthService,
        additionalOverrides: [
          likesRepositoryProvider.overrideWithValue(likesRepository),
          repostsRepositoryProvider.overrideWithValue(repostsRepository),
          videosRepositoryProvider.overrideWithValue(videosRepository),
          commentsRepositoryProvider.overrideWithValue(commentsRepository),
          contentBlocklistRepositoryProvider.overrideWithValue(
            blocklistRepository,
          ),
          bookmarkServiceProvider.overrideWith((_) => bookmarkService),
          isFeatureEnabledProvider(
            FeatureFlag.videoReplies,
          ).overrideWith((_) => false),
          isFeatureEnabledProvider(
            FeatureFlag.curatedLists,
          ).overrideWith((_) => false),
        ],
      );
    }

    Widget buildSubjectWithContainer(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<MyProfileBloc>.value(value: myProfileBloc),
                BlocProvider<ProfileFeedCubit>.value(value: profileFeedCubit),
              ],
              child: const ProfileGridView(
                key: ValueKey('profile-grid'),
                userIdHex: userIdHex,
                isOwnProfile: false,
                videos: [],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'recreates tab state when own-profile status changes in place',
      (tester) async {
        await tester.pumpWidget(buildSubject(isOwnProfile: false));
        await tester.pump();

        expect(find.bySemanticsLabel('videos_tab'), findsOneWidget);
        expect(find.bySemanticsLabel('collabs_tab'), findsOneWidget);
        expect(find.bySemanticsLabel('saved_tab'), findsNothing);
        expect(find.bySemanticsLabel('comments_tab'), findsOneWidget);

        await tester.pumpWidget(buildSubject(isOwnProfile: true));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('videos_tab'), findsOneWidget);
        expect(find.bySemanticsLabel('collabs_tab'), findsOneWidget);
        expect(find.bySemanticsLabel('liked_tab'), findsOneWidget);
        expect(find.bySemanticsLabel('reposted_tab'), findsOneWidget);
        expect(find.bySemanticsLabel('saved_tab'), findsOneWidget);
        expect(find.bySemanticsLabel('comments_tab'), findsOneWidget);
      },
    );

    testWidgets(
      'does not restore another viewer identity tab index after auth change',
      (tester) async {
        const viewerA =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const viewerB =
            '2222222222222222222222222222222222222222222222222222222222222222';
        var currentViewer = viewerA;
        final authService = createMockAuthService();
        when(
          () => authService.currentPublicKeyHex,
        ).thenAnswer((_) => currentViewer);
        when(() => authService.isAuthenticated).thenReturn(true);
        when(() => authService.isAnonymous).thenReturn(false);
        when(() => authService.hasExpiredOAuthSession).thenReturn(false);
        when(() => authService.isRpcUpgradeInProgress).thenReturn(false);

        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(
              mockAuthService: authService,
              mockNostrService: nostrClient,
            ),
            likesRepositoryProvider.overrideWithValue(likesRepository),
            repostsRepositoryProvider.overrideWithValue(repostsRepository),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            commentsRepositoryProvider.overrideWithValue(commentsRepository),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
            bookmarkServiceProvider.overrideWith((_) => bookmarkService),
            isFeatureEnabledProvider(
              FeatureFlag.videoReplies,
            ).overrideWith((_) => false),
            isFeatureEnabledProvider(
              FeatureFlag.curatedLists,
            ).overrideWith((_) => false),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildSubjectWithContainer(container));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('reposted_tab'));
        await tester.pumpAndSettle();
        expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 2);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(buildSubjectWithContainer(container));
        await tester.pump();
        expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 2);

        currentViewer = viewerB;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(buildSubjectWithContainer(container));
        await tester.pump();

        expect(tester.widget<TabBar>(find.byType(TabBar)).controller?.index, 0);
      },
    );

    testWidgets(
      'videos tab shows the skeleton grid while the cold feed load is in '
      'flight (no separate loading view)',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(isOwnProfile: false, isLoadingVideos: true),
        );
        await tester.pump();

        expect(find.byType(ProfileVideosGridSkeleton), findsOneWidget);
      },
    );

    testWidgets('pull-to-refresh refreshes profile metadata and feed', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isOwnProfile: true));
      await tester.pump();

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();

      verify(
        () => myProfileBloc.add(any(that: isA<MyProfileRefreshRequested>())),
      ).called(1);
      verify(
        () => profileFeedCubit.add(const ProfileFeedRefreshRequested()),
      ).called(1);
    });

    testWidgets('pull gesture triggers profile metadata and feed refresh', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isOwnProfile: true));
      await tester.pump();

      await tester.fling(
        find.byType(NestedScrollView),
        const Offset(0, 500),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => myProfileBloc.add(any(that: isA<MyProfileRefreshRequested>())),
      ).called(1);
      verify(
        () => profileFeedCubit.add(const ProfileFeedRefreshRequested()),
      ).called(1);
    });
  });
}

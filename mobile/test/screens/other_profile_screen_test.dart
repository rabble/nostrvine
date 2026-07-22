// ABOUTME: Widget tests for OtherProfileView integration behavior.
// ABOUTME: Verifies screen-level provider reactivity for profile affordances.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/other_profile/other_profile_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/official_accounts_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockOtherProfileBloc
    extends MockBloc<OtherProfileEvent, OtherProfileState>
    implements OtherProfileBloc {}

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockOfficials extends Mock implements OfficialAccountsService {}

void main() {
  const targetPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const viewerPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  late _MockOtherProfileBloc otherProfileBloc;
  late _MockPeopleListsBloc peopleListsBloc;
  late _MockContentBlocklistRepository blocklistRepository;
  late _MockLikesRepository likesRepository;
  late _MockRepostsRepository repostsRepository;
  late _MockCommentsRepository commentsRepository;
  late _MockVideosRepository videosRepository;
  late _MockVideoEventService videoEventService;
  late _MockOfficials officials;
  late MockFollowRepository followRepository;
  late MockNostrClient nostrClient;
  late MockAuthService authService;

  UserProfile profile() => UserProfile(
    pubkey: targetPubkey,
    displayName: 'Target User',
    rawData: const {},
    createdAt: DateTime(2026),
    eventId: 'c' * 64,
  );

  AuthorFeedResult emptyAuthorFeed() => const AuthorFeedResult(
    authorPubkey: targetPubkey,
    totalCount: 0,
    hasMore: false,
  );

  setUpAll(() {
    registerFallbackValue(const OtherProfileLoadRequested());
  });

  setUp(() {
    otherProfileBloc = _MockOtherProfileBloc();
    peopleListsBloc = _MockPeopleListsBloc();
    blocklistRepository = _MockContentBlocklistRepository();
    likesRepository = _MockLikesRepository();
    repostsRepository = _MockRepostsRepository();
    commentsRepository = _MockCommentsRepository();
    videosRepository = _MockVideosRepository();
    videoEventService = _MockVideoEventService();
    officials = _MockOfficials();
    followRepository = createMockFollowRepository(
      followingPubkeys: const [targetPubkey],
    );
    nostrClient = createMockNostrService();
    authService = createMockAuthService();

    final loadedState = OtherProfileLoaded(profile: profile(), isFresh: true);
    whenListen(
      otherProfileBloc,
      const Stream<OtherProfileState>.empty(),
      initialState: loadedState,
    );
    when(() => otherProfileBloc.state).thenReturn(loadedState);
    when(() => otherProfileBloc.pubkey).thenReturn(targetPubkey);
    when(() => otherProfileBloc.isBlocked).thenReturn(false);
    when(() => otherProfileBloc.isFollowing).thenReturn(true);
    whenListen(
      peopleListsBloc,
      const Stream<PeopleListsState>.empty(),
      initialState: const PeopleListsState(),
    );
    when(() => peopleListsBloc.state).thenReturn(const PeopleListsState());

    when(() => blocklistRepository.isBlocked(any())).thenReturn(false);
    when(() => blocklistRepository.hasBlockedUs(any())).thenReturn(false);
    when(() => blocklistRepository.hasMutedUs(any())).thenReturn(false);
    when(() => blocklistRepository.shouldFilterFromFeeds(any())).thenReturn(
      false,
    );
    when(() => blocklistRepository.currentState).thenReturn(
      ContentPolicyState.empty(),
    );
    when(() => blocklistRepository.stateStream).thenAnswer(
      (_) => const Stream<ContentPolicyState>.empty(),
    );

    when(
      likesRepository.watchLikedEventIds,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      repostsRepository.watchRepostedAddressableIds,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());

    when(() => videoEventService.authorVideos(any())).thenReturn(
      const <VideoEvent>[],
    );
    when(() => videoEventService.filterVideoList(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
    );
    when(() => videoEventService.addListener(any())).thenReturn(null);
    when(() => videoEventService.removeListener(any())).thenReturn(null);
    when(() => videoEventService.addVideoUpdateListener(any())).thenReturn(
      () {},
    );
    when(() => videoEventService.subscribeToUserVideos(any())).thenAnswer(
      (_) async {},
    );
    when(
      () => videosRepository.getAuthorFeed(
        authorPubkey: any(named: 'authorPubkey'),
        offset: any(named: 'offset'),
        relaySeed: any(named: 'relaySeed'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenAnswer((_) async => emptyAuthorFeed());

    when(() => officials.isApprovedMinorDmRecipientSync(any())).thenReturn(
      false,
    );
    when(() => nostrClient.publicKey).thenReturn(viewerPubkey);
    when(() => authService.currentPublicKeyHex).thenReturn(viewerPubkey);
    when(() => authService.authState).thenReturn(AuthState.authenticated);
    when(() => authService.isAuthenticated).thenReturn(true);
    when(() => authService.isAnonymous).thenReturn(false);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    when(() => authService.isRpcUpgradeInProgress).thenReturn(false);
  });

  Widget buildSubject({
    required ProviderContainer container,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<OtherProfileBloc>.value(value: otherProfileBloc),
            BlocProvider<PeopleListsBloc>.value(value: peopleListsBloc),
          ],
          child: const OtherProfileView(pubkey: targetPubkey),
        ),
      ),
    );
  }

  ProviderContainer createContainer(StateProvider<bool> restrictedProvider) {
    return ProviderContainer(
      overrides: [
        ...getStandardTestOverrides(
          mockAuthService: authService,
          mockNostrService: nostrClient,
          mockFollowRepository: followRepository,
        ),
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
        likesRepositoryProvider.overrideWithValue(likesRepository),
        repostsRepositoryProvider.overrideWithValue(repostsRepository),
        commentsRepositoryProvider.overrideWithValue(commentsRepository),
        videosRepositoryProvider.overrideWithValue(videosRepository),
        videoEventServiceProvider.overrideWithValue(videoEventService),
        officialAccountsServiceProvider.overrideWithValue(officials),
        isDmRestrictedProvider.overrideWith(
          (ref) => ref.watch(restrictedProvider),
        ),
        userProfileStatsReactiveProvider(targetPubkey).overrideWith(
          (ref) => const Stream<ProfileStats?>.empty(),
        ),
        fetchUserProfileProvider(targetPubkey).overrideWith(
          (ref) async => profile(),
        ),
        isFeatureEnabledProvider(FeatureFlag.videoReplies).overrideWith(
          (ref) => false,
        ),
        isFeatureEnabledProvider(
          FeatureFlag.profileMonetizationLinks,
        ).overrideWith((ref) => false),
        isFeatureEnabledProvider(FeatureFlag.curatedLists).overrideWith(
          (ref) => false,
        ),
      ],
    );
  }

  testWidgets(
    'updates Message visibility when DM restriction flips while mounted',
    (tester) async {
      final restrictedProvider = StateProvider<bool>((ref) => true);
      final container = createContainer(restrictedProvider);
      addTearDown(container.dispose);

      await tester.pumpWidget(buildSubject(container: container));
      await tester.pump();

      expect(find.text('Message'), findsNothing);

      container.read(restrictedProvider.notifier).state = false;
      await tester.pump();

      expect(find.text('Message'), findsOneWidget);

      container.read(restrictedProvider.notifier).state = true;
      await tester.pump();

      expect(find.text('Message'), findsNothing);
    },
  );
}

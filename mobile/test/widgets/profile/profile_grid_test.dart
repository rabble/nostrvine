import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/widgets/profile/profile_grid.dart';
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
    late MockNostrClient nostrClient;

    setUp(() {
      likesRepository = _MockLikesRepository();
      repostsRepository = _MockRepostsRepository();
      videosRepository = _MockVideosRepository();
      commentsRepository = _MockCommentsRepository();
      blocklistRepository = _MockContentBlocklistRepository();
      bookmarkService = _MockBookmarkService();
      profileFeedCubit = _MockProfileFeedCubit();
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
    });

    Widget buildSubject({required bool isOwnProfile}) {
      return testMaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<MyProfileBloc>(
                create: (_) => MyProfileBloc(
                  profileRepository: createMockProfileRepository(),
                  pubkey: userIdHex,
                ),
              ),
              BlocProvider<ProfileFeedCubit>.value(value: profileFeedCubit),
            ],
            child: ProfileGridView(
              key: const ValueKey('profile-grid'),
              userIdHex: userIdHex,
              isOwnProfile: isOwnProfile,
              videos: const [],
            ),
          ),
        ),
        mockNostrService: nostrClient,
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
  });
}

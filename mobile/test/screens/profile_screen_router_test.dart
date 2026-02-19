// ABOUTME: Tests for router-driven ProfileScreen implementation
// ABOUTME: Verifies URL ↔ PageView synchronization for profile feeds

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide VineDraft;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVineDraft extends Mock implements VineDraft {}

class _MockFollowRepository extends Mock implements FollowRepository {
  @override
  List<String> get followingPubkeys => [];

  @override
  Stream<List<String>> get followingStream => Stream.value([]);

  @override
  bool get isInitialized => true;

  @override
  int get followingCount => 0;
}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockNostrClient extends Mock implements NostrClient {
  // Valid 64-character hex string for testing
  static const testPubkeyHex =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  @override
  bool get hasKeys => true;

  @override
  String get publicKey => testPubkeyHex;

  @override
  bool get isInitialized => true;

  @override
  int get connectedRelayCount => 1;

  @override
  List<String> get configuredRelays => <String>[];
}

class _MockUserProfileService extends Mock implements UserProfileService {}

void main() {
  Widget _shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
  );

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  final mockVideos = [
    VideoEvent(
      id: 'p0',
      pubkey: 'npubXYZ',
      createdAt: nowUnix,
      content: 'Profile Video 0',
      timestamp: now,
      title: 'Profile 0',
      videoUrl: 'https://example.com/p0.mp4',
    ),
    VideoEvent(
      id: 'p1',
      pubkey: 'npubXYZ',
      createdAt: nowUnix,
      content: 'Profile Video 1',
      timestamp: now,
      title: 'Profile 1',
      videoUrl: 'https://example.com/p1.mp4',
    ),
    VideoEvent(
      id: 'p2',
      pubkey: 'npubXYZ',
      createdAt: nowUnix,
      content: 'Profile Video 2',
      timestamp: now,
      title: 'Profile 2',
      videoUrl: 'https://example.com/p2.mp4',
    ),
  ];

  testWidgets('PROFILE: URL ↔ PageView sync', (tester) async {
    final c = ProviderContainer(
      overrides: [
        videosForProfileRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 0));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreenRouter), findsOneWidget);

    // Verify first video shown
    expect(find.text('Profile 0/3'), findsOneWidget);

    // Navigate to index 1
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 1));
    await tester.pumpAndSettle();

    // Verify second video shown
    expect(find.text('Profile 1/3'), findsOneWidget);
    // TODO(any): Fix and re-enable this test
  }, skip: true);

  testWidgets('PROFILE: Empty state shows when no videos', (tester) async {
    final c = ProviderContainer(
      overrides: [
        videosForProfileRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: [],
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('No posts yet'), findsOneWidget);
    // TODO(any): Fix and re-enable this test
  }, skip: true);

  testWidgets('PROFILE: Prefetch ±1 profiles when URL index changes', (
    tester,
  ) async {
    final prefetchedPubkeys = <String>[];

    final mockNotifier = FakeUserProfileNotifier(
      onPrefetch: (pubkeys) => prefetchedPubkeys.addAll(pubkeys),
    );

    final c = ProviderContainer(
      overrides: [
        videosForProfileRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
        userProfileProvider.overrideWith(() => mockNotifier),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 1));
    await tester.pumpAndSettle();

    // Should prefetch profiles for videos at index 0 and 2 (±1 from current)
    // In profile screen, all videos are from the same author, so this might
    // prefetch the same npub multiple times - that's fine for now
    expect(prefetchedPubkeys.length, greaterThanOrEqualTo(1));
    // TODO(any): Fix and re-enable this test
  }, skip: true);

  testWidgets('PROFILE: Lifecycle pause → activeVideoId becomes null', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [
        appForegroundProvider.overrideWithValue(const AsyncValue.data(false)),
        videosForProfileRouteProvider.overrideWith((ref) {
          return AsyncValue.data(
            VideoFeedState(
              videos: mockVideos,
              hasMoreContent: false,
              isLoadingMore: false,
            ),
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 1));
    await tester.pumpAndSettle();

    // When backgrounded, active video should be null
    expect(c.read(activeVideoIdProvider), isNull);
    // TODO(any): Fix and re-enable this test
  }, skip: true);

  group('BackgroundPublishBloc error handling', () {
    late _MockVineDraft mockDraft;
    late _FakeBackgroundPublishBloc fakeBloc;
    late ScrollController scrollController;
    late _MockFollowRepository mockFollowRepository;
    late _MockLikesRepository mockLikesRepository;
    late _MockRepostsRepository mockRepostsRepository;
    late _MockVideosRepository mockVideosRepository;
    late _MockNostrClient mockNostrClient;
    late _MockUserProfileService mockUserProfileService;

    setUp(() {
      mockDraft = _MockVineDraft();
      when(() => mockDraft.id).thenReturn('test-draft-id');
      when(() => mockDraft.title).thenReturn('');
      when(() => mockDraft.clips).thenReturn([]);
      scrollController = ScrollController();

      mockFollowRepository = _MockFollowRepository();
      when(
        () => mockFollowRepository.getMyFollowers(),
      ).thenAnswer((_) async => <String>[]);
      when(
        () => mockFollowRepository.getFollowers(any()),
      ).thenAnswer((_) async => <String>[]);
      mockLikesRepository = _MockLikesRepository();
      when(
        () => mockLikesRepository.watchLikedEventIds(),
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        () => mockLikesRepository.fetchUserLikes(any()),
      ).thenAnswer((_) async => <String>[]);

      mockRepostsRepository = _MockRepostsRepository();
      when(
        () => mockRepostsRepository.watchRepostedAddressableIds(),
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
      when(
        () => mockRepostsRepository.fetchUserReposts(any()),
      ).thenAnswer((_) async => <String>[]);

      mockVideosRepository = _MockVideosRepository();
      mockNostrClient = _MockNostrClient();
      mockUserProfileService = _MockUserProfileService();

      // Stub UserProfileService methods to prevent real network calls
      when(
        () => mockUserProfileService.getCachedProfile(any()),
      ).thenReturn(null);
      when(() => mockUserProfileService.hasProfile(any())).thenReturn(false);
      when(
        () => mockUserProfileService.shouldSkipProfileFetch(any()),
      ).thenReturn(true);
      when(
        () => mockUserProfileService.fetchProfile(
          any(),
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockUserProfileService.prefetchProfilesImmediately(any()),
      ).thenAnswer((_) async {});
      when(() => mockUserProfileService.addListener(any())).thenReturn(null);
      when(() => mockUserProfileService.removeListener(any())).thenReturn(null);
    });

    tearDown(() {
      fakeBloc.close();
      scrollController.dispose();
    });

    Widget buildTestWidget(_FakeBackgroundPublishBloc bloc) {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(
            mockNostrService: mockNostrClient,
            mockUserProfileService: mockUserProfileService,
          ),
          followRepositoryProvider.overrideWithValue(mockFollowRepository),
          likesRepositoryProvider.overrideWithValue(mockLikesRepository),
          repostsRepositoryProvider.overrideWithValue(mockRepostsRepository),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
        ],
        child: MaterialApp(
          theme: VineTheme.theme,
          home: BlocProvider<BackgroundPublishBloc>.value(
            value: bloc,
            child: Scaffold(
              body: ProfileViewSwitcher(
                npub:
                    'npub142qp2pn56v7d4tqtw9qqgq2qqqqqqqqqqqqqqqqqqqqqqqqqqqqqfl2n4z',
                userIdHex: _MockNostrClient.testPubkeyHex,
                isOwnProfile: true,
                videos: const [],
                videoIndex: null,
                profileStatsAsync: const AsyncValue.loading(),
                scrollController: scrollController,
                onSetupProfile: () {},
                onEditProfile: () {},
                onOpenClips: () {},
                onOpenAnalytics: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows DivineSnackbarContainer when upload has error result', (
      tester,
    ) async {
      fakeBloc = _FakeBackgroundPublishBloc(
        initialState: BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: mockDraft,
              result: const PublishError('Upload failed'),
              progress: 1.0,
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestWidget(fakeBloc));
      await tester.pumpAndSettle();

      // Should show the error snackbar
      expect(find.byType(DivineSnackbarContainer), findsOneWidget);
      expect(find.text('Video upload failed.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('does not show DivineSnackbarContainer when no error uploads', (
      tester,
    ) async {
      fakeBloc = _FakeBackgroundPublishBloc(
        initialState: BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: mockDraft,
              result: null, // Still uploading, no result
              progress: 0.5,
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildTestWidget(fakeBloc));
      // Use pump() instead of pumpAndSettle() because there's a progress
      // indicator animation running (upload in progress)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should not show the error snackbar
      expect(find.byType(DivineSnackbarContainer), findsNothing);
    });

    testWidgets(
      'retry button dispatches BackgroundPublishRetryRequested event',
      (tester) async {
        fakeBloc = _FakeBackgroundPublishBloc(
          initialState: BackgroundPublishState(
            uploads: [
              BackgroundUpload(
                draft: mockDraft,
                result: const PublishError('Upload failed'),
                progress: 1.0,
              ),
            ],
          ),
        );

        await tester.pumpWidget(buildTestWidget(fakeBloc));
        await tester.pumpAndSettle();

        // Tap the retry button
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        // Should have dispatched the retry event
        expect(fakeBloc.retryRequestedEvents, hasLength(1));
        expect(
          fakeBloc.retryRequestedEvents.first.draftId,
          equals('test-draft-id'),
        );
      },
    );

    testWidgets(
      'swiping error snackbar dispatches BackgroundPublishVanished event',
      (tester) async {
        fakeBloc = _FakeBackgroundPublishBloc(
          initialState: BackgroundPublishState(
            uploads: [
              BackgroundUpload(
                draft: mockDraft,
                result: const PublishError('Upload failed'),
                progress: 1.0,
              ),
            ],
          ),
        );

        await tester.pumpWidget(buildTestWidget(fakeBloc));
        await tester.pumpAndSettle();

        // Find the Dismissible widget and swipe it
        await tester.drag(
          find.byType(Dismissible),
          const Offset(500, 0), // Swipe right
        );
        await tester.pumpAndSettle();

        // Should have dispatched the vanished event
        expect(fakeBloc.vanishedEvents, hasLength(1));
        expect(fakeBloc.vanishedEvents.first.draftId, equals('test-draft-id'));
      },
    );
  });
}

/// Fake UserProfileNotifier for testing prefetch behavior
class FakeUserProfileNotifier extends UserProfileNotifier {
  FakeUserProfileNotifier({required this.onPrefetch});

  final void Function(List<String>) onPrefetch;

  @override
  Future<void> prefetchProfilesImmediately(List<String> pubkeys) async {
    onPrefetch(pubkeys);
  }
}

/// Fake BackgroundPublishBloc for testing error snackbar display and retry
class _FakeBackgroundPublishBloc
    extends Bloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {
  _FakeBackgroundPublishBloc({BackgroundPublishState? initialState})
    : super(initialState ?? const BackgroundPublishState()) {
    on<BackgroundPublishRetryRequested>((event, emit) {
      retryRequestedEvents.add(event);
    });
    on<BackgroundPublishVanished>((event, emit) {
      vanishedEvents.add(event);
    });
    on<BackgroundPublishProgressChanged>((event, emit) {});
    on<BackgroundPublishRequested>((event, emit) {});
  }

  final retryRequestedEvents = <BackgroundPublishRetryRequested>[];
  final vanishedEvents = <BackgroundPublishVanished>[];
}

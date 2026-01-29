// ABOUTME: Tests for router-driven ProfileScreen implementation
// ABOUTME: Verifies URL ↔ PageView synchronization for profile feeds

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide VineDraft;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/state/video_feed_state.dart';

class _MockVineDraft extends Mock implements VineDraft {}

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

    setUp(() {
      mockDraft = _MockVineDraft();
      when(() => mockDraft.id).thenReturn('test-draft-id');
      scrollController = ScrollController();
    });

    tearDown(() {
      fakeBloc.close();
      scrollController.dispose();
    });

    Widget buildTestWidget(_FakeBackgroundPublishBloc bloc) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: BlocProvider<BackgroundPublishBloc>.value(
          value: bloc,
          child: Scaffold(
            body: ProfileViewSwitcher(
              npub: 'test-npub',
              userIdHex: 'test-hex',
              isOwnProfile: true,
              videos: const [],
              videoIndex: null,
              profileStatsAsync: const AsyncValue.loading(),
              scrollController: scrollController,
              onSetupProfile: () {},
              onEditProfile: () {},
              onOpenClips: () {},
              childOverride: const Placeholder(),
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
      await tester.pumpAndSettle();

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
    on<BackgroundPublishVanished>((event, emit) {});
    on<BackgroundPublishProgressChanged>((event, emit) {});
    on<BackgroundPublishRequested>((event, emit) {});
  }

  final retryRequestedEvents = <BackgroundPublishRetryRequested>[];
}

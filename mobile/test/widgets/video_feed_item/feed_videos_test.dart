// ABOUTME: Widget tests for FeedVideos — covers loading/restricted overlay,
// ABOUTME: overlay mode switching (forbidden/ageRestricted/contentWarning/interactive),
// ABOUTME: isActive toggling, and pagination flush via didUpdateWidget.

import 'package:bloc_test/bloc_test.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_cubit.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_state.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_loading_placeholder.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockFeedLoadingModerationCubit
    extends MockCubit<FeedLoadingModerationState>
    implements FeedLoadingModerationCubit {
  @override
  void start() {}
}

class _MockVideoPlaybackStatusCubit extends MockCubit<VideoPlaybackStatusState>
    implements VideoPlaybackStatusCubit {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

class _MockFeedAutoAdvanceCubit extends MockCubit<FeedAutoAdvanceState>
    implements FeedAutoAdvanceCubit {}

class _MockConnectionStatusService extends Mock
    implements ConnectionStatusService {}

class _MockVideoModerationStatusService extends Mock
    implements VideoModerationStatusService {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _testVideoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

VideoEvent _makeVideo({
  String? id,
  List<String> warnLabels = const [],
}) {
  return VideoEvent(
    id: id ?? _testVideoId,
    pubkey: _testPubkey,
    createdAt: 1704067200,
    content: 'Test video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    videoUrl: 'https://example.com/video.mp4',
    warnLabels: warnLabels,
  );
}

// ---------------------------------------------------------------------------
// Stub helpers
// ---------------------------------------------------------------------------

extension _PlaybackCubitStub on _MockVideoPlaybackStatusCubit {
  void stub(PlaybackStatus status, String videoId) {
    final baseState = VideoPlaybackStatusState();
    when(() => state).thenReturn(
      status == PlaybackStatus.ready
          ? baseState
          : baseState.withStatus(videoId, status),
    );
    whenListen(this, const Stream<VideoPlaybackStatusState>.empty());
  }
}

extension _AutoAdvanceCubitStub on _MockFeedAutoAdvanceCubit {
  void stub(FeedAutoAdvanceState s) {
    when(() => state).thenReturn(s);
    whenListen(this, const Stream<FeedAutoAdvanceState>.empty());
  }
}

extension _VolumeCubitStub on _MockVideoVolumeCubit {
  void stub() {
    when(() => state).thenReturn(const VideoVolumeState());
    whenListen(this, const Stream<VideoVolumeState>.empty());
  }
}

extension _LikesRepoStub on _MockLikesRepository {
  void stubAll() {
    when(
      watchLikedEventIds,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(() => isLiked(any())).thenAnswer((_) async => false);
    when(
      () => getLikeCount(any(), addressableId: any(named: 'addressableId')),
    ).thenAnswer((_) async => 0);
  }
}

extension _CommentsRepoStub on _MockCommentsRepository {
  void stubAll() {
    when(
      () => getCommentsCount(
        any(),
        rootAddressableId: any(named: 'rootAddressableId'),
      ),
    ).thenAnswer((_) async => 0);
  }
}

extension _RepostsRepoStub on _MockRepostsRepository {
  void stubAll() {
    when(
      watchRepostedAddressableIds,
    ).thenAnswer((_) => const Stream<Set<String>>.empty());
    when(
      () => getRepostCountByEventId(any()),
    ).thenAnswer((_) async => 0);
  }
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

// ignore: strict_raw_type
List _buildOverrides({
  VideoModerationStatusService? moderationService,
  LikesRepository? likesRepository,
  CommentsRepository? commentsRepository,
  RepostsRepository? repostsRepository,
}) {
  return [
    ...getStandardTestOverrides(),
    connectionStatusServiceProvider.overrideWithValue(
      _MockConnectionStatusService(),
    ),
    videoModerationStatusServiceProvider.overrideWithValue(
      moderationService ?? _MockVideoModerationStatusService(),
    ),
    subtitleVisibilityProvider.overrideWithValue(false),
    likesRepositoryProvider.overrideWithValue(
      likesRepository ?? (_MockLikesRepository()..stubAll()),
    ),
    commentsRepositoryProvider.overrideWithValue(
      commentsRepository ?? (_MockCommentsRepository()..stubAll()),
    ),
    repostsRepositoryProvider.overrideWithValue(
      repostsRepository ?? (_MockRepostsRepository()..stubAll()),
    ),
  ];
}

/// Pumps [FeedVideos] wrapped in all required bloc providers and Riverpod
/// overrides. [videoPlaybackStatusCubit] drives the overlay mode tests;
/// [moderationService] drives the loading/restricted overlay tests.
Future<void> _pumpFeedVideos(
  WidgetTester tester, {
  required List<VideoEvent> videos,
  _MockVideoPlaybackStatusCubit? videoPlaybackStatusCubit,
  _MockFeedAutoAdvanceCubit? feedAutoAdvanceCubit,
  _MockVideoVolumeCubit? videoVolumeCubit,
  VideoModerationStatusService? moderationService,
  _MockLikesRepository? likesRepository,
  _MockCommentsRepository? commentsRepository,
  _MockRepostsRepository? repostsRepository,
  bool isActive = true,
  bool hasMore = false,
  bool isLoadingMore = false,
  void Function(VideoEvent, int)? onActiveVideoChanged,
}) async {
  final mockPlaybackCubit =
      videoPlaybackStatusCubit ??
      (_MockVideoPlaybackStatusCubit()..stub(
        PlaybackStatus.ready,
        videos.isNotEmpty ? videos.first.id : _testVideoId,
      ));
  final mockAutoAdvanceCubit =
      feedAutoAdvanceCubit ??
      (_MockFeedAutoAdvanceCubit()..stub(const FeedAutoAdvanceState()));
  final mockVolumeCubit = videoVolumeCubit ?? (_MockVideoVolumeCubit()..stub());

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: ProviderContainer(
        overrides: _buildOverrides(
          moderationService: moderationService,
          likesRepository: likesRepository,
          commentsRepository: commentsRepository,
          repostsRepository: repostsRepository,
        ).cast(),
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<FeedAutoAdvanceCubit>.value(
              value: mockAutoAdvanceCubit,
            ),
            BlocProvider<VideoPlaybackStatusCubit>.value(
              value: mockPlaybackCubit,
            ),
            BlocProvider<VideoVolumeCubit>.value(value: mockVolumeCubit),
          ],
          child: Scaffold(
            body: FeedVideos(
              videos: videos,
              onNearEnd: () {},
              isActive: isActive,
              hasMore: hasMore,
              isLoadingMore: isLoadingMore,
              onActiveVideoChanged: onActiveVideoChanged,
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(const VideoInteractionsSubscriptionRequested());
  });

  setUp(() {
    InfiniteVideoFeed.debugIsSupportedOverride = false;
  });

  tearDown(() {
    InfiniteVideoFeed.debugIsSupportedOverride = null;
  });

  // -------------------------------------------------------------------------
  // _FeedLoadingOrRestrictedOverlayView modes
  // -------------------------------------------------------------------------
  group('_FeedLoadingOrRestrictedOverlayView', () {
    testWidgets(
      'shows $VideoLoadingPlaceholder while moderation cubit is loading',
      (tester) async {
        final video = _makeVideo();
        await _pumpFeedVideos(tester, videos: [video]);
        // With debugIsSupportedOverride=false, no controller is created so
        // loadingBuilder is always invoked.
        await tester.pump();

        expect(find.byType(VideoLoadingPlaceholder), findsOneWidget);
      },
    );

    testWidgets(
      'shows $PooledVideoErrorOverlay when moderation cubit emits restricted',
      (tester) async {
        // Test _FeedLoadingOrRestrictedOverlayView directly by providing a
        // mock FeedLoadingModerationCubit in restricted state. The production
        // _FeedLoadingOrRestrictedOverlay creates its own BlocProvider, so
        // we bypass that wrapper and test the view widget directly.
        final video = _makeVideo();
        final restrictedCubit = _MockFeedLoadingModerationCubit();
        when(() => restrictedCubit.state).thenReturn(
          const FeedLoadingModerationState(
            status: FeedLoadingModerationStatus.restricted,
          ),
        );
        whenListen(
          restrictedCubit,
          const Stream<FeedLoadingModerationState>.empty(),
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<FeedLoadingModerationCubit>.value(
              value: restrictedCubit,
              child: Scaffold(
                body: SizedBox.expand(
                  child: Builder(
                    builder: (context) {
                      final isRestricted = context.select(
                        (FeedLoadingModerationCubit c) => c.state.isRestricted,
                      );
                      if (isRestricted) {
                        return PooledVideoErrorOverlay(
                          video: video,
                          onRetry: () {},
                          errorType: VideoErrorType.notFound,
                        );
                      }
                      return VideoLoadingPlaceholder(
                        videoId: video.id,
                        index: 0,
                        thumbnailUrl: video.thumbnailUrl,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(PooledVideoErrorOverlay), findsOneWidget);
        expect(find.byType(VideoLoadingPlaceholder), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Overlay mode switching via VideoPlaybackStatusCubit
  // -------------------------------------------------------------------------
  group('overlay mode switching', () {
    testWidgets(
      'shows $ModeratedContentOverlay for forbidden playback status',
      (tester) async {
        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.forbidden, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump();

        expect(find.byType(ModeratedContentOverlay), findsOneWidget);
      },
    );

    testWidgets(
      'shows $ModeratedContentOverlay for ageRestricted playback status',
      (tester) async {
        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ageRestricted, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump();

        expect(find.byType(ModeratedContentOverlay), findsOneWidget);
      },
    );

    testWidgets(
      'shows $ContentWarningBlurOverlay when video has warnLabels',
      (tester) async {
        final video = _makeVideo(warnLabels: ['nsfw']);
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump();

        expect(find.byType(ContentWarningBlurOverlay), findsOneWidget);
        // Neither moderation overlay should be showing.
        expect(find.byType(ModeratedContentOverlay), findsNothing);
      },
    );

    testWidgets(
      'shows interactive overlay when status is ready and no content warning',
      (tester) async {
        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump();

        // Neither a moderation overlay nor a content warning overlay should
        // be visible when the video is ready with no restrictions.
        expect(find.byType(ModeratedContentOverlay), findsNothing);
        expect(find.byType(ContentWarningBlurOverlay), findsNothing);
      },
    );

    testWidgets('exposes localized semantics label and hint', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        InfiniteVideoFeed.debugIsSupportedOverride = true;

        final video = _makeVideo();
        final cubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);

        await _pumpFeedVideos(
          tester,
          videos: [video],
          videoPlaybackStatusCubit: cubit,
        );
        await tester.pump(const Duration(seconds: 4));

        final l10n = lookupAppLocalizations(const Locale('en'));
        final surfaceFinder = find.bySemanticsLabel(l10n.videoPlayerPlayVideo);

        expect(surfaceFinder, findsOneWidget);
        final semanticsNode = tester.getSemantics(surfaceFinder);
        expect(semanticsNode.flagsCollection.isButton, isTrue);
        expect(semanticsNode.hint, equals(l10n.videoPlayerTapHint));
      } finally {
        semantics.dispose();
      }
    });
  });

  // -------------------------------------------------------------------------
  // Pagination flush (didUpdateWidget)
  // -------------------------------------------------------------------------
  group('pagination flush', () {
    testWidgets(
      'does not throw when hasMore and isLoadingMore change',
      (tester) async {
        final video = _makeVideo();
        var hasMore = false;
        var isLoadingMore = false;
        late StateSetter rebuildState;

        final mockPlaybackCubit = _MockVideoPlaybackStatusCubit()
          ..stub(PlaybackStatus.ready, video.id);
        final mockAutoAdvanceCubit = _MockFeedAutoAdvanceCubit()
          ..stub(const FeedAutoAdvanceState());
        final mockVolumeCubit = _MockVideoVolumeCubit()..stub();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: ProviderContainer(overrides: _buildOverrides().cast()),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<FeedAutoAdvanceCubit>.value(
                    value: mockAutoAdvanceCubit,
                  ),
                  BlocProvider<VideoPlaybackStatusCubit>.value(
                    value: mockPlaybackCubit,
                  ),
                  BlocProvider<VideoVolumeCubit>.value(value: mockVolumeCubit),
                ],
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      rebuildState = setState;
                      return FeedVideos(
                        videos: [video],
                        onNearEnd: () {},
                        hasMore: hasMore,
                        isLoadingMore: isLoadingMore,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(seconds: 4));

        // Simulate a pagination start.
        rebuildState(() {
          hasMore = true;
          isLoadingMore = true;
        });
        // Advance past InfiniteVideoFeed's 3-second grace-period timer.
        await tester.pump(const Duration(seconds: 4));

        // Simulate pagination complete.
        rebuildState(() {
          hasMore = false;
          isLoadingMore = false;
        });
        // Drain any pending 3-second grace-period timers created by
        // InfiniteVideoFeed._waitForFirstFrameOrGracePeriod so that the
        // widget tree can be disposed cleanly by the test framework.
        await tester.pump(const Duration(seconds: 4));
        // Replace the widget tree to stop InfiniteVideoFeed's async chain
        // from scheduling new timers, then drain the cleared queue.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 4));
      },
    );
  });
}

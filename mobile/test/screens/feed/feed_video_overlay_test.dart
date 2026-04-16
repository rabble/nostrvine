// ABOUTME: Tests for FeedVideoOverlay — list attribution integration and
// ABOUTME: scroll-driven opacity behavior.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/feed_video_overlay.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/scroll_driven_opacity.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';
import 'package:openvine/widgets/video_feed_item/list_attribution_chip.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../test_data/video_test_data.dart';

class _MockVideoInteractionsBloc
    extends MockBloc<VideoInteractionsEvent, VideoInteractionsState>
    implements VideoInteractionsBloc {}

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockMediaAuthInterceptor extends Mock implements MediaAuthInterceptor {}

class _MockVideoFeedController extends Mock implements VideoFeedController {}

class _FakeBuildContext extends Fake implements BuildContext {}

// Full 64-character test IDs (never truncate Nostr IDs)
const _testVideoId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _testPubkey =
    'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3';

void main() {
  group(FeedVideoOverlay, () {
    late VideoInteractionsBloc mockInteractionsBloc;
    late Player mockPlayer;
    late PlayerStream mockStream;
    late PlayerState mockPlayerState;
    late CuratedListRepository mockCuratedListRepository;
    late VideoEventService mockVideoEventService;
    late MockProfileRepository mockProfileRepository;
    late MockNip05VerificationService mockNip05VerificationService;
    late VideoEvent testVideo;
    late StreamController<bool> playingController;
    late StreamController<bool> bufferingController;
    late ValueNotifier<double> pagePosition;

    setUpAll(() {
      registerFallbackValue(const VideoInteractionsSubscriptionRequested());
      registerFallbackValue(_FakeBuildContext());
      registerFallbackValue(<String, String>{});
    });

    setUp(() {
      mockInteractionsBloc = _MockVideoInteractionsBloc();
      mockPlayer = _MockPlayer();
      mockStream = _MockPlayerStream();
      mockPlayerState = _MockPlayerState();
      mockCuratedListRepository = _MockCuratedListRepository();
      mockVideoEventService = _MockVideoEventService();
      mockProfileRepository = createMockProfileRepository();
      mockNip05VerificationService = createMockNip05VerificationService();
      playingController = StreamController<bool>.broadcast();
      bufferingController = StreamController<bool>.broadcast();
      pagePosition = ValueNotifier<double>(0);

      // Stub Player.stream for subtitle layer and paused-play overlay.
      when(() => mockPlayer.stream).thenReturn(mockStream);
      when(() => mockPlayer.state).thenReturn(mockPlayerState);
      when(
        () => mockStream.position,
      ).thenAnswer((_) => const Stream<Duration>.empty());
      when(
        () => mockStream.playing,
      ).thenAnswer((_) => playingController.stream);
      when(
        () => mockStream.buffering,
      ).thenAnswer((_) => bufferingController.stream);
      when(() => mockPlayerState.playing).thenReturn(false);
      when(() => mockPlayerState.buffering).thenReturn(false);
      when(
        () => mockVideoEventService.getRepostersForVideo(any()),
      ).thenAnswer((_) async => const <String>[]);

      // Stub interactions bloc state
      when(
        () => mockInteractionsBloc.state,
      ).thenReturn(const VideoInteractionsState());

      testVideo = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: 1704067200,
        content: 'Test video content',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
        videoUrl: 'https://example.com/video.mp4',
      );
    });

    tearDown(() async {
      await playingController.close();
      await bufferingController.close();
      pagePosition.dispose();
    });

    Widget buildSubject({
      Set<String>? listSources,
      Future<void>? firstFrameFuture,
      bool isActive = true,
      Player? player,
      bool includePlayer = true,
      ValueNotifier<double>? pagePositionOverride,
      int index = 0,
      bool showAutoButton = false,
      bool isAutoEnabled = false,
      VoidCallback? onAutoPressed,
      VideoFeedController? feedController,
      List<dynamic>? additionalOverrides,
    }) {
      final overlay = FeedVideoOverlay(
        video: testVideo,
        isActive: isActive,
        pagePosition: pagePositionOverride ?? pagePosition,
        index: index,
        player: includePlayer ? (player ?? mockPlayer) : null,
        firstFrameFuture: firstFrameFuture,
        listSources: listSources,
        showAutoButton: showAutoButton,
        isAutoEnabled: isAutoEnabled,
        onAutoPressed: onAutoPressed,
      );

      return testMaterialApp(
        additionalOverrides: [
          curatedListRepositoryProvider.overrideWithValue(
            mockCuratedListRepository,
          ),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          ...?additionalOverrides,
        ],
        mockProfileRepository: mockProfileRepository,
        mockNip05VerificationService: mockNip05VerificationService,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
              ),
              BlocProvider<VideoPlaybackStatusCubit>(
                create: (_) => VideoPlaybackStatusCubit(),
              ),
            ],
            child: feedController == null
                ? overlay
                : VideoPoolProvider(
                    feedController: feedController,
                    child: overlay,
                  ),
          ),
        ),
      );
    }

    group('list attribution', () {
      testWidgets(
        'does not show the content warning overlay for creator labels without warn labels',
        (tester) async {
          testVideo = testVideo.copyWith(
            contentWarningLabels: const ['violence'],
          );

          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(find.text('Sensitive Content'), findsNothing);
          expect(find.text('View Anyway'), findsNothing);
          expect(find.text('Hide all content like this'), findsNothing);
          expect(find.byType(ProofModeBadgeRow), findsOneWidget);
        },
      );

      testWidgets('renders a centered play affordance when paused', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        playingController.add(true);
        await tester.pump();
        playingController.add(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(find.byKey(const ValueKey('paused-play')), findsOneWidget);
      });

      testWidgets('hides the centered play affordance while playing', (
        tester,
      ) async {
        when(() => mockPlayerState.playing).thenReturn(true);

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byKey(const ValueKey('paused-play')), findsNothing);
      });

      testWidgets(
        'waits for the first frame before showing play after playback starts',
        (tester) async {
          final firstFrameCompleter = Completer<void>();

          await tester.pumpWidget(
            buildSubject(firstFrameFuture: firstFrameCompleter.future),
          );
          await tester.pump();

          expect(find.byKey(const ValueKey('paused-play')), findsNothing);

          firstFrameCompleter.complete();
          await tester.pump();
          expect(find.byKey(const ValueKey('paused-play')), findsNothing);

          playingController.add(true);
          await tester.pump();
          playingController.add(false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 220));

          expect(find.byKey(const ValueKey('paused-play')), findsOneWidget);
        },
      );

      testWidgets('still renders badges when inactive and player is missing', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(isActive: false, includePlayer: false),
        );
        await tester.pump();

        expect(find.byType(ProofModeBadgeRow), findsOneWidget);
      });

      testWidgets(
        'verify age retries pooled playback with viewer auth headers',
        (tester) async {
          const sha256 =
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
          const videoUrl = 'https://media.divine.video/$sha256/720p.mp4';
          const headers = {'Authorization': 'Nostr viewer-token'};
          final mockMediaAuthInterceptor = _MockMediaAuthInterceptor();
          final mockFeedController = _MockVideoFeedController();

          testVideo = createTestVideoEvent(
            id: _testVideoId,
            pubkey: _testPubkey,
            videoUrl: videoUrl,
            sha256: sha256,
          );

          when(
            () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
              context: any(named: 'context'),
              sha256Hash: sha256,
              url: videoUrl,
              serverUrl: 'https://media.divine.video',
              category: 'video',
            ),
          ).thenAnswer((_) async => headers);
          when(
            () => mockFeedController.updateRequestHeadersAndRetry(0, headers),
          ).thenReturn(null);

          await tester.pumpWidget(
            buildSubject(
              feedController: mockFeedController,
              additionalOverrides: [
                mediaAuthInterceptorProvider.overrideWithValue(
                  mockMediaAuthInterceptor,
                ),
              ],
            ),
          );
          await tester.pump();

          final cubit = BlocProvider.of<VideoPlaybackStatusCubit>(
            tester.element(find.byType(FeedVideoOverlay)),
          );
          cubit.report(testVideo.id, PlaybackStatus.ageRestricted);
          await tester.pump();

          expect(find.byType(ModeratedContentOverlay), findsOneWidget);
          expect(
            find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
            findsOneWidget,
          );

          await tester.tap(
            find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
          );
          await tester.pump();

          verify(
            () => mockMediaAuthInterceptor.handleUnauthorizedMedia(
              context: any(named: 'context'),
              sha256Hash: sha256,
              url: videoUrl,
              serverUrl: 'https://media.divine.video',
              category: 'video',
            ),
          ).called(1);
          verify(
            () => mockFeedController.updateRequestHeadersAndRetry(0, headers),
          ).called(1);
          expect(cubit.state.statusFor(testVideo.id), PlaybackStatus.ready);
        },
      );

      testWidgets('renders $ListAttributionChip when listSources is provided', (
        tester,
      ) async {
        final testList = CuratedList(
          id: 'list-1',
          name: 'Cool Videos',
          videoEventIds: const ['v1', 'v2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          () => mockCuratedListRepository.getListById('list-1'),
        ).thenReturn(testList);

        await tester.pumpWidget(buildSubject(listSources: {'list-1'}));
        await tester.pump();

        expect(find.byType(ListAttributionChip), findsOneWidget);
        expect(find.text('Cool Videos'), findsOneWidget);
        expect(find.byIcon(Icons.playlist_play), findsOneWidget);
      });

      testWidgets(
        'does not render $ListAttributionChip when listSources is null',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.pump();

          expect(find.byType(ListAttributionChip), findsNothing);
        },
      );

      testWidgets(
        'does not render $ListAttributionChip when listSources is empty',
        (tester) async {
          await tester.pumpWidget(buildSubject(listSources: {}));
          await tester.pump();

          expect(find.byType(ListAttributionChip), findsNothing);
        },
      );

      testWidgets('renders multiple list chips for multiple sources', (
        tester,
      ) async {
        final list1 = CuratedList(
          id: 'list-1',
          name: 'Cool Videos',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final list2 = CuratedList(
          id: 'list-2',
          name: 'Funny Clips',
          videoEventIds: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(
          () => mockCuratedListRepository.getListById('list-1'),
        ).thenReturn(list1);
        when(
          () => mockCuratedListRepository.getListById('list-2'),
        ).thenReturn(list2);

        await tester.pumpWidget(
          buildSubject(listSources: {'list-1', 'list-2'}),
        );
        await tester.pump();

        expect(find.byType(ListAttributionChip), findsOneWidget);
        expect(find.byIcon(Icons.playlist_play), findsNWidgets(2));
      });

      testWidgets('opens metadata sheet when tapping the description', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        await tester.tap(find.text('Test video content'));
        await tester.pumpAndSettle();

        expect(find.text('Loops'), findsOneWidget);
        expect(find.text('Likes'), findsOneWidget);
      });

      testWidgets('renders Auto action when enabled for the current feed', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            showAutoButton: true,
            isAutoEnabled: true,
            onAutoPressed: () {},
          ),
        );
        await tester.pump();

        expect(find.text('Auto'), findsNothing);
        expect(find.bySemanticsLabel('Disable auto advance'), findsOneWidget);
      });
    });

    group('scroll-driven opacity', () {
      double overlayOpacity(WidgetTester tester) {
        // Find the Opacity widget wrapping the scroll-faded overlay Stack.
        // The gradient Positioned is outside the fade, so we look for the
        // outermost Opacity whose child is an IgnorePointer.
        final opacityWidgets = tester
            .widgetList<Opacity>(find.byType(Opacity))
            .toList();
        // The scroll-faded Opacity is the one built by ValueListenableBuilder.
        // It is the only Opacity that wraps an IgnorePointer directly.
        for (final widget in opacityWidgets) {
          final element = tester.element(
            find.byWidget(widget, skipOffstage: false),
          );
          bool hasIgnorePointerChild = false;
          element.visitChildren((child) {
            if (child.widget is IgnorePointer) {
              hasIgnorePointerChild = true;
            }
          });
          if (hasIgnorePointerChild) return widget.opacity;
        }
        throw StateError('Scroll-faded Opacity widget not found in tree');
      }

      testWidgets(
        'overlay is fully opaque when pagePosition matches index',
        (tester) async {
          // index=0, pagePosition=0.0 → distance=0 → opacity=1.0
          await tester.pumpWidget(buildSubject());
          await tester.pump();
          pagePosition.value = 0.0;
          await tester.pump();

          expect(overlayOpacity(tester), equals(1.0));
        },
      );

      testWidgets(
        'overlay is fully hidden when scrolled a full page away',
        (tester) async {
          // index=0, pagePosition=1.0 → distance=1.0 → opacity=0.0
          await tester.pumpWidget(buildSubject());
          await tester.pump();
          pagePosition.value = 1.0;
          await tester.pump();

          expect(overlayOpacity(tester), equals(0.0));
        },
      );

      testWidgets(
        'overlay uses dimmed opacity in the middle of the scroll band',
        (tester) async {
          // index=0, pagePosition=0.3 → distance=0.3 (between thresholds)
          // → opacity == kOverlayDimmedOpacity
          await tester.pumpWidget(buildSubject());
          await tester.pump();
          pagePosition.value = 0.3;
          await tester.pump();

          expect(
            overlayOpacity(tester),
            closeTo(kOverlayDimmedOpacity, 1e-9),
          );
        },
      );

      testWidgets(
        'overlay opacity updates when pagePosition changes',
        (tester) async {
          await tester.pumpWidget(buildSubject());
          await tester.pump();

          pagePosition.value = 0.0;
          await tester.pump();
          expect(overlayOpacity(tester), equals(1.0));

          pagePosition.value = 1.0;
          await tester.pump();
          expect(overlayOpacity(tester), equals(0.0));
        },
      );

      testWidgets(
        'overlay is fully opaque for a non-zero index when pagePosition matches',
        (tester) async {
          // index=2, pagePosition=2.0 → distance=0 → opacity=1.0
          await tester.pumpWidget(buildSubject(index: 2));
          await tester.pump();
          pagePosition.value = 2.0;
          await tester.pump();

          expect(overlayOpacity(tester), equals(1.0));
        },
      );
    });
  });
}

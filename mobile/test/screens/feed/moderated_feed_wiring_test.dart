// ABOUTME: Smoke test proving FeedVideoOverlay swaps in ModeratedContentOverlay
// ABOUTME: when its VideoPlaybackStatusCubit reports a forbidden status.

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
import 'package:openvine/widgets/proofmode_badge_row.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc
    extends MockBloc<VideoInteractionsEvent, VideoInteractionsState>
    implements VideoInteractionsBloc {}

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

// Full 64-character Nostr IDs — never truncate.
const _testVideoId =
    'fe1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd';
const _testPubkey =
    '9988776655443322110099887766554433221100998877665544332211009988';

void main() {
  group('FeedVideoOverlay moderated-content wiring', () {
    late VideoInteractionsBloc mockInteractionsBloc;
    late Player mockPlayer;
    late PlayerStream mockStream;
    late PlayerState mockPlayerState;
    late CuratedListRepository mockCuratedListRepository;
    late MockProfileRepository mockProfileRepository;
    late MockNip05VerificationService mockNip05VerificationService;
    late VideoEvent testVideo;
    late StreamController<bool> playingController;
    late StreamController<bool> bufferingController;
    late ValueNotifier<double> pagePosition;
    late VideoPlaybackStatusCubit cubit;

    setUpAll(() {
      registerFallbackValue(const VideoInteractionsSubscriptionRequested());
    });

    setUp(() {
      mockInteractionsBloc = _MockVideoInteractionsBloc();
      mockPlayer = _MockPlayer();
      mockStream = _MockPlayerStream();
      mockPlayerState = _MockPlayerState();
      mockCuratedListRepository = _MockCuratedListRepository();
      mockProfileRepository = createMockProfileRepository();
      mockNip05VerificationService = createMockNip05VerificationService();
      playingController = StreamController<bool>.broadcast();
      bufferingController = StreamController<bool>.broadcast();
      pagePosition = ValueNotifier<double>(0);
      cubit = VideoPlaybackStatusCubit();

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
      await cubit.close();
    });

    Widget buildSubject() {
      return testMaterialApp(
        additionalOverrides: [
          curatedListRepositoryProvider.overrideWithValue(
            mockCuratedListRepository,
          ),
        ],
        mockProfileRepository: mockProfileRepository,
        mockNip05VerificationService: mockNip05VerificationService,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<VideoInteractionsBloc>.value(
                value: mockInteractionsBloc,
              ),
              BlocProvider<VideoPlaybackStatusCubit>.value(value: cubit),
            ],
            child: FeedVideoOverlay(
              video: testVideo,
              isActive: true,
              pagePosition: pagePosition,
              index: 0,
              player: mockPlayer,
            ),
          ),
        ),
      );
    }

    testWidgets(
      'renders normal chrome when status is ready and swaps in '
      'ModeratedContentOverlay when cubit reports forbidden',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Normal chrome (badges) visible, moderated overlay absent.
        expect(find.byType(ProofModeBadgeRow), findsOneWidget);
        expect(find.byType(ModeratedContentOverlay), findsNothing);

        // Report forbidden for the active video.
        cubit.report(_testVideoId, PlaybackStatus.forbidden);
        await tester.pump();

        // Moderated overlay takes over — the normal chrome (ProofModeBadgeRow,
        // author description) is gone.
        expect(find.byType(ModeratedContentOverlay), findsOneWidget);
        expect(find.byType(ProofModeBadgeRow), findsNothing);
        expect(find.text('Test video content'), findsNothing);
        expect(
          find.text(ModeratedContentOverlayStrings.forbiddenTitle),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders ModeratedContentOverlay with verify-age CTA when cubit reports '
      'ageRestricted',
      (tester) async {
        cubit.report(_testVideoId, PlaybackStatus.ageRestricted);

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(ModeratedContentOverlay), findsOneWidget);
        expect(
          find.text(ModeratedContentOverlayStrings.ageRestrictedTitle),
          findsOneWidget,
        );
        expect(
          find.text(ModeratedContentOverlayStrings.verifyAgeLabel),
          findsOneWidget,
        );
        expect(find.byType(ProofModeBadgeRow), findsNothing);
      },
    );
  });
}

// ABOUTME: Tests for FeedVideoOverlay list attribution integration
// ABOUTME: Verifies ListAttributionChip display for curated list videos

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
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/feed_video_overlay.dart';
import 'package:openvine/widgets/video_feed_item/list_attribution_chip.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc
    extends MockBloc<VideoInteractionsEvent, VideoInteractionsState>
    implements VideoInteractionsBloc {}

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

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
    late VideoEvent testVideo;
    late StreamController<bool> playingController;
    late StreamController<bool> bufferingController;

    setUpAll(() {
      registerFallbackValue(const VideoInteractionsSubscriptionRequested());
    });

    setUp(() {
      mockInteractionsBloc = _MockVideoInteractionsBloc();
      mockPlayer = _MockPlayer();
      mockStream = _MockPlayerStream();
      mockPlayerState = _MockPlayerState();
      mockCuratedListRepository = _MockCuratedListRepository();
      playingController = StreamController<bool>.broadcast();
      bufferingController = StreamController<bool>.broadcast();

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
    });

    Widget buildSubject({
      Set<String>? listSources,
      Future<void>? firstFrameFuture,
    }) {
      return testMaterialApp(
        additionalOverrides: [
          curatedListRepositoryProvider.overrideWithValue(
            mockCuratedListRepository,
          ),
          userProfileServiceProvider.overrideWithValue(
            createMockUserProfileService(),
          ),
        ],
        home: Scaffold(
          body: BlocProvider<VideoInteractionsBloc>.value(
            value: mockInteractionsBloc,
            child: FeedVideoOverlay(
              video: testVideo,
              isActive: true,
              player: mockPlayer,
              firstFrameFuture: firstFrameFuture,
              listSources: listSources,
            ),
          ),
        ),
      );
    }

    group('list attribution', () {
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

        expect(find.bySemanticsLabel('Play video'), findsOneWidget);
      });

      testWidgets('hides the centered play affordance while playing', (
        tester,
      ) async {
        when(() => mockPlayerState.playing).thenReturn(true);

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.bySemanticsLabel('Play video'), findsNothing);
      });

      testWidgets(
        'waits for the first frame before showing play after playback starts',
        (tester) async {
          final firstFrameCompleter = Completer<void>();

          await tester.pumpWidget(
            buildSubject(firstFrameFuture: firstFrameCompleter.future),
          );
          await tester.pump();

          expect(find.bySemanticsLabel('Play video'), findsNothing);

          firstFrameCompleter.complete();
          await tester.pump();
          expect(find.bySemanticsLabel('Play video'), findsNothing);

          playingController.add(true);
          await tester.pump();
          playingController.add(false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 220));

          expect(find.bySemanticsLabel('Play video'), findsOneWidget);
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
    });
  });
}

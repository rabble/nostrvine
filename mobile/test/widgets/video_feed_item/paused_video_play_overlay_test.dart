import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_play_overlay.dart';

class _MockDivineVideoPlayerController extends Mock
    implements DivineVideoPlayerController {}

void main() {
  group('PausedVideoPlayOverlay', () {
    late DivineVideoPlayerController mockController;
    late StreamController<DivineVideoPlayerState> stateStreamController;

    setUp(() {
      mockController = _MockDivineVideoPlayerController();
      stateStreamController =
          StreamController<DivineVideoPlayerState>.broadcast();

      when(() => mockController.state).thenReturn(
        const DivineVideoPlayerState(),
      );
      when(() => mockController.stateStream).thenAnswer(
        (_) => stateStreamController.stream,
      );
    });

    tearDown(() async {
      await stateStreamController.close();
    });

    Widget buildSubject({Key? key}) {
      return MaterialApp(
        home: Scaffold(
          body: PausedVideoPlayOverlay(
            key: key,
            controller: mockController,
            firstFrameFuture: Future<void>.value(),
          ),
        ),
      );
    }

    testWidgets(
      'keeps the play affordance visible when remounted with the same paused player after playback was observed',
      (tester) async {
        await tester.pumpWidget(buildSubject(key: const ValueKey('first')));
        await tester.pump();

        stateStreamController.add(
          const DivineVideoPlayerState(status: PlaybackStatus.playing),
        );
        await tester.pump();
        stateStreamController.add(
          const DivineVideoPlayerState(status: PlaybackStatus.paused),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(find.bySemanticsLabel('Play video'), findsOneWidget);

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pump();

        await tester.pumpWidget(buildSubject(key: const ValueKey('second')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        // After remount _hasStartedPlayback resets, so the overlay is hidden
        // until the player transitions through playing again.
        expect(find.bySemanticsLabel('Play video'), findsNothing);

        stateStreamController.add(
          const DivineVideoPlayerState(status: PlaybackStatus.playing),
        );
        await tester.pump();
        stateStreamController.add(
          const DivineVideoPlayerState(status: PlaybackStatus.paused),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(find.bySemanticsLabel('Play video'), findsOneWidget);
      },
    );
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_play_overlay.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockPlayerStream extends Mock implements PlayerStream {}

void main() {
  group('PausedVideoPlayOverlay', () {
    late Player mockPlayer;
    late PlayerState mockPlayerState;
    late PlayerStream mockPlayerStream;
    late StreamController<bool> playingController;
    late StreamController<bool> bufferingController;

    setUp(() {
      mockPlayer = _MockPlayer();
      mockPlayerState = _MockPlayerState();
      mockPlayerStream = _MockPlayerStream();
      playingController = StreamController<bool>.broadcast();
      bufferingController = StreamController<bool>.broadcast();

      when(() => mockPlayer.state).thenReturn(mockPlayerState);
      when(() => mockPlayer.stream).thenReturn(mockPlayerStream);
      when(() => mockPlayerState.playing).thenReturn(false);
      when(() => mockPlayerState.buffering).thenReturn(false);
      when(
        () => mockPlayerStream.playing,
      ).thenAnswer((_) => playingController.stream);
      when(
        () => mockPlayerStream.buffering,
      ).thenAnswer((_) => bufferingController.stream);
    });

    tearDown(() async {
      await playingController.close();
      await bufferingController.close();
    });

    Widget buildSubject({Key? key}) {
      return MaterialApp(
        home: Scaffold(
          body: PausedVideoPlayOverlay(
            key: key,
            player: mockPlayer,
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

        playingController.add(true);
        await tester.pump();
        playingController.add(false);
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

        playingController.add(true);
        await tester.pump();
        playingController.add(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(find.bySemanticsLabel('Play video'), findsOneWidget);
      },
    );
  });
}

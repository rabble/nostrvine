import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';
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
      when(() => mockPlayerState.volume).thenReturn(100.0);
      when(
        () => mockPlayerStream.playing,
      ).thenAnswer((_) => playingController.stream);
      when(
        () => mockPlayerStream.buffering,
      ).thenAnswer((_) => bufferingController.stream);
      when(
        () => mockPlayerStream.volume,
      ).thenAnswer((_) => const Stream<double>.empty());
    });

    tearDown(() async {
      await playingController.close();
      await bufferingController.close();
    });

    Widget buildSubject({Key? key}) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PausedVideoPlayOverlay(
            key: key,
            player: mockPlayer,
            firstFrameFuture: Future<void>.value(),
            onToggleMuteState: () {},
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

        expect(find.byKey(const ValueKey('paused-play')), findsOneWidget);

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SizedBox.shrink(),
          ),
        );
        await tester.pump();

        await tester.pumpWidget(buildSubject(key: const ValueKey('second')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        // After remount _hasStartedPlayback resets, so the overlay is hidden
        // until the player transitions through playing again.
        expect(find.byKey(const ValueKey('paused-play')), findsNothing);

        playingController.add(true);
        await tester.pump();
        playingController.add(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(find.byKey(const ValueKey('paused-play')), findsOneWidget);
      },
    );

    group('unpause feedback', () {
      Finder findPauseCenterControl() => find.byWidgetPredicate(
        (w) =>
            w is CenterPlaybackControl &&
            w.state == CenterPlaybackControlState.pause,
      );

      testWidgets('shows the pause icon briefly after a user-initiated unpause '
          '(pause longer than 150 ms then resume)', (tester) async {
        // The feedback threshold is compared against `clock.now()`
        // differences; drive a manual clock so the test is not at the
        // mercy of wall-clock timing.
        var now = DateTime(2026);
        await withClock(Clock(() => now), () async {
          await tester.pumpWidget(buildSubject());
          await tester.pump();

          // Latch: first paused -> playing transition enables future
          // feedback for this widget + player.
          playingController.add(true);
          await tester.pump();

          // Pause for longer than the 150 ms feedback threshold.
          playingController.add(false);
          await tester.pump();

          // Advance both the injected clock and the test clock so the
          // pause duration crosses the 150 ms threshold.
          now = now.add(const Duration(milliseconds: 220));
          await tester.pump(const Duration(milliseconds: 220));

          // While paused, the paused-play affordance is visible — the
          // feedback pause icon is explicitly *not* the play icon.
          expect(find.byKey(const ValueKey('paused-play')), findsOneWidget);
          expect(findPauseCenterControl(), findsNothing);

          // User taps to resume.
          playingController.add(true);
          // Let AnimatedSwitcher settle after the transition kicks in.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 220));

          // Feedback pause icon should now be mounted.
          expect(findPauseCenterControl(), findsOneWidget);
          expect(find.byKey(const ValueKey('paused-play')), findsNothing);

          // After the full feedback window + fade + AnimatedSwitcher
          // transition, the feedback collapses back to the hidden branch.
          await tester.pumpAndSettle();
          expect(findPauseCenterControl(), findsNothing);
          expect(find.byKey(const ValueKey('paused-play')), findsNothing);
        });
      });

      testWidgets(
        'does not flash feedback for sub-threshold loop-restart blips',
        (tester) async {
          var now = DateTime(2026);
          await withClock(Clock(() => now), () async {
            await tester.pumpWidget(buildSubject());
            await tester.pump();

            // Latch first.
            playingController.add(true);
            await tester.pump();

            // Simulate a loop-restart blip: paused -> playing within a
            // handful of milliseconds (well below the 150 ms threshold).
            playingController.add(false);
            now = now.add(const Duration(milliseconds: 10));
            await tester.pump(const Duration(milliseconds: 10));
            playingController.add(true);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 220));

            // No pause-icon feedback should ever render.
            expect(findPauseCenterControl(), findsNothing);
          });
        },
      );
    });
  });
}

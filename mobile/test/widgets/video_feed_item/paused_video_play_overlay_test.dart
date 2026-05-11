import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/widgets/video_feed_item/center_playback_control.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_play_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockPlayer extends Mock implements Player {}

class _MockPlayerState extends Mock implements PlayerState {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

void main() {
  group('PausedVideoPlayOverlay', () {
    late Player mockPlayer;
    late PlayerState mockPlayerState;
    late PlayerStream mockPlayerStream;
    late StreamController<bool> playingController;
    late StreamController<bool> bufferingController;
    late FeedAutoAdvanceCubit autoAdvanceCubit;
    late VideoVolumeCubit volumeCubit;
    late SharedPreferences mockPrefs;

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

      autoAdvanceCubit = FeedAutoAdvanceCubit();
      volumeCubit = _MockVideoVolumeCubit();
      when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
      mockPrefs = createMockSharedPreferences();
    });

    tearDown(() async {
      await playingController.close();
      await bufferingController.close();
      await autoAdvanceCubit.close();
    });

    Widget buildSubject({Key? key}) {
      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<FeedAutoAdvanceCubit>.value(value: autoAdvanceCubit),
            BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PausedVideoPlayOverlay(
                key: key,
                player: mockPlayer,
                firstFrameFuture: Future<void>.value(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'shows the play affordance immediately when the player is paused, '
      'even before any play has been observed',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(find.byKey(const ValueKey('paused-play')), findsOneWidget);
      },
    );

    testWidgets(
      'hides the play affordance while the player is buffering',
      (tester) async {
        when(() => mockPlayerState.buffering).thenReturn(true);
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        bufferingController.add(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(find.byKey(const ValueKey('paused-play')), findsNothing);
      },
    );

    testWidgets(
      'renders the playback toggles pill above the play icon when paused',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(find.byType(FeedPlaybackTogglesPill), findsOneWidget);
        expect(find.byKey(const ValueKey('paused-play')), findsOneWidget);

        final pillCenter = tester.getCenter(
          find.byType(FeedPlaybackTogglesPill),
        );
        final playCenter = tester.getCenter(
          find.byKey(const ValueKey('paused-play')),
        );
        expect(
          pillCenter.dy,
          lessThan(playCenter.dy),
          reason: 'pill should sit above the play icon',
        );
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

          // Start from playing so the next paused->playing transition is
          // observable. Fully settle the AnimatedSwitcher's transition of
          // the initial paused-play affordance out of the tree before we
          // re-enter the paused state; without this, AnimatedSwitcher
          // accumulates outgoing entries across the bounce.
          playingController.add(true);
          await tester.pumpAndSettle();

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
          // Let AnimatedSwitcher kick the transition off.
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

            // Start from playing so the next paused->playing transition
            // is observable. Fully settle the AnimatedSwitcher's transition
            // of the initial paused-play affordance out of the tree before
            // we re-enter the paused state.
            playingController.add(true);
            await tester.pumpAndSettle();

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

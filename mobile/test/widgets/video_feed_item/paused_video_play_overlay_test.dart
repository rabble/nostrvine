import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
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
  });
}

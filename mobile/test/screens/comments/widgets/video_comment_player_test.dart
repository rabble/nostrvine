import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../helpers/web_video_player_test_doubles.dart';

/// A fake controller that records the order of [pause] and [dispose] and never
/// marks itself initialized (so the widget doesn't build a real [VideoPlayer]).
class _RecordingController extends FakeVideoPlayerController {
  _RecordingController(this.calls);

  final List<String> calls;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pause() async {
    calls.add('pause');
    await super.pause();
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await super.dispose();
  }
}

/// A recording fake whose [initialize] blocks on [initCompleter], so a test can
/// unmount the widget while the first play is still in flight.
class _DeferredInitController extends FakeVideoPlayerController {
  _DeferredInitController(this.calls, this.initCompleter);

  final List<String> calls;
  final Completer<void> initCompleter;

  @override
  Future<void> initialize() => initCompleter.future;

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await super.dispose();
  }
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('clips to the provided border radius', (tester) async {
    const borderRadius = BorderRadius.all(Radius.circular(12));

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoCommentPlayer(
            videoUrl: 'https://media.divine.video/comment-video.mp4',
            borderRadius: borderRadius,
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(
      find.ancestor(
        of: find.byType(VisibilityDetector),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clip.borderRadius, borderRadius);
  });

  testWidgets('opens the full video page from the inline comment player', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoCommentPlayer(
            videoUrl: 'https://media.divine.video/comment-video.mp4',
            onOpenVideo: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.byType(VideoCommentPlayer), findsOneWidget);
    await tester.tap(find.byType(DivineIconButton));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('pauses before disposing when unmounted after play', (
    tester,
  ) async {
    final calls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoCommentPlayer(
            videoUrl: 'https://media.divine.video/comment-video.mp4',
            controllerFactory: (_) => _RecordingController(calls),
          ),
        ),
      ),
    );

    // Tap the player surface to start playback.
    await tester.tap(find.byType(VideoCommentPlayer));
    await tester.pump();

    // Unmount the widget, then flush the async teardown closure.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(calls, equals(['pause', 'dispose']));
  });

  testWidgets('pauses before disposing on the in-flight !mounted path', (
    tester,
  ) async {
    final calls = <String>[];
    final initCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoCommentPlayer(
            videoUrl: 'https://media.divine.video/comment-video.mp4',
            controllerFactory: (_) =>
                _DeferredInitController(calls, initCompleter),
          ),
        ),
      ),
    );

    // Start playback; initialize() is now pending.
    await tester.tap(find.byType(VideoCommentPlayer));
    await tester.pump();

    // Unmount before initialization completes, then let it complete so the
    // in-flight _togglePlay hits the !mounted teardown branch.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    initCompleter.complete();
    await tester.pump();

    expect(calls, equals(['pause', 'dispose']));
  });
}

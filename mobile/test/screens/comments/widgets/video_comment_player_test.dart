import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  // Records the native method invocations the widget drives through
  // divine_video_player, so tests can assert the migrated controller wiring
  // (create/play/pause/dispose) without a real native player.
  final methodCalls = <String>[];

  void mockHandler(String channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), (call) async {
          methodCalls.add(call.method);
          if (call.method == 'create') {
            return <String, Object?>{'textureId': 1};
          }
          return null;
        });
  }

  void clearHandler(String channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), null);
  }

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    methodCalls.clear();
    DivineVideoPlayerController.resetIdCounterForTesting();
    // The first controller created in a test always gets player id 0.
    mockHandler('divine_video_player');
    mockHandler('divine_video_player/player_0');
    mockHandler('divine_video_player/player_0/events');
  });

  tearDown(() {
    clearHandler('divine_video_player');
    clearHandler('divine_video_player/player_0');
    clearHandler('divine_video_player/player_0/events');
  });

  Widget buildPlayer({VoidCallback? onOpenVideo}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: VideoCommentPlayer(
          videoUrl: 'https://media.divine.video/comment-video.mp4',
          onOpenVideo: onOpenVideo,
        ),
      ),
    );
  }

  // Flushes the async initialize→setSource→…→play chain that runs over the
  // mocked platform channels after a tap.
  Future<void> startPlayback(WidgetTester tester) async {
    await tester.tap(find.byType(VideoCommentPlayer));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

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

    await tester.pumpWidget(buildPlayer(onOpenVideo: () => opened = true));

    expect(find.byType(VideoCommentPlayer), findsOneWidget);
    await tester.tap(find.byType(DivineIconButton));
    await tester.pump();

    expect(opened, isTrue);
  });

  testWidgets('renders a $DivineVideoPlayer surface', (tester) async {
    await tester.pumpWidget(buildPlayer());

    expect(find.byType(DivineVideoPlayer), findsOneWidget);
  });

  testWidgets('creates and plays a Divine controller when tapped', (
    tester,
  ) async {
    await tester.pumpWidget(buildPlayer());
    await startPlayback(tester);

    expect(
      methodCalls,
      containsAll(<String>['create', 'setClips', 'setLooping', 'play']),
    );
  });

  testWidgets('disposes the native controller when unmounted', (tester) async {
    await tester.pumpWidget(buildPlayer());
    await startPlayback(tester);
    expect(DivineVideoPlayerController.liveControllerCount, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    // dispose() drops the controller from the live registry synchronously.
    expect(DivineVideoPlayerController.liveControllerCount, 0);
  });

  testWidgets('pauses playback when the app is backgrounded', (tester) async {
    await tester.pumpWidget(buildPlayer());
    await startPlayback(tester);

    methodCalls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(methodCalls, contains('pause'));
  });
}

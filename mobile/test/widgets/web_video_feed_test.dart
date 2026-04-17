import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/web_video_feed.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

class _FakeVideoPlayerController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  _FakeVideoPlayerController()
    : super(const VideoPlayerValue(duration: Duration.zero));

  void emitValue(VideoPlayerValue newValue) {
    value = newValue;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {
    value = const VideoPlayerValue(
      duration: Duration(seconds: 6),
      isInitialized: true,
      size: Size(1080, 1920),
    );
  }

  @override
  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration position) async {
    value = value.copyWith(position: position);
  }

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> dispose() async => super.dispose();

  int get textureId => 0;

  @override
  int get playerId => 0;

  @override
  VideoViewType get viewType => VideoViewType.textureView;

  @override
  void setCaptionOffset(Duration offset) {}

  @override
  Future<Duration> get position async => value.position;

  @override
  Future<void> setClosedCaptionFile(
    Future<ClosedCaptionFile>? closedCaptionFile,
  ) async {}

  @override
  VideoFormat? get formatHint => null;

  @override
  String get dataSource => 'https://example.com/test.mp4';

  @override
  DataSourceType get dataSourceType => DataSourceType.network;

  @override
  String get package => '';

  @override
  Map<String, String> get httpHeaders => const {};

  @override
  Future<ClosedCaptionFile>? get closedCaptionFile => null;

  @override
  VideoPlayerOptions? get videoPlayerOptions => null;
}

class _FakeVideoPlayerPlatform extends video_platform.VideoPlayerPlatform {
  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<int?> create(video_platform.DataSource dataSource) async => 0;

  @override
  Stream<video_platform.VideoEvent> videoEventsFor(int playerId) =>
      const Stream.empty();

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

VideoEvent _makeVideo({int seed = 0}) {
  final hex = seed.toRadixString(16).padLeft(2, '0');
  return VideoEvent(
    id: 'a1b2c3d4e5f6789012345678901234567890abcdef12345678901234567890$hex',
    pubkey:
        'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3',
    createdAt: 1700000000,
    content: 'Test video $seed',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
    videoUrl: 'https://example.com/video$seed.mp4',
  );
}

void main() {
  late video_platform.VideoPlayerPlatform originalPlatform;

  setUp(() {
    originalPlatform = video_platform.VideoPlayerPlatform.instance;
    video_platform.VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
  });

  tearDown(() {
    video_platform.VideoPlayerPlatform.instance = originalPlatform;
  });

  testWidgets('rebuilds itemBuilder when the web controller initializes', (
    tester,
  ) async {
    final controller = _FakeVideoPlayerController();

    await tester.pumpWidget(
      MaterialApp(
        home: WebVideoFeed(
          videos: [_makeVideo()],
          controllerFactory: ({required url, required headers}) => controller,
          itemBuilder:
              (
                context,
                video,
                index, {
                required isActive,
                controller,
              }) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Text(controller == null ? 'waiting' : 'ready'),
                );
              },
        ),
      ),
    );

    expect(find.text('waiting'), findsOneWidget);

    await tester.pump();

    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('fires onCompleted when the active video loops', (tester) async {
    final controller = _FakeVideoPlayerController();
    var completionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: WebVideoFeed(
          videos: [_makeVideo()],
          controllerFactory: ({required url, required headers}) => controller,
          onCompleted: (_) => completionCount++,
        ),
      ),
    );

    await tester.pump();

    controller.emitValue(
      controller.value.copyWith(
        isInitialized: true,
        duration: const Duration(seconds: 6),
        position: const Duration(seconds: 5, milliseconds: 500),
      ),
    );
    await tester.pump();

    controller.emitValue(
      controller.value.copyWith(position: const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(completionCount, 1);
  });

  testWidgets('animateToPage moves to the requested page', (tester) async {
    final key = GlobalKey<WebVideoFeedState>();
    final videos = [
      _makeVideo(),
      _makeVideo().copyWith(
        id: 'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234',
        videoUrl: 'https://example.com/video-2.mp4',
      ),
    ];
    final controller1 = _FakeVideoPlayerController();
    final controller2 = _FakeVideoPlayerController();
    var activeIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: WebVideoFeed(
          key: key,
          videos: videos,
          controllerFactory: ({required url, required headers}) {
            return url.toString().contains('video-2')
                ? controller2
                : controller1;
          },
          onActiveVideoChanged: (_, index) => activeIndex = index,
        ),
      ),
    );

    await tester.pump();

    unawaited(key.currentState!.animateToPage(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(key.currentState!.currentIndex, 1);
    expect(activeIndex, 1);
  });

  testWidgets(
    'drops controller entries when WebVideoPlayer items are disposed',
    (tester) async {
      final videos = List.generate(8, (i) => _makeVideo(seed: i));

      await tester.pumpWidget(
        MaterialApp(
          home: WebVideoFeed(
            videos: videos,
            controllerFactory: ({required url, required headers}) =>
                _FakeVideoPlayerController(),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<State<WebVideoFeed>>(
                find.byType(WebVideoFeed),
              )
              as dynamic;
      final pageController = tester
          .widget<PageView>(
            find.byType(PageView),
          )
          .controller!;

      // Drive PageView through several indices. Pages that drop out of the
      // viewport cause their WebVideoPlayer state to dispose, which must
      // evict the tracked controller entry.
      for (var i = 1; i < videos.length; i++) {
        pageController.jumpToPage(i);
        await tester.pump();
      }

      // With bounded eviction, the tracked controllers and player keys must
      // not include every visited index — only those still alive in the
      // PageView viewport.
      expect(
        state.debugControllerCount as int,
        lessThan(videos.length),
        reason: 'controllers should be evicted for disposed items',
      );
      expect(
        state.debugPlayerKeyCount as int,
        lessThan(videos.length),
        reason: 'player keys should be pruned for disposed items',
      );
    },
  );

  testWidgets(
    'prunes stale controller entries when videos list shrinks',
    (tester) async {
      final initial = List.generate(4, (i) => _makeVideo(seed: i));

      await tester.pumpWidget(
        MaterialApp(
          home: WebVideoFeed(
            videos: initial,
            controllerFactory: ({required url, required headers}) =>
                _FakeVideoPlayerController(),
          ),
        ),
      );
      await tester.pump();

      // Shrink the list — the feed should prune indices that no longer map
      // to a valid video.
      await tester.pumpWidget(
        MaterialApp(
          home: WebVideoFeed(
            videos: [initial.first],
            controllerFactory: ({required url, required headers}) =>
                _FakeVideoPlayerController(),
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<State<WebVideoFeed>>(
                find.byType(WebVideoFeed),
              )
              as dynamic;

      expect(state.debugControllerCount as int, lessThanOrEqualTo(1));
      expect(state.debugPlayerKeyCount as int, lessThanOrEqualTo(1));
    },
  );

  testWidgets(
    'does not rebuild the feed itemBuilder for every controller init',
    (tester) async {
      final videos = List.generate(3, (i) => _makeVideo(seed: i));
      final itemBuilderCalls = <int, int>{};

      await tester.pumpWidget(
        MaterialApp(
          home: WebVideoFeed(
            videos: videos,
            controllerFactory: ({required url, required headers}) =>
                _FakeVideoPlayerController(),
            itemBuilder:
                (
                  context,
                  video,
                  index, {
                  required isActive,
                  controller,
                }) {
                  itemBuilderCalls.update(
                    index,
                    (prev) => prev + 1,
                    ifAbsent: () => 1,
                  );
                  return const SizedBox.shrink();
                },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Each item builder only rebuilds for its own controller state changes,
      // not for every other page's controller init. 3 items × any number of
      // inits must stay well below N² builds.
      for (final entry in itemBuilderCalls.entries) {
        expect(
          entry.value,
          lessThanOrEqualTo(4),
          reason:
              'itemBuilder for index ${entry.key} rebuilt ${entry.value} '
              'times; expected scoped rebuilds only',
        );
      }
    },
  );
}

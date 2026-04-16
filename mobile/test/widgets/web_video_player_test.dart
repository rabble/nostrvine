import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/web_video_player.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

class _MockVideoPlayerController extends Mock
    implements VideoPlayerController {}

class _FakeVideoPlayerController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  _FakeVideoPlayerController({
    required Size videoSize,
    this.playError,
  }) : _videoSize = videoSize,
       super(const VideoPlayerValue(duration: Duration.zero));

  final Size _videoSize;
  final Exception? playError;

  @override
  Future<void> initialize() async {
    value = VideoPlayerValue(
      duration: const Duration(seconds: 6),
      isInitialized: true,
      size: _videoSize,
    );
  }

  @override
  Future<void> play() async {
    final error = playError;
    if (error != null) throw error;
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
  Widget buildView(int playerId) => Container(key: const Key('platform-view'));

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
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

  testWidgets('shows an error state when web video initialization times out', (
    tester,
  ) async {
    final controller = _MockVideoPlayerController();
    final initializeCompleter = Completer<void>();

    when(controller.initialize).thenAnswer((_) => initializeCompleter.future);
    when(controller.dispose).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WebVideoPlayer(
          url: 'https://example.com/video.mp4',
          initializeTimeout: const Duration(milliseconds: 50),
          controllerFactory: ({required url, required headers}) => controller,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('Failed to load video'), findsOneWidget);
  });

  testWidgets(
    'sizes the web player to a cover box so fullscreen video can crop',
    (tester) async {
      final controller = _FakeVideoPlayerController(
        videoSize: const Size(480, 480),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 600,
              child: WebVideoPlayer(
                url: 'https://example.com/video.mp4',
                controllerFactory: ({required url, required headers}) {
                  return controller;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byKey(const Key('platform-view')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('platform-view'))),
        const Size(600, 600),
      );
    },
  );

  testWidgets(
    'keeps the player initialized when autoplay is blocked by the browser',
    (tester) async {
      final controller = _FakeVideoPlayerController(
        videoSize: const Size(1080, 1920),
        playError: Exception('autoplay blocked'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WebVideoPlayer(
            url: 'https://example.com/video.mp4',
            autoPlay: true,
            controllerFactory: ({required url, required headers}) {
              return controller;
            },
          ),
        ),
      );

      await tester.pump();

      expect(find.byKey(const Key('platform-view')), findsOneWidget);
      expect(find.text('Failed to load video'), findsNothing);
    },
  );
}

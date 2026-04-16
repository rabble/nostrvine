import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/video_feed_item/video_player_subtitle_layer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class _FakeVideoPlayerController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  _FakeVideoPlayerController()
    : super(const VideoPlayerValue(duration: Duration.zero));

  void simulateInitialized({Duration position = Duration.zero}) {
    value = VideoPlayerValue(
      duration: const Duration(seconds: 6),
      isInitialized: true,
      isPlaying: true,
      position: position,
      size: const Size(1080, 1920),
    );
  }

  @override
  Future<void> initialize() async => simulateInitialized();

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

VideoEvent _makeVideo() => VideoEvent(
  id: 'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234',
  pubkey: 'd4e5f6789012345678901234567890abcdef123456789012345678901234a1b2c3',
  createdAt: 1700000000,
  content: 'Test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  videoUrl: 'https://example.com/video.mp4',
  textTrackContent: 'WEBVTT\n\n1\n00:00:00.100 --> 00:00:01.000\nHello there\n',
);

void main() {
  testWidgets(
    'renders the active subtitle cue from a video player controller',
    (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = _FakeVideoPlayerController()
        ..simulateInitialized(position: const Duration(milliseconds: 300));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 640,
                  child: VideoPlayerSubtitleLayer(
                    video: _makeVideo(),
                    controller: controller,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Hello there'), findsOneWidget);
    },
  );
}

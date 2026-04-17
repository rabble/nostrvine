import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart'
    as video_platform;

class FakeVideoPlayerController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  FakeVideoPlayerController({
    this.source = 'https://example.com/test.mp4',
    this.initialValue = const VideoPlayerValue(duration: Duration.zero),
  }) : super(initialValue);

  final String source;
  final VideoPlayerValue initialValue;

  void emitValue(VideoPlayerValue newValue) {
    value = newValue;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {
    value = value.copyWith(
      duration: const Duration(seconds: 6),
      isInitialized: true,
      size: const Size(1080, 1920),
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
  String get dataSource => source;

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

class FakeVideoPlayerPlatform extends video_platform.VideoPlayerPlatform {
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

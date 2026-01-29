import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

// ============================================
// Mock Classes
// ============================================

/// Mock for media_kit Player.
class MockPlayer extends Mock implements Player {}

/// Mock for media_kit_video VideoController.
class MockVideoController extends Mock implements VideoController {}

/// Mock for PlayerStream.
class MockPlayerStream extends Mock implements PlayerStream {}

/// Mock for PlayerState.
class MockPlayerState extends Mock implements PlayerState {}

/// Mock for PlayerPool.
class MockPlayerPool extends Mock implements PlayerPool {}

/// Mock for DeviceMemoryUtil.
class MockDeviceMemoryUtil extends Mock implements DeviceMemoryUtil {}

/// Mock for VideoFeedController.
class MockVideoFeedController extends Mock implements VideoFeedController {}

// ============================================
// Fake Classes (for fallback values)
// ============================================

/// Fake for PooledPlayer.
class FakePooledPlayer extends Fake implements PooledPlayer {}

/// Fake for Media.
class FakeMedia extends Fake implements Media {}

/// Fake for PlayerLease.
class FakePlayerLease extends Fake implements PlayerLease {}

/// Fake for VideoPoolConfig.
class FakeVideoPoolConfig extends Fake implements VideoPoolConfig {}

// ============================================
// Test Data Helpers
// ============================================

/// Creates a list of test videos.
List<VideoItem> createTestVideos(int count) {
  return List.generate(
    count,
    (i) => VideoItem(
      id: 'video-$i',
      url: 'https://example.com/video$i.mp4',
      title: 'Test Video $i',
      description: 'Description for video $i',
      thumbnailUrl: 'https://example.com/thumb$i.jpg',
    ),
  );
}

/// Creates a single test video with custom properties.
VideoItem createTestVideo({
  String id = 'test-video',
  String url = 'https://example.com/test.mp4',
  String? title,
  String? description,
  String? thumbnailUrl,
}) {
  return VideoItem(
    id: id,
    url: url,
    title: title,
    description: description,
    thumbnailUrl: thumbnailUrl,
  );
}

// ============================================
// Mock Setup Helpers
// ============================================

/// Registers all fallback values for mocktail.
void registerTestFallbackValues() {
  registerFallbackValue(FakePooledPlayer());
  registerFallbackValue(FakeMedia());
  registerFallbackValue(FakePlayerLease());
  registerFallbackValue(FakeVideoPoolConfig());
  registerFallbackValue(Media('https://example.com/video.mp4'));
  registerFallbackValue(PlaylistMode.single);
  registerFallbackValue(Duration.zero);
}

/// Creates a mock PooledPlayer with stubbed player and video controller.
PooledPlayer createMockPooledPlayer({
  MockPlayer? player,
  MockVideoController? videoController,
}) {
  final mockPlayer = player ?? MockPlayer();
  final mockVideoController = videoController ?? MockVideoController();

  // Stub common player methods
  when(mockPlayer.stop).thenAnswer((_) async {});
  when(mockPlayer.play).thenAnswer((_) async {});
  when(mockPlayer.pause).thenAnswer((_) async {});
  when(mockPlayer.dispose).thenAnswer((_) async {});
  when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
  when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});
  when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
  when(
    () => mockPlayer.open(any(), play: any(named: 'play')),
  ).thenAnswer((_) async {});
  when(() => mockPlayer.setPlaylistMode(any())).thenAnswer((_) async {});

  // Stub stream and state properties
  final mockStream = MockPlayerStream();
  final mockState = MockPlayerState();

  when(() => mockStream.buffering).thenAnswer((_) => const Stream.empty());
  when(() => mockStream.position).thenAnswer((_) => const Stream.empty());
  when(() => mockStream.playing).thenAnswer((_) => const Stream.empty());

  when(() => mockState.buffering).thenReturn(false);
  when(() => mockState.playing).thenReturn(false);
  when(() => mockState.position).thenReturn(Duration.zero);
  when(() => mockState.duration).thenReturn(const Duration(seconds: 10));
  when(() => mockState.buffer).thenReturn(Duration.zero);

  when(() => mockPlayer.stream).thenReturn(mockStream);
  when(() => mockPlayer.state).thenReturn(mockState);

  return PooledPlayer(
    player: mockPlayer,
    videoController: mockVideoController,
  );
}

/// Creates a mock PlayerPool with stubbed methods.
///
/// This factory is compatible with PlayerPoolManager.initialize's
/// playerPoolFactory parameter.
PlayerPool createMockPlayerPool(VideoPoolConfig config) {
  final mockPool = MockPlayerPool();
  final mockPooledPlayer = createMockPooledPlayer();

  when(() => mockPool.prewarm(any())).thenAnswer((_) async {});
  when(mockPool.dispose).thenAnswer((_) async {});
  when(() => mockPool.shrinkTo(any())).thenAnswer((_) async {});
  when(mockPool.acquire).thenAnswer((_) async => mockPooledPlayer);
  when(() => mockPool.release(any())).thenAnswer((_) async {});
  when(() => mockPool.updatePoolSize(any())).thenAnswer((_) async {});

  when(() => mockPool.maxPoolSize).thenReturn(config.poolSize);
  when(() => mockPool.maxTotalPlayers).thenReturn(config.maxActivePlayers);
  when(() => mockPool.availableCount).thenReturn(0);
  when(() => mockPool.inUseCount).thenReturn(0);
  when(() => mockPool.totalPlayers).thenReturn(0);

  return mockPool;
}

// ============================================
// PlayerPoolManager Test Helpers
// ============================================

/// Initializes PlayerPoolManager for testing with mocked dependencies.
///
/// Uses mock DeviceMemoryUtil and PlayerPoolFactory to avoid native FFI issues.
Future<PlayerPoolManager> initializeTestPoolManager({
  MemoryTier tier = MemoryTier.medium,
  VideoPoolConfig? customConfig,
  PlayerPool Function(VideoPoolConfig)? playerPoolFactory,
}) async {
  final mockMemoryClassifier = MockDeviceMemoryUtil();
  when(mockMemoryClassifier.getMemoryTier).thenAnswer((_) async => tier);

  return PlayerPoolManager.initialize(
    memoryClassifier: mockMemoryClassifier,
    playerPoolFactory: playerPoolFactory ?? createMockPlayerPool,
    skipMediaKitInit: true,
    poolSize: customConfig?.poolSize,
    preloadAhead: customConfig?.preloadAhead,
    preloadBehind: customConfig?.preloadBehind,
    maxActivePlayers: customConfig?.maxActivePlayers,
  );
}

/// Cleans up PlayerPoolManager after testing.
Future<void> cleanupPoolManager() async {
  if (PlayerPoolManager.isInitialized) {
    await PlayerPoolManager.reset();
  }
}

// ============================================
// Test Exception Classes
// ============================================

/// Test class for creating VideoPlayerExceptions for testing.
class TestVideoPlayerException extends VideoPlayerException {
  const TestVideoPlayerException(super.message, [super.cause]);
}

// ============================================
// Concrete MemoryPressureHandler for Testing
// ============================================

/// Concrete implementation of MemoryPressureHandler for testing.
class TestableMemoryPressureHandler extends ChangeNotifier
    with MemoryPressureHandler {
  TestableMemoryPressureHandler() {
    initMemoryPressureHandling();
  }

  int memoryPressureCallCount = 0;

  @override
  void onMemoryPressure() {
    memoryPressureCallCount++;
  }

  @override
  void dispose() {
    disposeMemoryPressureHandling();
    super.dispose();
  }
}

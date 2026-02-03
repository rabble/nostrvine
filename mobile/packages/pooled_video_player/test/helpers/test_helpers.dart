import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import 'mocks.dart';

// ============================================
// FIXTURES
// ============================================

/// Creates a list of test VideoItems.
List<VideoItem> createTestVideos({int count = 5}) {
  return List.generate(
    count,
    (i) => VideoItem(
      id: 'video_$i',
      url: 'https://example.com/video_$i.mp4',
      title: 'Video $i',
      description: 'Description for video $i',
      thumbnailUrl: 'https://example.com/thumb_$i.jpg',
    ),
  );
}

/// Creates a single test VideoItem.
VideoItem createTestVideo({
  String id = 'test_video',
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
// MOCK PLAYER SETUP
// ============================================

/// Result of creating a mock player with all dependencies.
class MockPlayerSetup {
  MockPlayerSetup({
    required this.player,
    required this.state,
    required this.stream,
    required this.bufferingController,
    required this.playingController,
    required this.positionController,
  });

  final MockPlayer player;
  final MockPlayerState state;
  final MockPlayerStream stream;
  final StreamController<bool> bufferingController;
  final StreamController<bool> playingController;
  final StreamController<Duration> positionController;

  /// Dispose all stream controllers.
  Future<void> dispose() async {
    await bufferingController.close();
    await playingController.close();
    await positionController.close();
  }
}

/// Creates a fully configured MockPlayer with streams.
MockPlayerSetup createMockPlayerSetup({
  bool isPlaying = false,
  bool isBuffering = false,
  Duration position = Duration.zero,
}) {
  final mockPlayer = MockPlayer();
  final mockState = MockPlayerState();
  final mockStream = MockPlayerStream();

  // Stream controllers for async behavior
  final bufferingController = StreamController<bool>.broadcast();
  final playingController = StreamController<bool>.broadcast();
  final positionController = StreamController<Duration>.broadcast();

  // Set up state
  when(() => mockState.playing).thenReturn(isPlaying);
  when(() => mockState.buffering).thenReturn(isBuffering);
  when(() => mockState.position).thenReturn(position);
  when(() => mockPlayer.state).thenReturn(mockState);

  // Set up streams
  when(
    () => mockStream.buffering,
  ).thenAnswer((_) => bufferingController.stream);
  when(() => mockStream.playing).thenAnswer((_) => playingController.stream);
  when(() => mockStream.position).thenAnswer((_) => positionController.stream);
  when(() => mockPlayer.stream).thenReturn(mockStream);

  // Set up common methods
  when(
    () => mockPlayer.open(any(), play: any(named: 'play')),
  ).thenAnswer((_) async {});
  when(mockPlayer.play).thenAnswer((_) async {});
  when(mockPlayer.pause).thenAnswer((_) async {});
  when(mockPlayer.stop).thenAnswer((_) async {});
  when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
  when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
  when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});
  when(() => mockPlayer.setPlaylistMode(any())).thenAnswer((_) async {});
  when(mockPlayer.dispose).thenAnswer((_) async {});

  return MockPlayerSetup(
    player: mockPlayer,
    state: mockState,
    stream: mockStream,
    bufferingController: bufferingController,
    playingController: playingController,
    positionController: positionController,
  );
}

/// Creates a simple MockPlayer without stream controllers.
MockPlayer createMockPlayer({
  bool isPlaying = false,
  bool isBuffering = false,
}) {
  final setup = createMockPlayerSetup(
    isPlaying: isPlaying,
    isBuffering: isBuffering,
  );
  return setup.player;
}

/// Creates a MockVideoController.
MockVideoController createMockVideoController() {
  return MockVideoController();
}

/// Creates a MockPooledPlayer with configured player and controller.
MockPooledPlayer createMockPooledPlayer({
  bool isDisposed = false,
  bool isPlaying = false,
  bool isBuffering = false,
  MockPlayer? player,
  MockVideoController? videoController,
}) {
  final mockPooledPlayer = MockPooledPlayer();
  final mockPlayer =
      player ??
      createMockPlayer(
        isPlaying: isPlaying,
        isBuffering: isBuffering,
      );
  final mockController = videoController ?? createMockVideoController();

  when(() => mockPooledPlayer.player).thenReturn(mockPlayer);
  when(() => mockPooledPlayer.videoController).thenReturn(mockController);
  when(() => mockPooledPlayer.isDisposed).thenReturn(isDisposed);
  when(mockPooledPlayer.dispose).thenAnswer((_) async {});

  return mockPooledPlayer;
}

/// Creates a MockPlayerPool.
MockPlayerPool createMockPlayerPool({int maxPlayers = 5}) {
  final mockPool = MockPlayerPool();

  when(() => mockPool.maxPlayers).thenReturn(maxPlayers);
  when(() => mockPool.playerCount).thenReturn(0);
  when(() => mockPool.hasPlayer(any())).thenReturn(false);
  when(() => mockPool.getExistingPlayer(any())).thenReturn(null);
  when(() => mockPool.release(any())).thenAnswer((_) async {});
  when(mockPool.dispose).thenAnswer((_) async {});

  return mockPool;
}

/// Creates a MockVideoFeedController.
MockVideoFeedController createMockVideoFeedController({
  List<VideoItem>? videos,
  int currentIndex = 0,
  bool isPaused = false,
  bool isActive = true,
}) {
  final mockController = MockVideoFeedController();
  final videoList = videos ?? createTestVideos();

  when(() => mockController.videos).thenReturn(videoList);
  when(() => mockController.videoCount).thenReturn(videoList.length);
  when(() => mockController.currentIndex).thenReturn(currentIndex);
  when(() => mockController.isPaused).thenReturn(isPaused);
  when(() => mockController.isActive).thenReturn(isActive);
  when(() => mockController.getVideoController(any())).thenReturn(null);
  when(() => mockController.getPlayer(any())).thenReturn(null);
  when(() => mockController.getLoadState(any())).thenReturn(LoadState.none);
  when(() => mockController.isVideoReady(any())).thenReturn(false);
  when(() => mockController.onPageChanged(any())).thenReturn(null);
  when(mockController.play).thenReturn(null);
  when(mockController.pause).thenReturn(null);
  when(mockController.togglePlayPause).thenReturn(null);
  when(() => mockController.seek(any())).thenAnswer((_) async {});
  when(() => mockController.setVolume(any())).thenReturn(null);
  when(() => mockController.setPlaybackSpeed(any())).thenReturn(null);
  when(
    () => mockController.setActive(active: any(named: 'active')),
  ).thenReturn(null);
  when(() => mockController.addVideos(any())).thenReturn(null);
  when(() => mockController.addListener(any())).thenReturn(null);
  when(() => mockController.removeListener(any())).thenReturn(null);
  when(mockController.dispose).thenReturn(null);

  return mockController;
}

// ============================================
// WIDGET TEST HELPERS
// ============================================

/// Wraps a widget with MaterialApp for testing.
Widget wrapWithMaterialApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Wraps a widget with MaterialApp and VideoPoolProvider.
Widget wrapWithProvider({
  required Widget child,
  PlayerPool? pool,
  VideoFeedController? feedController,
}) {
  return MaterialApp(
    home: Scaffold(
      body: VideoPoolProvider(
        pool: pool,
        feedController: feedController,
        child: child,
      ),
    ),
  );
}

// ============================================
// TESTABLE PLAYER POOL
// ============================================

/// A testable PlayerPool that uses mock player creation.
class TestablePlayerPool extends PlayerPool {
  TestablePlayerPool({
    required this.mockPlayerFactory,
    super.maxPlayers,
  });

  /// Factory function to create mock PooledPlayers.
  final PooledPlayer Function(String url) mockPlayerFactory;

  final Map<String, PooledPlayer> _testPlayers = {};
  final List<String> _testLruOrder = [];

  @override
  Future<PooledPlayer> getPlayer(String url) async {
    if (_testPlayers.containsKey(url)) {
      _testLruOrder
        ..remove(url)
        ..add(url);
      return _testPlayers[url]!;
    }

    // Evict if at capacity
    while (_testPlayers.length >= maxPlayers && _testLruOrder.isNotEmpty) {
      final evictUrl = _testLruOrder.removeAt(0);
      final evicted = _testPlayers.remove(evictUrl);
      if (evicted != null && !evicted.isDisposed) {
        await evicted.dispose();
      }
    }

    final player = mockPlayerFactory(url);
    _testPlayers[url] = player;
    _testLruOrder.add(url);
    return player;
  }

  @override
  bool hasPlayer(String url) => _testPlayers.containsKey(url);

  @override
  PooledPlayer? getExistingPlayer(String url) {
    if (_testPlayers.containsKey(url)) {
      _testLruOrder
        ..remove(url)
        ..add(url);
      return _testPlayers[url];
    }
    return null;
  }

  @override
  int get playerCount => _testPlayers.length;

  @override
  Future<void> release(String url) async {
    final player = _testPlayers.remove(url);
    _testLruOrder.remove(url);
    if (player != null && !player.isDisposed) {
      await player.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    for (final player in _testPlayers.values) {
      if (!player.isDisposed) {
        await player.dispose();
      }
    }
    _testPlayers.clear();
    _testLruOrder.clear();
  }
}

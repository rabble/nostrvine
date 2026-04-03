// ABOUTME: Test helpers and fixtures for pooled_video_player tests
// ABOUTME: Provides factories for VideoItem, controllers, and widget wrappers

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

// ---------------------------------------------------------------------------
// Private Mock Classes
// ---------------------------------------------------------------------------

class _MockDivineVideoPlayerController extends Mock
    implements DivineVideoPlayerController {}

class _MockPlayerPool extends Mock implements PlayerPool {}

class _MockVideoFeedController extends Mock implements VideoFeedController {}

class _MockPooledPlayer extends Mock implements PooledPlayer {}

// ---------------------------------------------------------------------------
// Video Item Fixtures
// ---------------------------------------------------------------------------

/// Creates a list of test [VideoItem]s with sequential IDs.
List<VideoItem> createTestVideos({int count = 5}) {
  return List.generate(
    count,
    (i) => VideoItem(
      id: 'video_$i',
      url: 'https://example.com/video_$i.mp4',
    ),
  );
}

/// Creates a single test [VideoItem] with configurable properties.
VideoItem createTestVideo({
  String id = 'test_video',
  String url = 'https://example.com/test.mp4',
}) {
  return VideoItem(id: id, url: url);
}

/// Creates a list of HLS test [VideoItem]s with .m3u8 URLs.
///
/// Simulates Divine video streaming URLs for testing HLS support.
List<VideoItem> createHlsTestVideos({int count = 5}) {
  return List.generate(
    count,
    (i) => VideoItem(
      id: 'hls_video_$i',
      url: 'https://media.divine.video/hash$i/hls/master.m3u8',
    ),
  );
}

/// Creates a single HLS test [VideoItem] with .m3u8 URL.
VideoItem createHlsTestVideo({
  String id = 'hls_video',
  String hash = 'abc123',
  String quality = 'master',
}) {
  return VideoItem(
    id: id,
    url: 'https://media.divine.video/$hash/hls/$quality.m3u8',
  );
}

// ---------------------------------------------------------------------------
// Mock Controller Setup
// ---------------------------------------------------------------------------

/// Container for a fully configured mock controller with all dependencies.
///
/// Provides access to a stream controller for simulating async state updates.
class MockControllerSetup {
  MockControllerSetup({
    required this.controller,
    required this.stateController,
    required DivineVideoPlayerState initialState,
  }) : _currentState = initialState;

  final DivineVideoPlayerController controller;
  final StreamController<DivineVideoPlayerState> stateController;
  DivineVideoPlayerState _currentState;

  /// Emits a new state and updates the mock's `.state` return value.
  void emitState(DivineVideoPlayerState newState) {
    _currentState = newState;
    when(() => controller.state).thenReturn(_currentState);
    stateController.add(newState);
  }

  /// Disposes the stream controller.
  Future<void> dispose() async {
    await stateController.close();
  }
}

/// Creates a fully configured [MockControllerSetup] with stateStream.
///
/// Use [isPlaying], [isBuffering], [position], and [duration] to set
/// initial state.
MockControllerSetup createMockControllerSetup({
  bool isPlaying = false,
  bool isBuffering = false,
  Duration position = Duration.zero,
  Duration duration = Duration.zero,
}) {
  final mockController = _MockDivineVideoPlayerController();
  final stateController = StreamController<DivineVideoPlayerState>.broadcast();

  final initialState = DivineVideoPlayerState(
    status: isPlaying
        ? PlaybackStatus.playing
        : isBuffering
        ? PlaybackStatus.buffering
        : PlaybackStatus.idle,
    position: position,
    duration: duration,
  );

  when(() => mockController.state).thenReturn(initialState);
  when(
    () => mockController.stateStream,
  ).thenAnswer((_) => stateController.stream);
  when(
    () => mockController.firstFrameRendered,
  ).thenAnswer((_) => Future<bool>.value(true));
  when(() => mockController.isInitialized).thenReturn(true);

  // Configure common methods.
  // setSource must emit a state on stateStream so that _openWithFallbacks
  // (which awaits the first meaningful status) can proceed.
  // The emission is deferred via Timer.run so that it fires AFTER the
  // caller subscribes to stateStream.first (broadcast streams don't
  // buffer events emitted before subscription).
  when(() => mockController.setSource(any())).thenAnswer((_) async {
    Timer.run(() {
      if (stateController.isClosed) return;
      final next = DivineVideoPlayerState(
        status: PlaybackStatus.buffering,
        position: position,
        duration: duration,
      );
      when(() => mockController.state).thenReturn(next);
      stateController.add(next);
    });
  });
  when(() => mockController.setClips(any())).thenAnswer((_) async {});
  when(mockController.play).thenAnswer((_) async {});
  when(mockController.pause).thenAnswer((_) async {});
  when(mockController.stop).thenAnswer((_) async {});
  when(() => mockController.seekTo(any())).thenAnswer((_) async {});
  when(() => mockController.setVolume(any())).thenAnswer((_) async {});
  when(
    () => mockController.setPlaybackSpeed(any()),
  ).thenAnswer((_) async {});
  when(
    () => mockController.setLooping(looping: any(named: 'looping')),
  ).thenAnswer((_) async {});
  when(mockController.dispose).thenAnswer((_) async {});

  return MockControllerSetup(
    controller: mockController,
    stateController: stateController,
    initialState: initialState,
  );
}

/// Creates a simple mock [DivineVideoPlayerController] without stream
/// controllers.
///
/// For tests that don't need stream simulation, use this instead of
/// [createMockControllerSetup].
DivineVideoPlayerController createMockController({
  bool isPlaying = false,
  bool isBuffering = false,
}) {
  final setup = createMockControllerSetup(
    isPlaying: isPlaying,
    isBuffering: isBuffering,
  );
  return setup.controller;
}

/// Creates a mock [PooledPlayer] with configured controller.
PooledPlayer createMockPooledPlayer({
  bool isDisposed = false,
  bool isPlaying = false,
  bool isBuffering = false,
  DivineVideoPlayerController? controller,
}) {
  final mockPooledPlayer = _MockPooledPlayer();
  final mockController =
      controller ??
      createMockController(
        isPlaying: isPlaying,
        isBuffering: isBuffering,
      );

  when(() => mockPooledPlayer.controller).thenReturn(mockController);
  when(() => mockPooledPlayer.isDisposed).thenReturn(isDisposed);
  when(() => mockPooledPlayer.wasRecycled).thenReturn(false);
  when(mockPooledPlayer.clearRecycled).thenReturn(null);
  when(mockPooledPlayer.recycle).thenReturn(null);
  when(mockPooledPlayer.dispose).thenAnswer((_) async {});

  return mockPooledPlayer;
}

/// Creates a mock [PooledPlayer] from an existing [MockControllerSetup].
///
/// Wires up `addOnEvictedCallback`, `recycle`, and `dispose` so eviction
/// callbacks fire correctly (matching real [PooledPlayer] behaviour).
PooledPlayer createMockPooledPlayerFromSetup(MockControllerSetup setup) {
  final mockPooledPlayer = _MockPooledPlayer();
  final callbacks = <VoidCallback>[];

  var recycled = false;

  when(() => mockPooledPlayer.controller).thenReturn(setup.controller);
  when(() => mockPooledPlayer.isDisposed).thenReturn(false);
  when(() => mockPooledPlayer.wasRecycled).thenAnswer((_) => recycled);
  when(mockPooledPlayer.clearRecycled).thenAnswer((_) => recycled = false);
  when(() => mockPooledPlayer.addOnEvictedCallback(any())).thenAnswer((inv) {
    callbacks.add(inv.positionalArguments.first as VoidCallback);
  });
  when(() => mockPooledPlayer.removeOnEvictedCallback(any())).thenAnswer((
    inv,
  ) {
    callbacks.remove(inv.positionalArguments.first as VoidCallback);
  });
  when(mockPooledPlayer.recycle).thenAnswer((_) {
    recycled = true;
    for (final cb in List<VoidCallback>.of(callbacks)) {
      cb();
    }
    callbacks.clear();
  });
  when(mockPooledPlayer.dispose).thenAnswer((_) async {
    for (final cb in List<VoidCallback>.of(callbacks)) {
      cb();
    }
    callbacks.clear();
  });

  return mockPooledPlayer;
}

/// Creates a mock [PlayerPool] with default stubs.
PlayerPool createMockPlayerPool({int maxPlayers = 5}) {
  final mockPool = _MockPlayerPool();

  when(() => mockPool.maxPlayers).thenReturn(maxPlayers);
  when(() => mockPool.playerCount).thenReturn(0);
  when(() => mockPool.hasPlayer(any())).thenReturn(false);
  when(() => mockPool.getExistingPlayer(any())).thenReturn(null);
  when(() => mockPool.release(any())).thenAnswer((_) async {});
  when(mockPool.dispose).thenAnswer((_) async {});

  return mockPool;
}

/// Creates a mock [VideoFeedController] with configurable state.
VideoFeedController createMockVideoFeedController({
  List<VideoItem>? videos,
  int currentIndex = 0,
  bool isPaused = false,
  bool isActive = true,
}) {
  final mockController = _MockVideoFeedController();
  final videoList = videos ?? createTestVideos();

  when(() => mockController.videos).thenReturn(videoList);
  when(() => mockController.videoCount).thenReturn(videoList.length);
  when(() => mockController.currentIndex).thenReturn(currentIndex);
  when(() => mockController.isPaused).thenReturn(isPaused);
  when(() => mockController.isActive).thenReturn(isActive);
  when(() => mockController.getController(any())).thenReturn(null);
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
    () => mockController.setActive(
      active: any(named: 'active'),
      retainCurrentPlayer: any(named: 'retainCurrentPlayer'),
    ),
  ).thenReturn(null);
  when(() => mockController.addVideos(any())).thenReturn(null);
  when(() => mockController.addListener(any())).thenReturn(null);
  when(() => mockController.removeListener(any())).thenReturn(null);
  when(mockController.dispose).thenReturn(null);

  return mockController;
}

// ---------------------------------------------------------------------------
// Widget Test Helpers
// ---------------------------------------------------------------------------

/// Wraps a widget with [MaterialApp] for testing.
Widget wrapWithMaterialApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Wraps a widget with [MaterialApp] and [VideoPoolProvider].
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

// ---------------------------------------------------------------------------
// Testable Player Pool
// ---------------------------------------------------------------------------

/// A testable [PlayerPool] that uses mock player creation.
///
/// Allows tests to inject mock players and observe pool behavior.
class TestablePlayerPool extends PlayerPool {
  TestablePlayerPool({
    required this.mockPlayerFactory,
    super.maxPlayers,
  });

  /// Factory function to create mock [PooledPlayer]s.
  final PooledPlayer Function(String url) mockPlayerFactory;

  final Map<String, PooledPlayer> _testPlayers = {};
  final List<String> _testLruOrder = [];

  @override
  Future<PooledPlayer> getPlayer(String url) async {
    if (_testPlayers.containsKey(url)) {
      _testLruOrder
        ..remove(url)
        ..add(url);
      // Mirror real PlayerPool: mute cached players to prevent audio leaks.
      // The caller (_loadPlayer) will set volume/play state as needed.
      final existing = _testPlayers[url]!;
      unawaited(existing.controller.setVolume(0));
      return existing;
    }

    // Recycle LRU players until there is room, mirroring real PlayerPool.
    PooledPlayer? recycled;
    while (_testPlayers.length >= maxPlayers && _testLruOrder.isNotEmpty) {
      final evictUrl = _testLruOrder.removeAt(0);
      final evicted = _testPlayers.remove(evictUrl);
      if (evicted != null && !evicted.isDisposed) {
        evicted.recycle();
        // Mirror real PlayerPool._recycleLru(): await stop() so the surface
        // is cleared before the recycled player is exposed to the UI.
        await evicted.controller.stop();
        recycled = evicted;
        break;
      }
    }

    if (recycled != null) {
      _testPlayers[url] = recycled;
      _testLruOrder.add(url);
      return recycled;
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
  void stopAll() {
    for (final player in _testPlayers.values) {
      if (!player.isDisposed) {
        try {
          unawaited(player.controller.stop());
        } on Exception {
          // Ignore errors during emergency stop
        }
      }
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

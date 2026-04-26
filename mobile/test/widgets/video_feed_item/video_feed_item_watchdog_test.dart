// ABOUTME: Tests for the playback watchdog logic in VideoFeedItem
// ABOUTME: Verifies auto-resume from native pauses and safety guards
//
// These tests exercise the watchdog logic directly against
// VideoPlayerController listeners, without needing the full
// VideoFeedItem widget tree (which requires the entire provider
// graph). The production code installs the same listener via
// _installPlaybackWatchdog().

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

/// Fake VideoPlayerController that lets us simulate native-level
/// state changes (pause, buffer, error) via [value] mutations.
class _FakeController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  _FakeController() : super(const VideoPlayerValue(duration: Duration.zero));

  int playCallCount = 0;
  int pauseCallCount = 0;

  @override
  Future<void> play() async {
    playCallCount++;
    value = value.copyWith(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pauseCallCount++;
    value = value.copyWith(isPlaying: false);
  }

  void simulateInitialized({bool isPlaying = false}) {
    value = VideoPlayerValue(
      duration: const Duration(seconds: 6),
      isInitialized: true,
      isPlaying: isPlaying,
      size: const Size(1920, 1080),
    );
  }

  void simulateNativePause() {
    value = value.copyWith(isPlaying: false);
  }

  void simulateBuffering() {
    value = value.copyWith(isPlaying: false, isBuffering: true);
  }

  void simulateError() {
    value = VideoPlayerValue(
      duration: value.duration,
      isInitialized: value.isInitialized,
      size: value.size,
      errorDescription: 'Test error',
    );
  }

  // -- Minimal VideoPlayerController interface --

  @override
  Future<void> initialize() async => simulateInitialized();

  @override
  Future<void> dispose() async => super.dispose();

  @override
  Future<void> seekTo(Duration position) async =>
      value = value.copyWith(position: position);

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

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
  Map<String, String> get httpHeaders => {};

  @override
  Future<ClosedCaptionFile>? get closedCaptionFile => null;

  @override
  VideoPlayerOptions? get videoPlayerOptions => null;
}

/// Mirrors the watchdog logic from _VideoFeedItemState.
///
/// Installs a listener that calls [onResume] when the controller
/// stops playing unexpectedly, subject to the [shouldResume] guard.
///
/// Returns a teardown function that removes the listener.
VoidCallback _installTestWatchdog(
  _FakeController controller, {
  required VoidCallback onResume,
  required bool Function() shouldResume,
}) {
  void watchdog() {
    final v = controller.value;
    if (!shouldResume()) return;
    if (v.isPlaying) return;
    if (!v.isInitialized) return;
    if (v.isBuffering) return;
    if (v.hasError) return;
    onResume();
  }

  controller.addListener(watchdog);
  return () => controller.removeListener(watchdog);
}

void main() {
  late _FakeController controller;

  setUp(() {
    controller = _FakeController();
  });

  tearDown(() {
    try {
      controller.dispose();
    } catch (_) {}
  });

  group('Playback watchdog', () {
    test('auto-resumes when native player pauses unexpectedly', () {
      controller.simulateInitialized(isPlaying: true);

      var resumeCount = 0;
      _installTestWatchdog(
        controller,
        onResume: () => resumeCount++,
        shouldResume: () => true,
      );

      // Simulate native player stopping unexpectedly
      controller.simulateNativePause();

      expect(
        resumeCount,
        equals(1),
        reason:
            'Watchdog should trigger resume when native '
            'player stops unexpectedly',
      );
    });

    test('does not resume when shouldResume returns false', () {
      controller.simulateInitialized(isPlaying: true);

      var resumeCount = 0;
      // shouldResume=false simulates: user paused, video not
      // active, overlay visible, or widget disposed
      _installTestWatchdog(
        controller,
        onResume: () => resumeCount++,
        shouldResume: () => false,
      );

      controller.simulateNativePause();

      expect(
        resumeCount,
        equals(0),
        reason:
            'Watchdog should not resume when guard returns '
            'false',
      );
    });

    test('does not resume while buffering', () {
      controller.simulateInitialized(isPlaying: true);

      var resumeCount = 0;
      _installTestWatchdog(
        controller,
        onResume: () => resumeCount++,
        shouldResume: () => true,
      );

      controller.simulateBuffering();

      expect(
        resumeCount,
        equals(0),
        reason:
            'Watchdog should not resume during buffering '
            '(player will resume automatically)',
      );
    });

    test('does not resume when controller has error', () {
      controller.simulateInitialized(isPlaying: true);

      var resumeCount = 0;
      _installTestWatchdog(
        controller,
        onResume: () => resumeCount++,
        shouldResume: () => true,
      );

      controller.simulateError();

      expect(
        resumeCount,
        equals(0),
        reason:
            'Watchdog should not resume when controller has '
            'error',
      );
    });

    test('does not resume when controller is not initialized', () {
      // Controller starts uninitialized
      var resumeCount = 0;
      _installTestWatchdog(
        controller,
        onResume: () => resumeCount++,
        shouldResume: () => true,
      );

      // Trigger a listener notification while uninitialized
      controller.value = const VideoPlayerValue(duration: Duration.zero);

      expect(
        resumeCount,
        equals(0),
        reason:
            'Watchdog should not resume when controller is '
            'not initialized',
      );
    });

    test('does not fire when video is already playing', () {
      controller.simulateInitialized(isPlaying: true);

      var resumeCount = 0;
      _installTestWatchdog(
        controller,
        onResume: () => resumeCount++,
        shouldResume: () => true,
      );

      // Trigger listener without changing isPlaying
      controller.value = controller.value.copyWith(
        position: const Duration(seconds: 1),
      );

      expect(
        resumeCount,
        equals(0),
        reason:
            'Watchdog should not fire when video is already '
            'playing',
      );
    });

    test('teardown removes listener (no phantom playback)', () {
      controller.simulateInitialized(isPlaying: true);

      var resumeCount = 0;
      final teardown = _installTestWatchdog(
        controller,
        onResume: () => resumeCount++,
        shouldResume: () => true,
      );

      // Remove watchdog (simulates dispose or system pause)
      teardown();

      // Simulate native pause AFTER teardown
      controller.simulateNativePause();

      expect(
        resumeCount,
        equals(0),
        reason:
            'Watchdog should not fire after teardown '
            '(prevents phantom playback after navigation)',
      );
    });

    test('guard transitions from false to true allow resume', () {
      controller.simulateInitialized(isPlaying: true);

      var userPaused = true;
      var resumeCount = 0;
      _installTestWatchdog(
        controller,
        onResume: () => resumeCount++,
        shouldResume: () => !userPaused,
      );

      // First: user-paused, native pause should not resume
      controller.simulateNativePause();
      expect(resumeCount, equals(0));

      // Simulate system requesting play (clears user pause)
      userPaused = false;
      controller.simulateInitialized(isPlaying: true);

      // Now native pause should trigger resume
      controller.simulateNativePause();
      expect(
        resumeCount,
        equals(1),
        reason:
            'After user-pause is cleared by system play, '
            'watchdog should resume on next native pause',
      );
    });

    test('multiple rapid native pauses only resume each time', () {
      controller.simulateInitialized(isPlaying: true);

      var resumeCount = 0;
      _installTestWatchdog(
        controller,
        onResume: () {
          resumeCount++;
          // Simulate the resume restoring isPlaying
          controller.value = controller.value.copyWith(isPlaying: true);
        },
        shouldResume: () => true,
      );

      // Three rapid native pauses
      controller.simulateNativePause();
      controller.simulateNativePause();
      controller.simulateNativePause();

      expect(
        resumeCount,
        equals(3),
        reason:
            'Each native pause should trigger exactly one '
            'resume attempt',
      );
    });
  });
}

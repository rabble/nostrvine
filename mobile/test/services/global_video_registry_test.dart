// ABOUTME: Test suite for GlobalVideoRegistry singleton that manages all video controllers
// ABOUTME: Ensures centralized control of video playback across the entire app

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/services/global_video_registry.dart';

// Simple test double for VideoPlayerController
class TestVideoController {
  bool isPlaying;
  bool isInitialized;
  bool isDisposed;
  bool pauseCalled = false;
  
  TestVideoController({
    this.isPlaying = false,
    this.isInitialized = true,
    this.isDisposed = false,
  });
  
  void pause() {
    pauseCalled = true;
    isPlaying = false;
  }
  
  void play() {
    isPlaying = true;
  }
  
  void dispose() {
    isDisposed = true;
  }
}

void main() {
  group('GlobalVideoRegistry', () {
    late GlobalVideoRegistry registry;

    setUp(() {
      // Reset singleton state before each test
      GlobalVideoRegistry.resetForTesting();
      registry = GlobalVideoRegistry();
    });

    test('should be a singleton', () {
      final registry1 = GlobalVideoRegistry();
      final registry2 = GlobalVideoRegistry();
      
      expect(identical(registry1, registry2), isTrue);
    });

    test('should track registered controllers count', () {
      expect(registry.activeControllerCount, equals(0));
    });

    test('should provide debug info', () {
      final debugInfo = registry.getDebugInfo();
      
      expect(debugInfo['totalControllers'], equals(0));
      expect(debugInfo['playingControllers'], equals(0));
      expect(debugInfo['pausedControllers'], equals(0));
    });

    test('should handle cleanup of disposed controllers', () {
      // This test verifies the cleanup method exists and can be called
      expect(() => registry.cleanupDisposedControllers(), returnsNormally);
    });
  });
}
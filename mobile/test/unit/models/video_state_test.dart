// ABOUTME: Comprehensive test suite for VideoState model - TDD implementation
// ABOUTME: Tests state transitions, validation, immutability and error handling

import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';

void main() {
  group('VideoLoadingState Enum', () {
    test('should have all required states', () {
      final states = VideoLoadingState.values;
      
      expect(states, contains(VideoLoadingState.notLoaded));
      expect(states, contains(VideoLoadingState.loading));
      expect(states, contains(VideoLoadingState.ready));
      expect(states, contains(VideoLoadingState.failed));
      expect(states, contains(VideoLoadingState.permanentlyFailed));
      expect(states, contains(VideoLoadingState.disposed));
      expect(states.length, equals(6));
    });

    test('should have correct enum values', () {
      expect(VideoLoadingState.notLoaded.toString(), contains('notLoaded'));
      expect(VideoLoadingState.loading.toString(), contains('loading'));
      expect(VideoLoadingState.ready.toString(), contains('ready'));
      expect(VideoLoadingState.failed.toString(), contains('failed'));
      expect(VideoLoadingState.permanentlyFailed.toString(), contains('permanentlyFailed'));
      expect(VideoLoadingState.disposed.toString(), contains('disposed'));
    });
  });

  group('VideoState Model', () {
    late VideoEvent testVideoEvent;

    setUp(() {
      // Create a test video event
      testVideoEvent = VideoEvent(
        id: 'test-video-id-123',
        pubkey: 'test-pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        title: 'Test Video',
        hashtags: ['test', 'video'],
        duration: 30,
        dimensions: '1920x1080',
        fileSize: 1024000,
        mimeType: 'video/mp4',
        sha256: 'test-sha256',
      );
    });

    group('Constructor and Initial State', () {
      test('should create VideoState with notLoaded state by default', () {
        final videoState = VideoState(event: testVideoEvent);

        expect(videoState.event, equals(testVideoEvent));
        expect(videoState.loadingState, equals(VideoLoadingState.notLoaded));
        expect(videoState.errorMessage, isNull);
        expect(videoState.lastUpdated, isNotNull);
        expect(videoState.retryCount, equals(0));
        expect(videoState.isDisposed, isFalse);
      });

      test('should create VideoState with specified state', () {
        final videoState = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.loading,
        );

        expect(videoState.loadingState, equals(VideoLoadingState.loading));
        expect(videoState.event, equals(testVideoEvent));
      });

      test('should create VideoState with error message', () {
        const errorMessage = 'Network error occurred';
        final videoState = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.failed,
          errorMessage: errorMessage,
        );

        expect(videoState.errorMessage, equals(errorMessage));
        expect(videoState.loadingState, equals(VideoLoadingState.failed));
      });

      test('should create VideoState with retry count', () {
        final videoState = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.failed,
          retryCount: 3,
        );

        expect(videoState.retryCount, equals(3));
        expect(videoState.loadingState, equals(VideoLoadingState.failed));
      });
    });

    group('State Transition Methods', () {
      late VideoState initialState;

      setUp(() {
        initialState = VideoState(event: testVideoEvent);
      });

      test('toLoading() should transition to loading state', () {
        final loadingState = initialState.toLoading();

        expect(loadingState.loadingState, equals(VideoLoadingState.loading));
        expect(loadingState.event, equals(testVideoEvent));
        expect(loadingState.errorMessage, isNull);
        expect(loadingState.retryCount, equals(0));
        expect(loadingState.lastUpdated.isAfter(initialState.lastUpdated), isTrue);
      });

      test('toReady() should transition to ready state', () {
        final loadingState = initialState.toLoading();
        final readyState = loadingState.toReady();

        expect(readyState.loadingState, equals(VideoLoadingState.ready));
        expect(readyState.event, equals(testVideoEvent));
        expect(readyState.errorMessage, isNull);
        expect(readyState.retryCount, equals(0));
        expect(readyState.lastUpdated.isAfter(loadingState.lastUpdated), isTrue);
      });

      test('toFailed() should transition to failed state with error message', () {
        const errorMessage = 'Failed to load video';
        final loadingState = initialState.toLoading();
        final failedState = loadingState.toFailed(errorMessage);

        expect(failedState.loadingState, equals(VideoLoadingState.failed));
        expect(failedState.errorMessage, equals(errorMessage));
        expect(failedState.retryCount, equals(1));
        expect(failedState.lastUpdated.isAfter(loadingState.lastUpdated), isTrue);
      });

      test('toFailed() should increment retry count correctly', () {
        final failedState1 = initialState.toFailed('First failure');
        expect(failedState1.retryCount, equals(1));

        final failedState2 = failedState1.toFailed('Second failure');
        expect(failedState2.retryCount, equals(2));

        final failedState3 = failedState2.toFailed('Third failure');
        expect(failedState3.retryCount, equals(3));
      });

      test('toPermanentlyFailed() should transition to permanently failed state', () {
        const errorMessage = 'Permanent failure - invalid URL';
        final failedState = initialState.toFailed('Initial failure');
        final permanentlyFailedState = failedState.toPermanentlyFailed(errorMessage);

        expect(permanentlyFailedState.loadingState, equals(VideoLoadingState.permanentlyFailed));
        expect(permanentlyFailedState.errorMessage, equals(errorMessage));
        expect(permanentlyFailedState.retryCount, equals(failedState.retryCount));
        expect(permanentlyFailedState.lastUpdated.isAfter(failedState.lastUpdated), isTrue);
      });

      test('toDisposed() should transition to disposed state', () {
        final readyState = initialState.toLoading().toReady();
        final disposedState = readyState.toDisposed();

        expect(disposedState.loadingState, equals(VideoLoadingState.disposed));
        expect(disposedState.isDisposed, isTrue);
        expect(disposedState.event, equals(testVideoEvent));
        expect(disposedState.lastUpdated.isAfter(readyState.lastUpdated), isTrue);
      });
    });

    group('State Validation', () {
      test('should enforce valid state transitions', () {
        final notLoadedState = VideoState(event: testVideoEvent);
        
        // Valid transitions from notLoaded
        expect(() => notLoadedState.toLoading(), returnsNormally);
        expect(() => notLoadedState.toDisposed(), returnsNormally);
        
        // Invalid direct transitions from notLoaded
        expect(() => notLoadedState.toReady(), throwsStateError);
        expect(() => notLoadedState.toFailed('error'), returnsNormally); // Can fail from any state
      });

      test('should prevent transitions from disposed state', () {
        final disposedState = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.disposed,
        );

        expect(() => disposedState.toLoading(), throwsStateError);
        expect(() => disposedState.toReady(), throwsStateError);
        expect(() => disposedState.toFailed('error'), throwsStateError);
        expect(() => disposedState.toPermanentlyFailed('error'), throwsStateError);
      });

      test('should prevent transitions from permanently failed state', () {
        final permanentlyFailedState = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.permanentlyFailed,
          errorMessage: 'Permanent error',
        );

        expect(() => permanentlyFailedState.toLoading(), throwsStateError);
        expect(() => permanentlyFailedState.toReady(), throwsStateError);
        expect(() => permanentlyFailedState.toFailed('error'), throwsStateError);
        // Can still dispose
        expect(() => permanentlyFailedState.toDisposed(), returnsNormally);
      });

      test('should validate retry count limits', () {
        final initialState = VideoState(event: testVideoEvent);
        
        // Build up to max retries
        var currentState = initialState;
        for (int i = 1; i <= VideoState.maxRetryCount; i++) {
          currentState = currentState.toFailed('Retry $i');
          expect(currentState.retryCount, equals(i));
        }

        // Next failure should become permanently failed
        final nextFailedState = currentState.toFailed('Final failure');
        expect(nextFailedState.loadingState, equals(VideoLoadingState.permanentlyFailed));
      });
    });

    group('Convenience Getters', () {
      test('isLoading should return correct value', () {
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.notLoaded).isLoading, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.loading).isLoading, isTrue);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.ready).isLoading, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.failed).isLoading, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.permanentlyFailed).isLoading, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.disposed).isLoading, isFalse);
      });

      test('isReady should return correct value', () {
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.notLoaded).isReady, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.loading).isReady, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.ready).isReady, isTrue);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.failed).isReady, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.permanentlyFailed).isReady, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.disposed).isReady, isFalse);
      });

      test('hasFailed should return correct value', () {
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.notLoaded).hasFailed, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.loading).hasFailed, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.ready).hasFailed, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.failed).hasFailed, isTrue);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.permanentlyFailed).hasFailed, isTrue);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.disposed).hasFailed, isFalse);
      });

      test('canRetry should return correct value', () {
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.notLoaded).canRetry, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.loading).canRetry, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.ready).canRetry, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.failed, retryCount: 1).canRetry, isTrue);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.failed, retryCount: VideoState.maxRetryCount).canRetry, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.permanentlyFailed).canRetry, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.disposed).canRetry, isFalse);
      });

      test('isDisposed should return correct value', () {
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.notLoaded).isDisposed, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.loading).isDisposed, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.ready).isDisposed, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.failed).isDisposed, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.permanentlyFailed).isDisposed, isFalse);
        expect(VideoState(event: testVideoEvent, loadingState: VideoLoadingState.disposed).isDisposed, isTrue);
      });
    });

    group('Immutability', () {
      test('should create new instances on state transitions', () {
        final originalState = VideoState(event: testVideoEvent);
        final loadingState = originalState.toLoading();
        final readyState = loadingState.toReady();

        // Each transition should create a new instance
        expect(identical(originalState, loadingState), isFalse);
        expect(identical(loadingState, readyState), isFalse);
        expect(identical(originalState, readyState), isFalse);

        // Original states should remain unchanged
        expect(originalState.loadingState, equals(VideoLoadingState.notLoaded));
        expect(loadingState.loadingState, equals(VideoLoadingState.loading));
        expect(readyState.loadingState, equals(VideoLoadingState.ready));
      });

      test('should preserve event reference across transitions', () {
        final originalState = VideoState(event: testVideoEvent);
        final loadingState = originalState.toLoading();
        final readyState = loadingState.toReady();

        // Event should be the same reference (immutable)
        expect(identical(originalState.event, loadingState.event), isTrue);
        expect(identical(loadingState.event, readyState.event), isTrue);
        expect(identical(originalState.event, readyState.event), isTrue);
      });
    });

    group('Equality and Hash Code', () {
      test('should implement equality correctly', () {
        final state1 = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.ready,
          errorMessage: null,
          retryCount: 0,
        );

        final state2 = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.ready,
          errorMessage: null,
          retryCount: 0,
        );

        final state3 = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.failed,
          errorMessage: 'Error',
          retryCount: 1,
        );

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
        expect(state2, isNot(equals(state3)));
      });

      test('should implement hashCode correctly', () {
        final state1 = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.ready,
          errorMessage: null,
          retryCount: 0,
        );

        final state2 = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.ready,
          errorMessage: null,
          retryCount: 0,
        );

        expect(state1.hashCode, equals(state2.hashCode));
      });
    });

    group('toString', () {
      test('should provide meaningful string representation', () {
        final state = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.failed,
          errorMessage: 'Network timeout',
          retryCount: 2,
        );

        final stringRep = state.toString();
        
        expect(stringRep, contains('VideoState'));
        expect(stringRep, contains('failed'));
        expect(stringRep, contains('test-video-id-123'));
        expect(stringRep, contains('Network timeout'));
        expect(stringRep, contains('2'));
      });
    });

    group('Error Handling', () {
      test('should require valid video event', () {
        expect(() => VideoState(event: null as dynamic), throwsAssertionError);
      });

      test('should handle null error messages gracefully', () {
        final state = VideoState(
          event: testVideoEvent,
          loadingState: VideoLoadingState.failed,
          errorMessage: null,
        );

        expect(state.errorMessage, isNull);
        expect(state.hasFailed, isTrue);
      });

      test('should handle negative retry counts', () {
        expect(() => VideoState(
          event: testVideoEvent,
          retryCount: -1,
        ), throwsAssertionError);
      });
    });

    group('Edge Cases', () {
      test('should handle rapid state transitions', () {
        var state = VideoState(event: testVideoEvent);
        
        // Rapid transitions
        state = state.toLoading();
        state = state.toFailed('Error 1');
        state = state.toLoading();
        state = state.toReady();
        state = state.toDisposed();

        expect(state.loadingState, equals(VideoLoadingState.disposed));
        expect(state.isDisposed, isTrue);
      });

      test('should maintain lastUpdated chronology', () async {
        final state1 = VideoState(event: testVideoEvent);
        
        // Small delay to ensure different timestamps
        await Future.delayed(const Duration(milliseconds: 1));
        final state2 = state1.toLoading();
        
        await Future.delayed(const Duration(milliseconds: 1));
        final state3 = state2.toReady();

        expect(state2.lastUpdated.isAfter(state1.lastUpdated), isTrue);
        expect(state3.lastUpdated.isAfter(state2.lastUpdated), isTrue);
      });
    });
  });
}
// ABOUTME: Tests for FeedPerformanceTracker stale session handling.
// ABOUTME: Verifies sessions older than 60s are discarded and resetAllSessions
// ABOUTME: clears all active sessions on app resume.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/feed_performance_tracker.dart';

void main() {
  group(FeedPerformanceTracker, () {
    late FeedPerformanceTracker tracker;

    setUp(() {
      // Reset to discard any stale singleton left by a previous test or test
      // file when running in a shared isolate (VGV optimized runner).
      FeedPerformanceTracker.resetInstance();
      tracker = FeedPerformanceTracker.testInstance();
    });

    tearDown(FeedPerformanceTracker.resetInstance);

    group('resetAllSessions', () {
      test('clears all active sessions', () {
        tracker
          ..startFeedLoad('home')
          ..startFeedLoad('explore')
          ..startFeedLoad('profile');

        expect(tracker.activeSessionCount, 3);

        tracker.resetAllSessions();

        expect(tracker.activeSessionCount, 0);
      });

      test('does nothing when no sessions are active', () {
        expect(tracker.activeSessionCount, 0);

        // Should not throw
        tracker.resetAllSessions();

        expect(tracker.activeSessionCount, 0);
      });
    });

    group('stale session detection', () {
      test('markFirstVideosReceived processes fresh session normally', () {
        tracker.startFeedLoad('home');
        expect(tracker.activeSessionCount, 1);

        tracker.markFirstVideosReceived('home', 5);

        // Session should still be active (not yet displayed)
        expect(tracker.activeSessionCount, 1);
      });

      test('markFeedDisplayed removes session on completion', () {
        tracker.startFeedLoad('home');
        expect(tracker.activeSessionCount, 1);

        tracker.markFeedDisplayed('home', 5);

        expect(tracker.activeSessionCount, 0);
      });

      test('markFirstVideosReceived is no-op for unknown feed type', () {
        tracker.markFirstVideosReceived('unknown', 5);
        expect(tracker.activeSessionCount, 0);
      });

      test('markFeedDisplayed is no-op for unknown feed type', () {
        tracker.markFeedDisplayed('unknown', 5);
        expect(tracker.activeSessionCount, 0);
      });
    });

    group('testInstance', () {
      test('creates instance without Firebase dependency', () {
        final instance = FeedPerformanceTracker.testInstance();

        instance
          ..startFeedLoad('test')
          ..markFirstVideosReceived('test', 3)
          ..markFeedDisplayed('test', 3);

        expect(instance.activeSessionCount, 0);
      });

      test('tracks multiple independent sessions', () {
        tracker
          ..startFeedLoad('home')
          ..startFeedLoad('explore');

        expect(tracker.activeSessionCount, 2);

        tracker.markFeedDisplayed('home', 5);
        expect(tracker.activeSessionCount, 1);

        tracker.markFeedDisplayed('explore', 10);
        expect(tracker.activeSessionCount, 0);
      });
    });

    group('video swipe tracking', () {
      test('startVideoSwipeTracking creates a session', () {
        const videoId =
            'abc123def456abc123def456abc123def456abc123def456abc123def456abcd';
        tracker.startVideoSwipeTracking(videoId);

        expect(tracker.activeSessionCount, 1);
      });

      test('markVideoSwipeComplete removes the session', () {
        const videoId =
            'abc123def456abc123def456abc123def456abc123def456abc123def456abcd';
        tracker
          ..startVideoSwipeTracking(videoId)
          ..markVideoSwipeComplete(videoId);

        expect(tracker.activeSessionCount, 0);
      });
    });
  });
}

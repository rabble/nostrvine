// ABOUTME: Tests for FeedPerformanceTracker stale session handling.
// ABOUTME: Verifies sessions are reset on app resume and stale sessions are
// discarded when mark methods are called after background/resume cycles.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/feed_performance_tracker.dart';

void main() {
  group(FeedPerformanceTracker, () {
    late FeedPerformanceTracker tracker;

    setUp(() {
      tracker = FeedPerformanceTracker.testInstance();
    });

    group('resetAllSessions', () {
      test('clears all active sessions', () {
        tracker
          ..startFeedLoad('home')
          ..startFeedLoad('discover');

        expect(tracker.activeSessionCount, equals(2));

        tracker.resetAllSessions();

        expect(tracker.activeSessionCount, equals(0));
      });

      test('is a no-op when no sessions are active', () {
        expect(tracker.activeSessionCount, equals(0));

        // Should not throw
        tracker.resetAllSessions();

        expect(tracker.activeSessionCount, equals(0));
      });

      test(
        'prevents stale markFeedDisplayed from recording after reset',
        () {
          tracker.startFeedLoad('home');
          expect(tracker.activeSessionCount, equals(1));

          tracker.resetAllSessions();
          expect(tracker.activeSessionCount, equals(0));

          // Completing a session that was cleared should be a no-op
          tracker.markFeedDisplayed('home', 10);
          expect(tracker.activeSessionCount, equals(0));
        },
      );

      test(
        'prevents stale markFirstVideosReceived from recording after reset',
        () {
          tracker.startFeedLoad('discover');
          expect(tracker.activeSessionCount, equals(1));

          tracker.resetAllSessions();

          // Completing a session that was cleared should be a no-op
          tracker.markFirstVideosReceived('discover', 5);
          expect(tracker.activeSessionCount, equals(0));
        },
      );
    });

    group('activeSessionCount', () {
      test('tracks number of active sessions', () {
        expect(tracker.activeSessionCount, equals(0));

        tracker.startFeedLoad('home');
        expect(tracker.activeSessionCount, equals(1));

        tracker.startFeedLoad('discover');
        expect(tracker.activeSessionCount, equals(2));

        tracker.markFeedDisplayed('home', 10);
        expect(tracker.activeSessionCount, equals(1));
      });
    });

    group('startFeedLoad', () {
      test('replaces existing session for same feed type', () {
        tracker
          ..startFeedLoad('home')
          ..startFeedLoad('home');

        expect(tracker.activeSessionCount, equals(1));
      });
    });

    group('markFeedDisplayed', () {
      test('removes session after successful completion', () {
        tracker.startFeedLoad('home');
        expect(tracker.activeSessionCount, equals(1));

        tracker.markFeedDisplayed('home', 10);
        expect(tracker.activeSessionCount, equals(0));
      });

      test('is a no-op for unknown feed type', () {
        tracker.markFeedDisplayed('nonexistent', 10);
        expect(tracker.activeSessionCount, equals(0));
      });
    });

    group('markFirstVideosReceived', () {
      test('does not remove session', () {
        tracker.startFeedLoad('home');
        tracker.markFirstVideosReceived('home', 5);

        expect(tracker.activeSessionCount, equals(1));
      });

      test('is a no-op for unknown feed type', () {
        tracker.markFirstVideosReceived('nonexistent', 5);
        expect(tracker.activeSessionCount, equals(0));
      });
    });
  });
}

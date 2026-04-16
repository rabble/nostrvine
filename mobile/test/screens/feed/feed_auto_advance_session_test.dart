// ABOUTME: Tests the feed-scoped Auto session state transitions.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/feed/feed_auto_advance_session.dart';

void main() {
  group('FeedAutoAdvanceSession', () {
    test('fresh session starts disabled and unsuppressed', () {
      final session = FeedAutoAdvanceSession();

      expect(session.autoEnabled, isFalse);
      expect(session.autoSuppressed, isFalse);
      expect(session.isEffectivelyActive, isFalse);
    });

    test('enabling auto activates the session', () {
      final session = FeedAutoAdvanceSession();

      session.setEnabled(true);

      expect(session.autoEnabled, isTrue);
      expect(session.autoSuppressed, isFalse);
      expect(session.isEffectivelyActive, isTrue);
    });

    test(
      'non-swipe interaction suppresses enabled auto until swipe resumes it',
      () {
        final session = FeedAutoAdvanceSession()..setEnabled(true);

        session.suppressForInteraction();
        expect(session.autoSuppressed, isTrue);
        expect(session.isEffectivelyActive, isFalse);

        session.resumeAfterSwipe();
        expect(session.autoSuppressed, isFalse);
        expect(session.isEffectivelyActive, isTrue);
      },
    );

    test('disabling auto clears suppression', () {
      final session = FeedAutoAdvanceSession()
        ..setEnabled(true)
        ..suppressForInteraction();

      session.setEnabled(false);

      expect(session.autoEnabled, isFalse);
      expect(session.autoSuppressed, isFalse);
      expect(session.isEffectivelyActive, isFalse);
    });
  });
}

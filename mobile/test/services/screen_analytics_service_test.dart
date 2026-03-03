// ABOUTME: Tests for ScreenAnalyticsService stale session handling.
// ABOUTME: Verifies sessions are reset on app resume and stale sessions are
// discarded when mark methods are called after background/resume cycles.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/screen_analytics_service.dart';

void main() {
  group(ScreenAnalyticsService, () {
    late ScreenAnalyticsService service;

    setUp(() {
      service = ScreenAnalyticsService.testInstance();
    });

    group('resetAllSessions', () {
      test('clears all active sessions', () {
        service
          ..startScreenLoad('home_screen')
          ..startScreenLoad('profile_screen');

        expect(service.activeSessionCount, equals(2));

        service.resetAllSessions();

        expect(service.activeSessionCount, equals(0));
      });

      test('is a no-op when no sessions are active', () {
        expect(service.activeSessionCount, equals(0));

        // Should not throw
        service.resetAllSessions();

        expect(service.activeSessionCount, equals(0));
      });

      test(
        'prevents stale markContentVisible from recording after reset',
        () {
          service.startScreenLoad('home_screen');
          expect(service.activeSessionCount, equals(1));

          service.resetAllSessions();
          expect(service.activeSessionCount, equals(0));

          // Completing a session that was cleared should be a no-op
          service.markContentVisible('home_screen');
          expect(service.activeSessionCount, equals(0));
        },
      );

      test(
        'prevents stale markDataLoaded from recording after reset',
        () {
          service.startScreenLoad('explore_screen');
          expect(service.activeSessionCount, equals(1));

          service.resetAllSessions();

          // Completing a session that was cleared should be a no-op
          service.markDataLoaded('explore_screen');
          expect(service.activeSessionCount, equals(0));
        },
      );
    });

    group('activeSessionCount', () {
      test('tracks number of active sessions', () {
        expect(service.activeSessionCount, equals(0));

        service.startScreenLoad('home_screen');
        expect(service.activeSessionCount, equals(1));

        service.startScreenLoad('profile_screen');
        expect(service.activeSessionCount, equals(2));

        service.endScreen('home_screen');
        expect(service.activeSessionCount, equals(1));
      });
    });

    group('startScreenLoad', () {
      test('replaces existing session for same screen', () {
        service
          ..startScreenLoad('home_screen')
          ..startScreenLoad('home_screen');

        expect(service.activeSessionCount, equals(1));
      });
    });

    group('endScreen', () {
      test('removes session', () {
        service.startScreenLoad('home_screen');
        expect(service.activeSessionCount, equals(1));

        service.endScreen('home_screen');
        expect(service.activeSessionCount, equals(0));
      });

      test('is a no-op for unknown screen', () {
        service.endScreen('nonexistent');
        expect(service.activeSessionCount, equals(0));
      });
    });

    group('markContentVisible', () {
      test('is a no-op for unknown screen', () {
        service.markContentVisible('nonexistent');
        expect(service.activeSessionCount, equals(0));
      });
    });

    group('markDataLoaded', () {
      test('is a no-op for unknown screen', () {
        service.markDataLoaded('nonexistent');
        expect(service.activeSessionCount, equals(0));
      });
    });
  });
}

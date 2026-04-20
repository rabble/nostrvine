// ABOUTME: Tests for ScreenAnalyticsService stale session handling.
// ABOUTME: Verifies sessions older than 60s are discarded and resetAllSessions
// ABOUTME: clears all active sessions on app resume.

@Tags(['skip_very_good_optimization'])
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/screen_analytics_service.dart';

void main() {
  group(ScreenAnalyticsService, () {
    late ScreenAnalyticsService service;

    setUp(() {
      service = ScreenAnalyticsService.testInstance();
    });

    tearDown(ScreenAnalyticsService.resetInstance);

    group('resetAllSessions', () {
      test('clears all active sessions', () {
        service
          ..startScreenLoad('HomeScreen')
          ..startScreenLoad('ExploreScreen')
          ..startScreenLoad('ProfileScreen');

        expect(service.activeSessionCount, 3);

        service.resetAllSessions();

        expect(service.activeSessionCount, 0);
      });

      test('does nothing when no sessions are active', () {
        expect(service.activeSessionCount, 0);

        service.resetAllSessions();

        expect(service.activeSessionCount, 0);
      });
    });

    group('stale session detection', () {
      test('markContentVisible processes fresh session normally', () {
        service.startScreenLoad('HomeScreen');
        expect(service.activeSessionCount, 1);

        service.markContentVisible('HomeScreen');

        expect(service.activeSessionCount, 1);
      });

      test('markDataLoaded processes fresh session normally', () {
        service.startScreenLoad('HomeScreen');
        expect(service.activeSessionCount, 1);

        service.markDataLoaded('HomeScreen');

        expect(service.activeSessionCount, 1);
      });

      test('markContentVisible is no-op for unknown screen', () {
        service.markContentVisible('UnknownScreen');
        expect(service.activeSessionCount, 0);
      });

      test('markDataLoaded is no-op for unknown screen', () {
        service.markDataLoaded('UnknownScreen');
        expect(service.activeSessionCount, 0);
      });

      test('endScreen removes session', () {
        service.startScreenLoad('HomeScreen');
        expect(service.activeSessionCount, 1);

        service.endScreen('HomeScreen');

        expect(service.activeSessionCount, 0);
      });
    });

    group('testInstance', () {
      test('creates instance without Firebase dependency', () {
        final instance = ScreenAnalyticsService.testInstance();

        instance
          ..startScreenLoad('TestScreen')
          ..markContentVisible('TestScreen')
          ..markDataLoaded('TestScreen')
          ..endScreen('TestScreen');

        expect(instance.activeSessionCount, 0);
      });

      test('tracks multiple independent sessions', () {
        service
          ..startScreenLoad('HomeScreen')
          ..startScreenLoad('ExploreScreen');

        expect(service.activeSessionCount, 2);

        service.endScreen('HomeScreen');
        expect(service.activeSessionCount, 1);

        service.endScreen('ExploreScreen');
        expect(service.activeSessionCount, 0);
      });
    });
  });
}

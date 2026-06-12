import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/firebase_analytics_event_sink.dart';

class _MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}

void main() {
  group(FirebaseAnalyticsEventSink, () {
    late FirebaseAnalytics analytics;
    late FirebaseAnalyticsEventSink sink;

    setUp(() {
      analytics = _MockFirebaseAnalytics();
      sink = FirebaseAnalyticsEventSink(analytics: analytics);
    });

    test('forwards custom events to Firebase Analytics', () async {
      const parameters = <String, Object>{
        'surface_name': 'comments_sheet',
        'total_ms': 3250,
      };
      when(
        () => analytics.logEvent(
          name: 'surface_load',
          parameters: parameters,
        ),
      ).thenAnswer((_) async {});

      await sink.logEvent(name: 'surface_load', parameters: parameters);

      verify(
        () => analytics.logEvent(
          name: 'surface_load',
          parameters: parameters,
        ),
      ).called(1);
    });

    test('forwards screen views to Firebase Analytics', () async {
      const parameters = <String, Object>{
        'route_name': 'video',
        'entry_point': 'navigation',
      };
      when(
        () => analytics.logScreenView(
          screenName: 'video_detail',
          screenClass: 'Route',
          parameters: parameters,
        ),
      ).thenAnswer((_) async {});

      await sink.logScreenView(
        screenName: 'video_detail',
        screenClass: 'Route',
        parameters: parameters,
      );

      verify(
        () => analytics.logScreenView(
          screenName: 'video_detail',
          screenClass: 'Route',
          parameters: parameters,
        ),
      ).called(1);
    });
  });
}

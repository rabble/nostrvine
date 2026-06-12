import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/analytics_event_sink.dart';

void main() {
  group(NoOpAnalyticsEventSink, () {
    test('accepts event and screen view calls without side effects', () async {
      const sink = NoOpAnalyticsEventSink();

      await sink.logEvent(
        name: 'surface_load',
        parameters: const {'surface_name': 'comments_sheet'},
      );
      await sink.logScreenView(
        screenName: 'video_detail',
        screenClass: 'Route',
        parameters: const {'route_name': 'video'},
      );
    });
  });
}

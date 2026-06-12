// ABOUTME: Firebase-backed implementation of the analytics event sink.

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:openvine/services/analytics_event_sink.dart';

class FirebaseAnalyticsEventSink implements AnalyticsEventSink {
  FirebaseAnalyticsEventSink({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) {
    return _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    );
  }
}

// ABOUTME: Tests authenticated identity fan-out to Analytics and Crashlytics.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/analytics_providers.dart';

class _RecordingSink implements AnalyticsEventSink {
  final userIds = <String?>[];
  final properties = <({String name, String? value})>[];

  @override
  Future<void> setUserId(String? userId) async => userIds.add(userId);

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async => properties.add((name: name, value: value));

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  const pubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('fans out the exact 64-character hex identity', () async {
    final sink = _RecordingSink();
    final crashIds = <String?>[];
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (userId) async => crashIds.add(userId),
    );

    await coordinator.setUserId(pubkey);

    expect(sink.userIds, [pubkey]);
    expect(crashIds, [pubkey]);
  });

  test('clears user identity and invite attribution on logout', () async {
    final sink = _RecordingSink();
    final crashIds = <String?>[];
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (userId) async => crashIds.add(userId),
    );

    await coordinator.setUserId(null);

    expect(sink.userIds, [null]);
    expect(sink.properties, [
      (name: AnalyticsUserProperty.inviteCode, value: null),
    ]);
    expect(crashIds, [null]);
  });

  test('refuses bech32 and malformed identities', () async {
    final sink = _RecordingSink();
    final crashIds = <String?>[];
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (userId) async => crashIds.add(userId),
    );

    await coordinator.setUserId('npub1not-a-hex-key');

    expect(sink.userIds, isEmpty);
    expect(crashIds, isEmpty);
  });
}

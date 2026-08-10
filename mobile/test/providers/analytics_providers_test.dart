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
  const otherPubkey =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  // The last applied identity is process-scoped, so it has to be reset between
  // tests for the suite to be order-independent.
  setUp(AnalyticsIdentityCoordinator.resetLastAppliedUserId);
  tearDown(AnalyticsIdentityCoordinator.resetLastAppliedUserId);

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

  test('clears invite attribution when the account changes', () async {
    final sink = _RecordingSink();
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (_) async {},
    );

    await coordinator.setUserId(pubkey);
    expect(sink.properties, isEmpty);

    // An account switch builds a fresh container, so the incoming account gets
    // its own coordinator without ever passing through logout.
    final switched = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (_) async {},
    );
    await switched.setUserId(otherPubkey);

    expect(sink.userIds, [pubkey, otherPubkey]);
    expect(sink.properties, [
      (name: AnalyticsUserProperty.inviteCode, value: null),
    ]);
  });

  test('keeps invite attribution set during the redeeming login', () async {
    final sink = _RecordingSink();
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (_) async {},
    );

    // Redemption sets the property before the new account authenticates, and
    // the sync provider can re-apply the same identity on a rebuild.
    await coordinator.setUserId(pubkey);
    await coordinator.setUserId(pubkey);

    expect(sink.properties, isEmpty);
  });

  test('lowercases identities so the campaign join stays exact', () async {
    final sink = _RecordingSink();
    final crashIds = <String?>[];
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (userId) async => crashIds.add(userId),
    );

    await coordinator.setUserId(pubkey.toUpperCase());

    expect(sink.userIds, [pubkey]);
    expect(crashIds, [pubkey]);
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

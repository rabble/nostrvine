// ABOUTME: Tests deterministic post-publish assignment and CTA analytics.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';

class _FakeFlags implements PostPublishFlagClient {
  _FakeFlags(this.createAgainEnabled);

  @override
  bool createAgainEnabled;

  @override
  void dispose() {}

  @override
  Future<void> initialize() async {}
}

class _RecordingSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async => events.add((name: name, parameters: parameters));

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}
}

void main() {
  const controlPubkey =
      '0000000000000000000000000000000000000000000000000000000000000000';
  const treatmentPubkey =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

  test('assigns the same user deterministically across calls', () {
    final experiment = PostPublishExperiment(
      flags: _FakeFlags(true),
      analytics: _RecordingSink(),
    );

    expect(
      experiment.variantForUser(controlPubkey),
      PostPublishVariant.control,
    );
    expect(
      experiment.variantForUser(treatmentPubkey),
      PostPublishVariant.createAgain,
    );
    expect(
      experiment.variantForUser(treatmentPubkey),
      PostPublishVariant.createAgain,
    );
  });

  test('assigns the same bucket regardless of hex casing', () {
    final experiment = PostPublishExperiment(
      flags: _FakeFlags(true),
      analytics: _RecordingSink(),
    );

    expect(
      experiment.variantForUser(treatmentPubkey.toUpperCase()),
      experiment.variantForUser(treatmentPubkey),
    );
  });

  test('remote flag forces every user into control', () {
    final experiment = PostPublishExperiment(
      flags: _FakeFlags(false),
      analytics: _RecordingSink(),
    );

    expect(
      experiment.variantForUser(treatmentPubkey),
      PostPublishVariant.control,
    );
  });

  test('records destination, variant, and seconds to create again', () async {
    final sink = _RecordingSink();
    var now = DateTime.utc(2026, 8, 8, 12);
    final experiment = PostPublishExperiment(
      flags: _FakeFlags(true),
      analytics: sink,
      now: () => now,
    );

    await experiment.screenShown(
      publishId: 'publish-1',
      destination: 'profile',
      variant: PostPublishVariant.createAgain,
    );
    final offer = experiment.completed({'publish-1'});
    expect(offer, isNotNull);
    now = now.add(const Duration(seconds: 17));
    await experiment.createAgainTapped(offer!);

    expect(sink.events.map((event) => event.name), [
      'post_publish_screen_shown',
      'post_publish_create_again_tapped',
    ]);
    expect(sink.events.first.parameters, {
      'destination': 'profile',
      'variant': 'create_again',
    });
    expect(sink.events.last.parameters, {'seconds_since_publish': 17});
  });

  test('bounds pending assignments that never resolve', () async {
    final experiment = PostPublishExperiment(
      flags: _FakeFlags(true),
      analytics: _RecordingSink(),
    );

    await experiment.screenShown(
      publishId: 'stranded',
      destination: 'profile',
      variant: PostPublishVariant.createAgain,
    );
    for (var i = 0; i < 32; i++) {
      await experiment.screenShown(
        publishId: 'publish-$i',
        destination: 'profile',
        variant: PostPublishVariant.createAgain,
      );
    }

    // The oldest stranded entry is evicted; the newest 32 still resolve.
    expect(experiment.completed({'stranded'}), isNull);
    expect(experiment.completed({'publish-31'}), isNotNull);
  });

  test('drops treatment state when a publish fails', () async {
    final experiment = PostPublishExperiment(
      flags: _FakeFlags(true),
      analytics: _RecordingSink(),
    );

    await experiment.screenShown(
      publishId: 'publish-failed',
      destination: 'profile',
      variant: PostPublishVariant.createAgain,
    );
    experiment.failed({'publish-failed'});

    expect(experiment.completed({'publish-failed'}), isNull);
  });
}

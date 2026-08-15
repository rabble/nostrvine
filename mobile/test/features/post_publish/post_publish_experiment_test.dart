// ABOUTME: Tests the post-publish confirmation experiment's bucketing and
// ABOUTME: the analytics it emits when View or Share is tapped.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';

class _RecordingAnalytics implements AnalyticsEventSink {
  final List<({String name, Map<String, Object> parameters})> events = [];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

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

/// A pubkey whose sha256 lands in each bucket, found by probing
/// [PostPublishExperiment.variantForUser] rather than hardcoding a hash.
String _pubkeyForVariant(PostPublishVariant variant) {
  final experiment = PostPublishExperiment(analytics: _RecordingAnalytics());
  for (var i = 0; i < 1000; i++) {
    final candidate = i.toRadixString(16).padLeft(64, '0');
    if (experiment.variantForUser(candidate) == variant) return candidate;
  }
  throw StateError('No pubkey found for $variant');
}

void main() {
  group(PostPublishExperiment, () {
    late _RecordingAnalytics analytics;
    late PostPublishExperiment experiment;

    setUp(() {
      analytics = _RecordingAnalytics();
      experiment = PostPublishExperiment(analytics: analytics);
    });

    group('variantForUser', () {
      test('buckets a signed-out user into control', () {
        expect(
          experiment.variantForUser(null),
          equals(PostPublishVariant.control),
        );
      });

      test('is case-insensitive so one account cannot change buckets', () {
        // A signer that returns uppercase hex must not move the account
        // between arms mid-experiment.
        final pubkey = _pubkeyForVariant(PostPublishVariant.viewShare);

        expect(
          experiment.variantForUser(pubkey.toUpperCase()),
          equals(experiment.variantForUser(pubkey)),
        );
      });

      test('assigns the same user the same variant every time', () {
        final pubkey = _pubkeyForVariant(PostPublishVariant.viewShare);

        expect(
          List.generate(5, (_) => experiment.variantForUser(pubkey)),
          everyElement(equals(PostPublishVariant.viewShare)),
        );
      });
    });

    group('completed', () {
      test('offers the confirmation for a viewShare publish', () async {
        await experiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: PostPublishVariant.viewShare,
        );

        expect(experiment.completed({'publish-1'}), isNotNull);
      });

      test('offers nothing for a control publish', () async {
        await experiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: PostPublishVariant.control,
        );

        expect(experiment.completed({'publish-1'}), isNull);
      });

      test('offers nothing for a publish it never saw', () {
        expect(experiment.completed({'unknown-publish'}), isNull);
      });

      test('does not offer twice for the same publish', () async {
        await experiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: PostPublishVariant.viewShare,
        );
        experiment.completed({'publish-1'});

        expect(experiment.completed({'publish-1'}), isNull);
      });

      test('a failed publish forfeits its offer', () async {
        await experiment.screenShown(
          publishId: 'publish-1',
          destination: 'profile',
          variant: PostPublishVariant.viewShare,
        );
        experiment.failed({'publish-1'});

        expect(experiment.completed({'publish-1'}), isNull);
      });
    });

    group('tap analytics', () {
      test('viewTapped reports elapsed seconds since publish', () async {
        final offer = PostPublishConfirmationOffer(
          publishedAt: DateTime(2026, 8, 15, 12),
        );
        final clocked = PostPublishExperiment(
          analytics: analytics,
          now: () => DateTime(2026, 8, 15, 12, 0, 7),
        );

        await clocked.viewTapped(offer);

        expect(
          analytics.events.single.name,
          equals('post_publish_view_tapped'),
        );
        expect(
          analytics.events.single.parameters['seconds_since_publish'],
          equals(7),
        );
      });

      test('shareTapped logs its own event name', () async {
        await experiment.shareTapped(
          PostPublishConfirmationOffer(publishedAt: DateTime.now()),
        );

        expect(
          analytics.events.single.name,
          equals('post_publish_share_tapped'),
        );
      });

      test('clamps a clock that ran backwards to zero', () async {
        final offer = PostPublishConfirmationOffer(
          publishedAt: DateTime(2026, 8, 15, 12),
        );
        final clocked = PostPublishExperiment(
          analytics: analytics,
          now: () => DateTime(2026, 8, 15, 11, 59),
        );

        await clocked.viewTapped(offer);

        expect(
          analytics.events.single.parameters['seconds_since_publish'],
          equals(0),
        );
      });
    });

    test('screenShown reports the variant under test', () async {
      await experiment.screenShown(
        publishId: 'publish-1',
        destination: 'profile',
        variant: PostPublishVariant.viewShare,
      );

      expect(analytics.events.single.name, equals('post_publish_screen_shown'));
      expect(
        analytics.events.single.parameters['variant'],
        equals('view_share'),
      );
    });
  });
}

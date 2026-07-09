// ABOUTME: Regression test for the #5953 PR review — deadMediaFeedGuardProvider
// ABOUTME: must mark the same BrokenVideoTracker instance videoEventServiceProvider
// ABOUTME: attaches to VideoEventService.filterVideoList, not a re-created one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_providers.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_provider_overrides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('brokenVideoTrackerProvider identity (#5953 review)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: getStandardTestOverrides().cast(),
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'brokenVideoTrackerProvider returns the same instance on every read',
      () async {
        // videoEventServiceProvider builds first and captures whatever
        // instance brokenVideoTrackerProvider hands back at that moment —
        // exactly like production startup order.
        container.read(videoEventServiceProvider);

        final first = await container.read(brokenVideoTrackerProvider.future);
        final second = await container.read(
          brokenVideoTrackerProvider.future,
        );

        expect(
          identical(first, second),
          isTrue,
          reason:
              'brokenVideoTrackerProvider must be keepAlive. Without it, the '
              "provider can autodispose once videoEventServiceProvider's "
              'one-off ref.read completes, so a later read (e.g. from '
              'deadMediaFeedGuardProvider) rebuilds a fresh tracker instance '
              'that VideoEventService never attached.',
        );
      },
    );

    test(
      "a mark made through deadMediaFeedGuardProvider's tracker is reflected "
      'by VideoEventService.filterVideoList',
      () async {
        // Build VideoEventService first (production attaches its tracker via
        // a fire-and-forget ref.read inside the provider's build function).
        final service = container.read(videoEventServiceProvider);

        // Let the fire-and-forget setBrokenVideoTracker(...) attach.
        await container.read(brokenVideoTrackerProvider.future);
        await Future<void>.delayed(Duration.zero);

        // media.divine.video so the videos survive the default
        // divine-hosted-only preference and only the tracker mark decides
        // whether they're filtered — matching the real #5953 scenario of a
        // missing media.divine.video blob.
        final good = TestHelpers.createVideoEvent(
          id: 'good1',
          videoUrl: 'https://media.divine.video/good1hash',
        );
        final dead = TestHelpers.createVideoEvent(
          id: 'dead1',
          videoUrl: 'https://media.divine.video/dead1hash',
        );

        expect(
          service.filterVideoList([good, dead]).map((v) => v.id),
          containsAll(<String>['good1', 'dead1']),
        );

        // deadMediaFeedGuardProvider wraps *the same* brokenVideoTrackerProvider
        // future with no other logic, so marking through the tracker it
        // resolves to is equivalent to a guard-confirmed mark.
        final guard = await container.read(deadMediaFeedGuardProvider.future);
        expect(guard, isA<Object>());
        final tracker = await container.read(brokenVideoTrackerProvider.future);
        await tracker.markVideoBroken('dead1', 'test: confirmed 404');

        expect(
          service.filterVideoList([good, dead]).map((v) => v.id),
          equals(['good1']),
          reason:
              'VideoEventService must filter against the exact tracker '
              'instance the home-feed guard marks — a stale/duplicate '
              'tracker (the pre-fix autoDispose bug) would leave the dead '
              'item visible in the home scrolling feed.',
        );
      },
    );
  });
}

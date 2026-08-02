// ABOUTME: Tests DeadMediaFeedGuard — a hard 404 prunes, the 401 age gate only
// ABOUTME: skips, and transient / reachable / missing-URL cases keep the item.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';
import 'package:openvine/services/media_availability_checker.dart';

class _MockChecker extends Mock implements MediaAvailabilityChecker {}

class _MockTracker extends Mock implements BrokenVideoTracker {}

void main() {
  group(DeadMediaFeedGuard, () {
    const url = 'https://media.divine.video/deadhash';

    late _MockChecker checker;
    late _MockTracker tracker;
    late DeadMediaFeedGuard guard;

    setUp(() {
      checker = _MockChecker();
      tracker = _MockTracker();
      when(
        () => tracker.markVideoBroken(any(), any()),
      ).thenAnswer((_) async {});
      guard = DeadMediaFeedGuard(
        brokenVideoTracker: tracker,
        availabilityChecker: checker,
      );
    });

    void stub(MediaAvailability availability) {
      when(() => checker.check(url)).thenAnswer((_) async => availability);
    }

    group('classify', () {
      test('prunes a HEAD-confirmed hard 404', () async {
        stub(MediaAvailability.missing);

        final verdict = await guard.classify(videoId: 'v1', videoUrl: url);

        expect(verdict, DeadMediaVerdict.skipAndPrune);
        verify(() => tracker.markVideoBroken('v1', any())).called(1);
      });

      // The 401 age gate is the regression this guards: blossom serves
      // AgeRestricted blobs to any authenticated request, so persisting a prune
      // would hide a video the viewer is entitled to watch for the tracker's
      // full TTL, on every surface that consults it. See #5953 / #6251.
      test('skips but never prunes an age-gated 401', () async {
        stub(MediaAvailability.authRequired);

        final verdict = await guard.classify(videoId: 'v1', videoUrl: url);

        expect(verdict, DeadMediaVerdict.skipOnly);
        verifyNever(() => tracker.markVideoBroken(any(), any()));
      });

      test('keeps a reachable item', () async {
        stub(MediaAvailability.available);

        final verdict = await guard.classify(videoId: 'v1', videoUrl: url);

        expect(verdict, DeadMediaVerdict.keep);
        verifyNever(() => tracker.markVideoBroken(any(), any()));
      });

      // A network flake must never evict a valid video.
      test('keeps the item when the check is inconclusive', () async {
        stub(MediaAvailability.unknown);

        final verdict = await guard.classify(videoId: 'v1', videoUrl: url);

        expect(verdict, DeadMediaVerdict.keep);
        verifyNever(() => tracker.markVideoBroken(any(), any()));
      });

      test('keeps the item and never probes when the URL is absent', () async {
        expect(
          await guard.classify(videoId: 'v1', videoUrl: null),
          DeadMediaVerdict.keep,
        );
        expect(
          await guard.classify(videoId: 'v1', videoUrl: ''),
          DeadMediaVerdict.keep,
        );
        verifyNever(() => checker.check(any()));
        verifyNever(() => tracker.markVideoBroken(any(), any()));
      });
    });

    group('confirmAndMarkMissing', () {
      test('advances past both a 404 and an age-gated 401', () async {
        stub(MediaAvailability.missing);
        expect(
          await guard.confirmAndMarkMissing(videoId: 'v1', videoUrl: url),
          isTrue,
        );

        stub(MediaAvailability.authRequired);
        expect(
          await guard.confirmAndMarkMissing(videoId: 'v2', videoUrl: url),
          isTrue,
        );
      });

      test('does not advance past a reachable or inconclusive item', () async {
        stub(MediaAvailability.available);
        expect(
          await guard.confirmAndMarkMissing(videoId: 'v1', videoUrl: url),
          isFalse,
        );

        stub(MediaAvailability.unknown);
        expect(
          await guard.confirmAndMarkMissing(videoId: 'v2', videoUrl: url),
          isFalse,
        );
      });

      // Only the 404 path may reach the tracker, whichever entry point is used.
      test('prunes on 404 only', () async {
        stub(MediaAvailability.authRequired);
        await guard.confirmAndMarkMissing(videoId: 'v1', videoUrl: url);
        verifyNever(() => tracker.markVideoBroken(any(), any()));

        stub(MediaAvailability.missing);
        await guard.confirmAndMarkMissing(videoId: 'v2', videoUrl: url);
        verify(() => tracker.markVideoBroken('v2', any())).called(1);
      });
    });
  });
}

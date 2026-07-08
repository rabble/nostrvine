// ABOUTME: Tests DeadMediaFeedGuard — confirms a hard 404 via HEAD and marks
// ABOUTME: the item broken; transient / non-404 / missing-URL cases keep it.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';
import 'package:openvine/services/media_availability_checker.dart';

class _MockChecker extends Mock implements MediaAvailabilityChecker {}

class _MockTracker extends Mock implements BrokenVideoTracker {}

void main() {
  group(DeadMediaFeedGuard, () {
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

    group('confirmAndMarkMissing', () {
      test(
        'returns true and marks broken when HEAD confirms a hard 404',
        () async {
          const url = 'https://media.divine.video/deadhash';
          when(
            () => checker.isConfirmedMissing(url),
          ).thenAnswer((_) async => true);

          final result = await guard.confirmAndMarkMissing(
            videoId: 'v1',
            videoUrl: url,
          );

          expect(result, isTrue);
          verify(() => tracker.markVideoBroken('v1', any())).called(1);
        },
      );

      test(
        'returns false and does NOT mark broken when the media is reachable / non-404',
        () async {
          when(
            () => checker.isConfirmedMissing(any()),
          ).thenAnswer((_) async => false);

          final result = await guard.confirmAndMarkMissing(
            videoId: 'v1',
            videoUrl: 'https://media.divine.video/live',
          );

          expect(result, isFalse);
          verifyNever(() => tracker.markVideoBroken(any(), any()));
        },
      );

      test('returns false without a HEAD when videoUrl is null', () async {
        final result = await guard.confirmAndMarkMissing(
          videoId: 'v1',
          videoUrl: null,
        );

        expect(result, isFalse);
        verifyNever(() => checker.isConfirmedMissing(any()));
        verifyNever(() => tracker.markVideoBroken(any(), any()));
      });

      test('returns false without a HEAD when videoUrl is empty', () async {
        final result = await guard.confirmAndMarkMissing(
          videoId: 'v1',
          videoUrl: '',
        );

        expect(result, isFalse);
        verifyNever(() => checker.isConfirmedMissing(any()));
      });
    });
  });
}

// ABOUTME: Tests DeadMediaFeedGuard — confirms 404 plus a terminal `blocked`
// ABOUTME: verdict before marking broken; reversible cases keep the item.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/dead_media_feed_guard.dart';
import 'package:openvine/services/media_availability_checker.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

class _MockChecker extends Mock implements MediaAvailabilityChecker {}

class _MockTracker extends Mock implements BrokenVideoTracker {}

class _MockModerationStatusService extends Mock
    implements VideoModerationStatusService {}

void main() {
  group(DeadMediaFeedGuard, () {
    late _MockChecker checker;
    late _MockTracker tracker;
    late _MockModerationStatusService moderationStatusService;
    late DeadMediaFeedGuard guard;

    setUp(() {
      checker = _MockChecker();
      tracker = _MockTracker();
      moderationStatusService = _MockModerationStatusService();
      when(
        () => tracker.markVideoBroken(any(), any()),
      ).thenAnswer((_) async {});
      guard = DeadMediaFeedGuard(
        brokenVideoTracker: tracker,
        moderationStatusService: moderationStatusService,
        availabilityChecker: checker,
      );
    });

    VideoModerationStatus status({
      bool blocked = false,
      bool quarantined = false,
      bool ageRestricted = false,
    }) => VideoModerationStatus(
      moderated: true,
      blocked: blocked,
      quarantined: quarantined,
      ageRestricted: ageRestricted,
      needsReview: false,
      aiGenerated: false,
    );

    group('confirmAndMarkMissing', () {
      test(
        'returns true and marks broken when HEAD 404 is blocked by moderation',
        () async {
          const url = 'https://media.divine.video/deadhash';
          final sha256 = 'a' * 64;
          when(
            () => checker.isConfirmedMissing(url),
          ).thenAnswer((_) async => true);
          when(
            () => moderationStatusService.fetchStatus(sha256),
          ).thenAnswer((_) async => status(blocked: true));

          final result = await guard.confirmAndMarkMissing(
            videoId: 'v1',
            videoUrl: url,
            explicitSha256: sha256,
          );

          expect(result, isTrue);
          verify(() => tracker.markVideoBroken('v1', any())).called(1);
        },
      );

      test(
        'returns true and marks broken when the canonical API no longer has the video',
        () async {
          final apiMissingGuard = DeadMediaFeedGuard(
            brokenVideoTracker: tracker,
            moderationStatusService: moderationStatusService,
            availabilityChecker: checker,
            eventMissingChecker: (_) async => true,
          );

          final result = await apiMissingGuard.confirmAndMarkMissing(
            videoId: 'v1',
            videoUrl: 'https://media.divine.video/live',
            explicitSha256: 'a' * 64,
          );

          expect(result, isTrue);
          verify(() => tracker.markVideoBroken('v1', any())).called(1);
          verifyNever(() => checker.isConfirmedMissing(any()));
          verifyNever(() => moderationStatusService.fetchStatus(any()));
        },
      );

      test(
        'falls back to media confirmation when the API missing check fails',
        () async {
          const url = 'https://media.divine.video/deadhash';
          final sha256 = 'a' * 64;
          final apiFailingGuard = DeadMediaFeedGuard(
            brokenVideoTracker: tracker,
            moderationStatusService: moderationStatusService,
            availabilityChecker: checker,
            eventMissingChecker: (_) async => throw Exception('timeout'),
          );
          when(
            () => checker.isConfirmedMissing(url),
          ).thenAnswer((_) async => true);
          when(
            () => moderationStatusService.fetchStatus(sha256),
          ).thenAnswer((_) async => status(blocked: true));

          final result = await apiFailingGuard.confirmAndMarkMissing(
            videoId: 'v1',
            videoUrl: url,
            explicitSha256: sha256,
          );

          expect(result, isTrue);
          verify(() => tracker.markVideoBroken('v1', any())).called(1);
        },
      );

      test(
        'stays recoverable when the API check throws and media cannot confirm',
        () async {
          const url = 'https://media.divine.video/live';
          final apiFailingGuard = DeadMediaFeedGuard(
            brokenVideoTracker: tracker,
            moderationStatusService: moderationStatusService,
            availabilityChecker: checker,
            eventMissingChecker: (_) async => throw Exception('timeout'),
          );
          when(
            () => checker.isConfirmedMissing(url),
          ).thenAnswer((_) async => false);

          final result = await apiFailingGuard.confirmAndMarkMissing(
            videoId: 'v1',
            videoUrl: url,
            explicitSha256: 'a' * 64,
          );

          expect(result, isFalse);
          verifyNever(() => tracker.markVideoBroken(any(), any()));
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
            explicitSha256: 'a' * 64,
          );

          expect(result, isFalse);
          verifyNever(() => tracker.markVideoBroken(any(), any()));
          verifyNever(() => moderationStatusService.fetchStatus(any()));
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
        verifyNever(() => moderationStatusService.fetchStatus(any()));
      });

      test('returns false without a HEAD when videoUrl is empty', () async {
        final result = await guard.confirmAndMarkMissing(
          videoId: 'v1',
          videoUrl: '',
        );

        expect(result, isFalse);
        verifyNever(() => checker.isConfirmedMissing(any()));
        verifyNever(() => moderationStatusService.fetchStatus(any()));
      });

      // Driven through a real MediaAvailabilityChecker rather than a stubbed
      // bool, so this goes red if the 404 predicate is ever widened to cover
      // the age gate. Blossom answers 401 for an AgeRestricted blob and serves
      // it to any authenticated request; pruning that would hide a video the
      // viewer can watch for the tracker's full TTL. See #5953 / #6251.
      test('never prunes an age-gated 401', () async {
        final gatedGuard = DeadMediaFeedGuard(
          brokenVideoTracker: tracker,
          moderationStatusService: moderationStatusService,
          availabilityChecker: MediaAvailabilityChecker(
            client: MockClient((_) async => http.Response('', 401)),
          ),
        );

        final result = await gatedGuard.confirmAndMarkMissing(
          videoId: 'v1',
          videoUrl: 'https://media.divine.video/agegated',
        );

        expect(result, isFalse);
        verifyNever(() => tracker.markVideoBroken(any(), any()));
        verifyNever(() => moderationStatusService.fetchStatus(any()));
      });

      test(
        'does not prune a 404 when moderation says age-restricted',
        () async {
          const url = 'https://media.divine.video/agegated';
          final sha256 = 'b' * 64;
          when(
            () => checker.isConfirmedMissing(url),
          ).thenAnswer((_) async => true);
          when(
            () => moderationStatusService.fetchStatus(sha256),
          ).thenAnswer((_) async => status(ageRestricted: true));

          final result = await guard.confirmAndMarkMissing(
            videoId: 'v1',
            videoUrl: url,
            explicitSha256: sha256,
          );

          expect(result, isFalse);
          verifyNever(() => tracker.markVideoBroken(any(), any()));
        },
      );

      test('does not prune a 404 when moderation lookup fails', () async {
        const url = 'https://media.divine.video/unknown';
        final sha256 = 'c' * 64;
        when(
          () => checker.isConfirmedMissing(url),
        ).thenAnswer((_) async => true);
        when(
          () => moderationStatusService.fetchStatus(sha256),
        ).thenAnswer((_) async => null);

        final result = await guard.confirmAndMarkMissing(
          videoId: 'v1',
          videoUrl: url,
          explicitSha256: sha256,
        );

        expect(result, isFalse);
        verifyNever(() => tracker.markVideoBroken(any(), any()));
      });

      // QUARANTINE maps to blossom RESTRICT — the reversible, pending-review
      // withhold, and the state an approval-required uploader's SAFE clip is
      // rewritten to. BrokenVideoTracker holds marks for 7 days and nothing
      // calls unmarkVideoBroken, so an un-quarantine never reaches the client.
      test('does not prune a 404 when moderation says quarantined', () async {
        const url = 'https://media.divine.video/quarantined';
        final sha256 = 'd' * 64;
        when(
          () => checker.isConfirmedMissing(url),
        ).thenAnswer((_) async => true);
        when(
          () => moderationStatusService.fetchStatus(sha256),
        ).thenAnswer((_) async => status(quarantined: true));

        final result = await guard.confirmAndMarkMissing(
          videoId: 'v1',
          videoUrl: url,
          explicitSha256: sha256,
        );

        expect(result, isFalse);
        verifyNever(() => tracker.markVideoBroken(any(), any()));
      });
    });

    // The fullscreen feed injects this predicate straight into
    // FullscreenFeedBloc (pooled_fullscreen_video_feed_screen.dart) and
    // persists off its bool, so the reversible verdicts must be pinned here
    // too — not only through confirmAndMarkMissing.
    group('isConfirmedUnavailable', () {
      const url = 'https://media.divine.video/hash';

      setUp(() {
        when(
          () => checker.isConfirmedMissing(url),
        ).thenAnswer((_) async => true);
      });

      test('is true for a 404 blocked by moderation', () async {
        when(
          () => moderationStatusService.fetchStatus(any()),
        ).thenAnswer((_) async => status(blocked: true));

        expect(
          await guard.isConfirmedUnavailable(
            videoId: 'v1',
            videoUrl: url,
            explicitSha256: 'e' * 64,
          ),
          isTrue,
        );
      });

      test('is false for a 404 that is only quarantined', () async {
        when(
          () => moderationStatusService.fetchStatus(any()),
        ).thenAnswer((_) async => status(quarantined: true));

        expect(
          await guard.isConfirmedUnavailable(
            videoId: 'v1',
            videoUrl: url,
            explicitSha256: 'e' * 64,
          ),
          isFalse,
        );
      });
    });
  });
}

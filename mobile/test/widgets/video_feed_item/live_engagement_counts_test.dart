// ABOUTME: Regression tests for feed action counter display seeds.
// ABOUTME: Preserves archival Vine baselines while adding live Divine counts.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/live_engagement_counts.dart';

void main() {
  VideoEvent videoWith({
    int? originalLikes,
    int? originalComments,
    int? originalReposts,
    int? nostrLikeCount,
    int? nostrCommentCount,
    int? nostrRepostCount,
    List<String>? reposterPubkeys,
  }) {
    return VideoEvent(
      id: 'video-id',
      pubkey: 'author-pubkey',
      createdAt: 1473050841,
      content: 'classic vine',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1473050841000),
      videoUrl: 'https://example.com/video.mp4',
      originalLikes: originalLikes,
      originalComments: originalComments,
      originalReposts: originalReposts,
      nostrLikeCount: nostrLikeCount,
      nostrCommentCount: nostrCommentCount,
      nostrRepostCount: nostrRepostCount,
      reposterPubkeys: reposterPubkeys,
    );
  }

  group('engagement count display seeds', () {
    test('preserve archival Vine metrics as the display baseline', () {
      final video = videoWith(
        originalLikes: 273622,
        originalComments: 6023,
        originalReposts: 122059,
      );

      expect(liveLikeCountSeed(video), equals(273622));
      expect(liveCommentCountSeed(video), equals(6023));
      expect(liveRepostCountSeed(video), equals(122059));
    });

    test('adds explicit live stats to archival Vine metrics', () {
      final video = videoWith(
        originalLikes: 273622,
        originalComments: 6023,
        originalReposts: 122059,
        nostrLikeCount: 5,
        nostrCommentCount: 2,
        nostrRepostCount: 3,
        reposterPubkeys: const ['pubkey-a', 'pubkey-b'],
      );

      expect(liveLikeCountSeed(video), equals(273627));
      expect(liveCommentCountSeed(video), equals(6025));
      expect(liveRepostCountSeed(video), equals(122062));
    });

    test(
      'uses visible reposter count when it exceeds explicit live reposts',
      () {
        final video = videoWith(
          originalReposts: 10,
          nostrRepostCount: 2,
          reposterPubkeys: const ['pubkey-a', 'pubkey-b', 'pubkey-c'],
        );

        expect(liveRepostCountSeed(video), equals(13));
      },
    );

    test(
      'uses visible reposter count when explicit live reposts are absent',
      () {
        final video = videoWith(
          originalReposts: 10,
          reposterPubkeys: const ['pubkey-a', 'pubkey-b'],
        );

        expect(liveRepostCountSeed(video), equals(12));
      },
    );

    test(
      'uses pasted New Videos payload counts instead of bogus relay totals',
      () {
        final video = videoWith(
          originalLikes: 2,
          originalComments: 0,
          originalReposts: 0,
          nostrLikeCount: 0,
        );

        expect(liveLikeCountSeed(video), equals(2));
        expect(liveCommentCountSeed(video), equals(0));
        expect(liveRepostCountSeed(video), equals(0));
      },
    );
  });

  group('divineOnlyCount', () {
    test('backs the archival baseline out of the display count', () {
      expect(
        divineOnlyCount(displayCount: 459878 + 387, archivedCount: 459878),
        equals(387),
      );
    });

    test('tracks optimistic taps applied to the display count', () {
      expect(
        divineOnlyCount(displayCount: 459878 + 388, archivedCount: 459878),
        equals(388),
      );
    });

    test('falls back to the raw live count when display count is unknown', () {
      expect(
        divineOnlyCount(
          displayCount: null,
          archivedCount: 459878,
          liveCount: 387,
        ),
        equals(387),
      );
      expect(
        divineOnlyCount(displayCount: null, archivedCount: 459878),
        equals(0),
      );
    });

    test('clamps to zero when the display count dips below archival', () {
      expect(
        divineOnlyCount(displayCount: 100, archivedCount: 459878),
        equals(0),
      );
    });
  });
}

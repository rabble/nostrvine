// ABOUTME: Regression tests for views/loops engagement metrics surviving
// ABOUTME: Nostr enrichment in enrichVideosWithNostrTags.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';

class _MockNostrClient extends Mock implements NostrClient {}

VideoEvent _restVideo({
  required String id,
  int? originalLoops,
  Map<String, String> extraTags = const {},
}) {
  return VideoEvent(
    id: id,
    pubkey: 'a' * 64,
    createdAt: 1704067200,
    content: 'rest video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      1704067200 * 1000,
      isUtc: true,
    ),
    videoUrl: 'https://example.com/$id.mp4',
    originalLoops: originalLoops,
    // Base REST rawTags are intentionally sparse (1 entry) so the enrichment
    // trigger in enrichVideosWithNostrTags — `rawTags.length < 4` — fires on
    // every test. Each test adds `views`, `title`, etc. via [extraTags].
    // Callers must keep `extraTags.length <= 2` to stay under the threshold.
    rawTags: {'d': id, ...extraTags},
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('enrichVideosWithNostrTags', () {
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockNostrClient = _MockNostrClient();
    });

    test(
      'preserves rawTags[views] from REST when Nostr enrichment fires',
      () async {
        const pubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final nostrEvent = Event(
          pubkey,
          34236,
          [
            ['d', 'video-1'],
            ['url', 'https://example.com/video-1.mp4'],
            ['title', 'Enriched Title'],
            ['m', 'video/mp4'],
          ],
          'Enriched content',
          createdAt: 1704067200,
        );
        final restVideo = _restVideo(
          id: nostrEvent.id,
          originalLoops: 0,
          extraTags: const {'views': '34'},
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [nostrEvent]);

        final enriched = await enrichVideosWithNostrTags([
          restVideo,
        ], nostrService: mockNostrClient);

        expect(enriched, hasLength(1));
        expect(enriched.single.rawTags['views'], equals('34'));
        expect(enriched.single.totalLoops, equals(34));
        expect(enriched.single.hasLoopMetadata, isTrue);
      },
    );

    test('Nostr-supplied tags override REST tags on key collision', () async {
      const pubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final nostrEvent = Event(
        pubkey,
        34236,
        [
          ['d', 'video-2'],
          ['url', 'https://example.com/video-2.mp4'],
          ['title', 'Nostr Title Wins'],
          ['m', 'video/mp4'],
        ],
        'Nostr content',
        createdAt: 1704067200,
      );
      final restVideo = _restVideo(
        id: nostrEvent.id,
        extraTags: const {'views': '7', 'title': 'REST Title (stale)'},
      );

      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => [nostrEvent]);

      final enriched = await enrichVideosWithNostrTags([
        restVideo,
      ], nostrService: mockNostrClient);

      expect(enriched.single.rawTags['title'], equals('Nostr Title Wins'));
      expect(enriched.single.rawTags['views'], equals('7'));
    });
  });
}

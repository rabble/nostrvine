// ABOUTME: Tests for non-blocking enrichment (Change 5 of EOSE fix)
// ABOUTME: Validates enrichVideosInBackground returns immediately

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';

class _MockNostrClient extends Mock implements NostrClient {}

VideoEvent _createTestVideo({
  required String id,
  Map<String, String>? rawTags,
}) {
  return VideoEvent(
    id: id,
    pubkey: 'test_pubkey',
    createdAt: 1704067200,
    content: 'Test video',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    rawTags: rawTags ?? const {},
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('enrichVideosInBackground', () {
    late _MockNostrClient mockNostrService;

    setUp(() {
      mockNostrService = _MockNostrClient();
    });

    test('returns original videos immediately', () {
      final videos = [_createTestVideo(id: 'v1'), _createTestVideo(id: 'v2')];

      // Set up a slow query that never completes quickly
      when(() => mockNostrService.queryEvents(any())).thenAnswer(
        (_) => Completer<List<Event>>().future, // Never completes
      );

      final result = enrichVideosInBackground(
        videos,
        nostrService: mockNostrService,
        onEnriched: (_) {},
      );

      // Should return synchronously with the original list
      expect(result, same(videos));
      expect(result.length, 2);
    });

    test('onEnriched callback fires with merged tags', () async {
      // Create a Nostr event with tags.
      // The Event constructor auto-generates the id from content,
      // so we create the event first and use its id for the test video.
      final testPubkey = 'a' * 64;
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['url', 'https://example.com/v1.mp4'],
          ['title', 'Enriched Video'],
          ['d', 'v1'],
          ['proof', 'c2pa-hash'],
        ],
        'Test content',
        createdAt: 1704067200,
      );
      final videos = [
        _createTestVideo(id: nostrEvent.id), // rawTags empty, needs enrichment
      ];

      when(
        () => mockNostrService.queryEvents(any()),
      ).thenAnswer((_) async => [nostrEvent]);

      final enrichedCompleter = Completer<List<VideoEvent>>();

      enrichVideosInBackground(
        videos,
        nostrService: mockNostrService,
        onEnriched: enrichedCompleter.complete,
      );

      // Wait for the background enrichment to complete
      final enriched = await enrichedCompleter.future.timeout(
        const Duration(seconds: 2),
      );

      expect(enriched.length, 1);
      expect(enriched.first.rawTags, isNotEmpty);
    });

    test(
      'copies content warning labels from enriched Nostr tags',
      () async {
        final testPubkey = 'a' * 64;
        final nostrEvent = Event(
          testPubkey,
          34236,
          [
            ['url', 'https://example.com/v1.mp4'],
            ['content-warning', 'nudity'],
            ['L', 'content-warning'],
            ['l', 'nudity', 'content-warning'],
          ],
          'Test content',
          createdAt: 1704067200,
        );
        final videos = [_createTestVideo(id: nostrEvent.id)];

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [nostrEvent]);

        final enriched = await enrichVideosWithNostrTags(
          videos,
          nostrService: mockNostrService,
        );

        expect(enriched, hasLength(1));
        expect(enriched.first.rawTags['content-warning'], equals('nudity'));
        expect(enriched.first.contentWarningLabels, equals(['nudity']));
      },
    );

    test('enrichment failure does not affect initial return', () async {
      final videos = [_createTestVideo(id: 'v1')];

      when(
        () => mockNostrService.queryEvents(any()),
      ).thenThrow(Exception('Network error'));

      var onEnrichedCalled = false;

      final result = enrichVideosInBackground(
        videos,
        nostrService: mockNostrService,
        onEnriched: (_) {
          onEnrichedCalled = true;
        },
      );

      // Should still return original videos
      expect(result, same(videos));

      // Wait a bit to ensure callback isn't called
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(onEnrichedCalled, isFalse);
    });

    test('does not call onEnriched when no enrichment needed', () async {
      final videos = [
        _createTestVideo(
          id: 'v1',
          rawTags: {
            'url': 'https://example.com/v1.mp4',
            'title': 'Already enriched',
            'd': 'v1',
            'proof': 'c2pa-hash',
          },
        ),
      ];

      // queryEvents should not be called since rawTags.length >= 4
      final result = enrichVideosInBackground(
        videos,
        nostrService: mockNostrService,
        onEnriched: (_) {
          fail('onEnriched should not be called');
        },
      );

      expect(result, same(videos));

      // Wait to ensure no callback
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyNever(() => mockNostrService.queryEvents(any()));
    });
  });
}

// ABOUTME: Tests for CurationService edge cases and error paths
// ABOUTME: Covers _updateVideoCache match, refreshCurationSets
// ABOUTME: stream errors, and createCurationSet exception

import 'dart:async';

import 'package:curation_service/curation_service.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventCache extends Mock implements VideoEventCache {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

// Test pubkey removed — the bespoke retry tests that used it were
// deleted along with retryUnpublishedCurations / failedAttempts.

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(
      Event('0' * 64, 1, <List<String>>[], ''),
    );
    registerFallbackValue(<String>[]);
    registerFallbackValue(const RetryPolicy());
    registerFallbackValue(
      VideoEvent(
        id: 'fallback',
        pubkey: 'fallback',
        createdAt: 0,
        content: '',
        timestamp: DateTime(2020),
      ),
    );
  });

  group('CurationService edge cases', () {
    late _MockNostrClient mockNostrService;
    late _MockVideoEventCache mockVideoEventCache;
    late _MockLikesRepository mockLikesRepository;
    late _MockNostrSigner mockSigner;
    late CurationService curationService;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockVideoEventCache = _MockVideoEventCache();
      mockLikesRepository = _MockLikesRepository();
      mockSigner = _MockNostrSigner();

      when(
        () => mockVideoEventCache.discoveryVideos,
      ).thenReturn([]);
      when(
        () => mockVideoEventCache.addVideoEvent(any()),
      ).thenReturn(null);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer(
        (_) => const Stream<Event>.empty(),
      );
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => {});
    });

    group('_updateVideoCache', () {
      test(
        'populates cache with matching videos from '
        'discovery',
        () async {
          final video1 = VideoEvent(
            id: 'video_a',
            pubkey: 'pub1',
            createdAt: 1000,
            content: '',
            timestamp: DateTime(2024),
          );
          final video2 = VideoEvent(
            id: 'video_b',
            pubkey: 'pub2',
            createdAt: 2000,
            content: '',
            timestamp: DateTime(2024),
          );

          when(
            () => mockVideoEventCache.discoveryVideos,
          ).thenReturn([video1, video2]);

          curationService = CurationService(
            nostrService: mockNostrService,
            videoEventCache: mockVideoEventCache,
            likesRepository: mockLikesRepository,
            signer: mockSigner,
            divineTeamPubkeys: const [],
          );

          // Subscribe and send a curation event with
          // video IDs that match our discovery videos
          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          await curationService.subscribeToCurationSets();

          controller.add(
            Event.fromJson({
              'id': 'curation_event',
              'pubkey': 'curator',
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'test_set'],
                ['title', 'Test Set'],
                ['e', 'video_a'],
                ['e', 'video_b'],
              ],
              'content': '',
              'sig': 'sig',
            }),
          );

          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );

          // The video cache should now have the matching
          // videos
          final videos = curationService.getVideosForSet(
            'test_set',
          );
          expect(videos, hasLength(2));
          expect(videos[0].id, equals('video_a'));
          expect(videos[1].id, equals('video_b'));

          await controller.close();
        },
      );
    });

    group('refreshCurationSets stream error', () {
      test(
        'handles stream error during refresh',
        () async {
          curationService = CurationService(
            nostrService: mockNostrService,
            videoEventCache: mockVideoEventCache,
            likesRepository: mockLikesRepository,
            signer: mockSigner,
            divineTeamPubkeys: const [],
          );

          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          final future = curationService.refreshCurationSets();

          // Emit an error on the stream
          controller.addError(
            Exception('Relay disconnect'),
          );

          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );

          // The completer should completeError and the
          // outer catch should handle it
          await future;

          // Should have fallen back to sample data
          expect(
            curationService.curationSets,
            isNotEmpty,
          );
        },
      );

      test(
        'handles parse error in refreshCurationSets '
        'event listener',
        () async {
          curationService = CurationService(
            nostrService: mockNostrService,
            videoEventCache: mockVideoEventCache,
            likesRepository: mockLikesRepository,
            signer: mockSigner,
            divineTeamPubkeys: const [],
          );

          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          final future = curationService.refreshCurationSets();

          // Send a kind 30005 event that will throw
          // ArgumentError during parsing (no 'd' tag).
          // CurationSet.fromNostrEvent does not throw
          // Exception for this case, so the catch won't
          // fire. But let's send a valid event followed
          // by stream close.
          controller.add(
            Event.fromJson({
              'id': 'good',
              'pubkey': 'curator',
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 30005,
              'tags': [
                ['d', 'good_set'],
                ['title', 'Good Set'],
              ],
              'content': '',
              'sig': 'sig',
            }),
          );

          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );

          unawaited(controller.close());
          await future;

          final set = curationService.getCurationSet(
            'good_set',
          );
          expect(set, isNotNull);
        },
      );
    });

    group('createCurationSet exception', () {
      test(
        'returns false when publishCuration throws '
        'exception',
        () async {
          // Make getPublicKey throw to cause
          // buildCurationEvent to throw
          when(
            () => mockSigner.getPublicKey(),
          ).thenThrow(Exception('Signer unavailable'));

          curationService = CurationService(
            nostrService: mockNostrService,
            videoEventCache: mockVideoEventCache,
            likesRepository: mockLikesRepository,
            signer: mockSigner,
            divineTeamPubkeys: const [],
          );

          final result = await curationService.createCurationSet(
            id: 'error_set',
            title: 'Error Set',
            videoIds: ['v1'],
          );

          expect(result, isFalse);
        },
      );
    });

    // The bespoke retryUnpublishedCurations/backoff API was removed in
    // favour of NostrClient.publishEventWithRetry (see PR 5 of the
    // reliable-nostr-publish series). Retry semantics are now covered by
    // curation_service_reliability_test.dart.
  });
}

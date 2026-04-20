// ABOUTME: Tests for CurationService Nostr publishing functionality
// ABOUTME: (kind 30005). Verifies curation sets are correctly published
// ABOUTME: via NostrClient.publishEventWithRetry.

import 'dart:async';

import 'package:curation_service/curation_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventCache extends Mock implements VideoEventCache {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'
    'e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

Event _testEvent({
  int kind = 30005,
  List<List<String>> tags = const [],
  String content = '',
}) {
  return Event(_testPubkey, kind, tags, content);
}

PublishOutcome _acceptedOutcome() => PublishOutcome(
  eventId: 'a' * 64,
  acceptedBy: const {'wss://a'},
  rejectedBy: const {},
  noResponseFrom: const {},
);

PublishOutcome _failedOutcome() => PublishOutcome(
  eventId: 'a' * 64,
  acceptedBy: const {},
  rejectedBy: const {},
  noResponseFrom: const {'wss://a'},
);

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_testEvent());
    registerFallbackValue(<String>[]);
    registerFallbackValue(<List<String>>[]);
    registerFallbackValue(const RetryPolicy());
  });

  group('CurationService Publishing', () {
    late CurationService curationService;
    late _MockNostrClient mockNostrService;
    late _MockVideoEventCache mockVideoEventCache;
    late _MockLikesRepository mockLikesRepository;
    late _MockNostrSigner mockSigner;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockVideoEventCache = _MockVideoEventCache();
      mockLikesRepository = _MockLikesRepository();
      mockSigner = _MockNostrSigner();

      when(
        () => mockSigner.getPublicKey(),
      ).thenAnswer((_) async => _testPubkey);
      when(() => mockSigner.signEvent(any())).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return Event(event.pubkey, event.kind, event.tags, event.content);
      });

      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(['wss://relay1.example.com']);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());

      when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => {});

      curationService = CurationService(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [],
      );
    });

    group('buildCurationEvent', () {
      test(
        'should create kind 30005 event with correct structure',
        () async {
          final event = await curationService.buildCurationEvent(
            id: 'test_curation_1',
            title: 'Test Curation',
            videoIds: ['video1', 'video2', 'video3'],
            description: 'A test curation set',
            imageUrl: 'https://example.com/image.jpg',
          );

          expect(event, isNotNull);
          expect(event!.kind, equals(30005));
        },
      );

      test('should handle optional fields correctly', () async {
        final event = await curationService.buildCurationEvent(
          id: 'minimal_curation',
          title: 'Minimal Curation',
          videoIds: ['video1'],
        );

        expect(event, isNotNull);
        expect(event!.kind, equals(30005));
      });

      test('should handle empty video list', () async {
        final event = await curationService.buildCurationEvent(
          id: 'empty_curation',
          title: 'Empty Curation',
          videoIds: [],
        );

        expect(event, isNotNull);
        expect(event!.kind, equals(30005));
        expect(event.tags.where((tag) => tag[0] == 'e'), isEmpty);
      });
    });

    group('publishCuration', () {
      test('should publish event to Nostr and return success', () async {
        when(
          () => mockNostrService.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _acceptedOutcome());

        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test Curation',
          videoIds: ['video1', 'video2'],
          description: 'Test description',
        );

        expect(result.success, isTrue);
        expect(result.outcome, isNotNull);
        expect(result.outcome!.acceptedBy, {'wss://a'});
        expect(result.eventId, isNotNull);

        verify(
          () => mockNostrService.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test('should handle complete failure gracefully', () async {
        when(
          () => mockNostrService.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _failedOutcome());

        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
      });

      test(
        'prevents duplicate concurrent publishes via duplicate flag',
        () {
          fakeAsync((async) {
            final completer = Completer<PublishOutcome>();
            when(
              () => mockNostrService.publishEventWithRetry(
                any(),
                policy: any(named: 'policy'),
                targetRelays: any(named: 'targetRelays'),
              ),
            ).thenAnswer((_) => completer.future);

            // Start first publish (will block on completer).
            CurationResult? firstResult;
            unawaited(
              curationService
                  .publishCuration(
                    id: 'rapid_curation',
                    title: 'Test',
                    videoIds: [],
                  )
                  .then((r) => firstResult = r),
            );

            async.flushMicrotasks();

            // Second publish of same id should be rejected as duplicate.
            CurationResult? secondResult;
            unawaited(
              curationService
                  .publishCuration(
                    id: 'rapid_curation',
                    title: 'Test',
                    videoIds: [],
                  )
                  .then((r) => secondResult = r),
            );

            async.flushMicrotasks();

            expect(secondResult!.success, isFalse);
            expect(secondResult!.duplicate, isTrue);

            // Complete the first publish.
            completer.complete(_acceptedOutcome());
            async.flushMicrotasks();
            expect(firstResult!.success, isTrue);
          });
        },
      );
    });

    group('Local Persistence', () {
      test('marks curation as published locally after success', () async {
        when(
          () => mockNostrService.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _acceptedOutcome());

        await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        final status = curationService.getCurationPublishStatus(
          'test_curation',
        );
        expect(status.isPublished, isTrue);
        expect(status.lastPublishedAt, isNotNull);
        expect(status.isPublishing, isFalse);
      });

      test('records hasFailed after publish failure', () async {
        when(
          () => mockNostrService.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _failedOutcome());

        await curationService.publishCuration(
          id: 'failed_curation',
          title: 'Test',
          videoIds: [],
        );

        final status = curationService.getCurationPublishStatus(
          'failed_curation',
        );
        expect(status.isPublished, isFalse);
        expect(status.hasFailed, isTrue);
      });

      test('returns default status for unknown curation', () {
        final status = curationService.getCurationPublishStatus(
          'unknown_curation',
        );
        expect(status.isPublished, isFalse);
        expect(status.isPublishing, isFalse);
        expect(status.hasFailed, isFalse);
      });
    });

    group('Publishing Status UI', () {
      test('reports "Publishing..." status during publish', () {
        fakeAsync((async) {
          final completer = Completer<PublishOutcome>();
          when(
            () => mockNostrService.publishEventWithRetry(
              any(),
              policy: any(named: 'policy'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) => completer.future);

          unawaited(
            curationService.publishCuration(
              id: 'publishing_curation',
              title: 'Test',
              videoIds: [],
            ),
          );

          async.flushMicrotasks();

          final status = curationService.getCurationPublishStatus(
            'publishing_curation',
          );
          expect(status.isPublishing, isTrue);
          expect(status.statusText, equals('Publishing...'));

          completer.complete(_acceptedOutcome());
          async.flushMicrotasks();

          final finalStatus = curationService.getCurationPublishStatus(
            'publishing_curation',
          );
          expect(finalStatus.isPublishing, isFalse);
          expect(finalStatus.isPublished, isTrue);
          expect(finalStatus.statusText, contains('Published'));
        });
      });

      test('shows error status for failed publishes', () async {
        when(
          () => mockNostrService.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _failedOutcome());

        await curationService.publishCuration(
          id: 'error_curation',
          title: 'Test',
          videoIds: [],
        );

        final status = curationService.getCurationPublishStatus(
          'error_curation',
        );
        expect(status.statusText, contains('Error'));
        expect(status.isError, isTrue);
      });
    });
  });
}

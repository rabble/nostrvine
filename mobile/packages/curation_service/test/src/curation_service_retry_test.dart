// ABOUTME: Retry semantics for CurationService.publishCuration — retry
// ABOUTME: is delegated to NostrClient.publishEventWithRetry and only the
// ABOUTME: final outcome is surfaced on CurationResult.

import 'package:curation_service/curation_service.dart';
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

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_testEvent());
    registerFallbackValue(<String>[]);
    registerFallbackValue(const RetryPolicy());
  });

  group('CurationService retry delegation', () {
    late CurationService curationService;
    late _MockNostrClient mockNostr;
    late _MockVideoEventCache mockCache;
    late _MockLikesRepository mockLikes;
    late _MockNostrSigner mockSigner;

    setUp(() {
      mockNostr = _MockNostrClient();
      mockCache = _MockVideoEventCache();
      mockLikes = _MockLikesRepository();
      mockSigner = _MockNostrSigner();

      when(
        () => mockSigner.getPublicKey(),
      ).thenAnswer((_) async => _testPubkey);
      when(() => mockSigner.signEvent(any())).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return Event(event.pubkey, event.kind, event.tags, event.content);
      });

      when(
        () => mockNostr.connectedRelays,
      ).thenReturn(['wss://relay1.example.com']);
      when(
        () => mockNostr.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());

      when(() => mockCache.discoveryVideos).thenReturn([]);
      when(
        () => mockLikes.getLikeCounts(any()),
      ).thenAnswer((_) async => {});

      curationService = CurationService(
        nostrService: mockNostr,
        videoEventCache: mockCache,
        likesRepository: mockLikes,
        signer: mockSigner,
        divineTeamPubkeys: const [],
      );
    });

    test(
      'publishCuration invokes publishEventWithRetry exactly once',
      () async {
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'a' * 64,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          ),
        );

        await curationService.publishCuration(
          id: 'single',
          title: 'Single',
          videoIds: const [],
        );

        // publishEventWithRetry is called once — the RetryPolicy is applied
        // inside NostrClient. The service must NOT implement its own retry
        // loop (that would double-count attempts).
        verify(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      },
    );

    test(
      'failed publish surfaces hasFailed on CurationPublishStatus',
      () async {
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: 'a' * 64,
            acceptedBy: const {},
            rejectedBy: const {},
            noResponseFrom: const {'wss://a'},
          ),
        );

        await curationService.publishCuration(
          id: 'failed_once',
          title: 'Failed Once',
          videoIds: const [],
        );

        final status = curationService.getCurationPublishStatus(
          'failed_once',
        );
        expect(status.isPublished, isFalse);
        expect(status.hasFailed, isTrue);
        expect(status.isError, isTrue);
      },
    );
  });
}

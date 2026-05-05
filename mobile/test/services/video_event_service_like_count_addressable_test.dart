// ABOUTME: Tests that VideoEventService passes addressable IDs through to
// ABOUTME: getLikeCounts so reactions on replaced videos are counted correctly.

import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as sdk;
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _MockLikesRepository extends Mock implements LikesRepository {}

void main() {
  group('VideoEventService - like count addressable ID wiring', () {
    const pubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const videoUrl = 'https://example.com/video.mp4';

    late _MockNostrClient mockNostrClient;
    late _MockSubscriptionManager mockSubscriptionManager;
    late _MockLikesRepository mockLikesRepository;
    late VideoEventService service;

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();
      mockLikesRepository = _MockLikesRepository();

      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.publicKey).thenReturn('');
      when(
        () => mockLikesRepository.getLikeCounts(
          any(),
          addressableIds: any(named: 'addressableIds'),
        ),
      ).thenAnswer((_) async => {});

      service = VideoEventService(
        mockNostrClient,
        subscriptionManager: mockSubscriptionManager,
      );
      service.setLikesRepository(mockLikesRepository);
    });

    tearDown(() {
      service.dispose();
    });

    // Fill the batch to the maximum (50) so the flush fires immediately,
    // avoiding any dependence on the 150 ms debounce timer.
    sdk.Event makeEvent(String dTag, {int createdAt = 1000}) => sdk.Event(
      pubkey,
      NIP71VideoKinds.addressableShortVideo,
      [
        ['d', dTag],
        ['url', videoUrl],
        ['title', 'Test'],
      ],
      '',
      createdAt: createdAt,
    );

    test(
      '_fetchAndUpdateLikeCount populates addressable IDs and passes them to getLikeCounts',
      () async {
        // Build a batch of 49 non-addressable-interest events to prime the
        // queue, then add the video under test as the 50th entry.  The 50th
        // push hits the batch-max threshold and triggers an immediate flush
        // (no timer).
        final padEvents = List.generate(
          49,
          (i) => makeEvent('pad-vine-$i'),
        );
        for (final e in padEvents) {
          service.handleEventForTesting(e, SubscriptionType.discovery);
        }

        // The 50th video — kind 34236 with a d-tag — has a non-null
        // addressableId and is the one we want to verify passes through.
        final targetEvent = makeEvent('target-vine');
        service.handleEventForTesting(
          targetEvent,
          SubscriptionType.discovery,
        );

        // The flush is synchronous up to the await inside
        // _executeLikeCountBatchFetch.  Pump the event loop so the async
        // getLikeCounts call completes.
        await Future<void>.delayed(Duration.zero);

        final captured = verify(
          () => mockLikesRepository.getLikeCounts(
            any(),
            addressableIds: captureAny(named: 'addressableIds'),
          ),
        ).captured;

        // The captured value is the addressableIds map passed to getLikeCounts.
        final addressableIds = captured.first as Map<String, String>?;
        expect(
          addressableIds,
          isNotNull,
          reason:
              'addressableIds should be non-null for a batch containing a kind 34236 video',
        );

        final targetVideo = VideoEvent.fromNostrEvent(targetEvent);
        expect(
          addressableIds!.containsKey(targetVideo.id),
          isTrue,
          reason:
              'The target video event ID should be present in addressableIds',
        );
        expect(
          addressableIds[targetVideo.id],
          equals(targetVideo.addressableId),
          reason:
              'The addressable ID should be the kind:pubkey:d-tag string from the video',
        );
      },
    );

    test(
      'addressable ID value has the correct kind:pubkey:d-tag format',
      () async {
        const dTag = 'my-special-vine';

        // Fill 49 padding events first, then the target as the 50th to trigger
        // an immediate flush.
        for (var i = 0; i < 49; i++) {
          service.handleEventForTesting(
            makeEvent('pad-vine-$i'),
            SubscriptionType.discovery,
          );
        }

        final targetEvent = makeEvent(dTag);
        service.handleEventForTesting(
          targetEvent,
          SubscriptionType.discovery,
        );

        await Future<void>.delayed(Duration.zero);

        final captured = verify(
          () => mockLikesRepository.getLikeCounts(
            any(),
            addressableIds: captureAny(named: 'addressableIds'),
          ),
        ).captured;

        final addressableIds = captured.first as Map<String, String>?;
        expect(addressableIds, isNotNull);

        final targetVideo = VideoEvent.fromNostrEvent(targetEvent);
        final aId = addressableIds![targetVideo.id];
        expect(
          aId,
          equals('${NIP71VideoKinds.addressableShortVideo}:$pubkey:$dTag'),
          reason: 'Addressable ID should be kind:pubkey:d-tag',
        );
      },
    );
  });
}

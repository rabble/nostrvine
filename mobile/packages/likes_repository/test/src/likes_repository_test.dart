import 'dart:async';

import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockLikesLocalStorage extends Mock implements LikesLocalStorage {}

class MockEvent extends Mock implements Event {}

void main() {
  group('LikesRepository', () {
    late MockNostrClient mockNostrClient;
    late MockLikesLocalStorage mockLocalStorage;
    late LikesRepository repository;

    // Test constants
    const testUserPubkey = 'test_user_pubkey_1234567890abcdef';
    const testEventId = 'test_event_id_1234567890abcdef';
    const testAuthorPubkey = 'test_author_pubkey_1234567890abcdef';
    const testReactionEventId = 'test_reaction_event_id_1234567890abcdef';
    const defaultTimestamp = 1700000000;

    // Helper to create a LikeRecord
    LikeRecord createLikeRecord({
      String targetEventId = testEventId,
      String reactionEventId = testReactionEventId,
      DateTime? createdAt,
    }) => LikeRecord(
      targetEventId: targetEventId,
      reactionEventId: reactionEventId,
      createdAt: createdAt ?? DateTime.now(),
    );

    // Helper to create a mock reaction event
    MockEvent createMockReaction({
      required String id,
      required String targetEventId,
      String content = '+',
      int createdAt = defaultTimestamp,
    }) {
      final event = MockEvent();
      when(() => event.id).thenReturn(id);
      when(() => event.content).thenReturn(content);
      when(() => event.createdAt).thenReturn(createdAt);
      when(() => event.tags).thenReturn([
        ['e', targetEventId],
      ]);
      return event;
    }

    // Helper to create a mock deletion event
    MockEvent createMockDeletion(List<String> deletedEventIds) {
      final event = MockEvent();
      when(() => event.tags).thenReturn(
        deletedEventIds.map((id) => ['e', id]).toList(),
      );
      return event;
    }

    // Helper to mock queryEvents with sequential responses
    void mockQueryEventsSequence(List<List<Event>> responses) {
      var callCount = 0;
      when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
        return responses[callCount++ % responses.length];
      });
    }

    // Helper to create repository with standard setup
    LikesRepository createRepository({bool withLocalStorage = true}) {
      return LikesRepository(
        nostrClient: mockNostrClient,
        localStorage: withLocalStorage ? mockLocalStorage : null,
      );
    }

    setUpAll(() {
      registerFallbackValue(MockEvent());
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(createLikeRecord());
      registerFallbackValue('');
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockLocalStorage = MockLikesLocalStorage();

      // Default mock behaviors
      when(() => mockNostrClient.publicKey).thenReturn(testUserPubkey);
      when(() => mockNostrClient.hasKeys).thenReturn(false);
      when(
        () => mockNostrClient.unsubscribe(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalStorage.getAllLikeRecords(),
      ).thenAnswer((_) async => []);
      when(
        () => mockLocalStorage.watchLikedEventIds(),
      ).thenAnswer((_) => Stream.value(<String>[]));
      when(
        () => mockLocalStorage.isLiked(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockLocalStorage.getLikeRecord(any()),
      ).thenAnswer((_) async => null);
    });

    tearDown(() => repository.dispose());

    group('constructor', () {
      test('creates repository without local storage', () {
        repository = createRepository(withLocalStorage: false);
        expect(repository, isNotNull);
      });

      test('creates repository with local storage', () {
        repository = createRepository();
        expect(repository, isNotNull);
      });
    });

    group('isLiked', () {
      test('returns false when event is not liked', () async {
        repository = createRepository();
        expect(await repository.isLiked(testEventId), isFalse);
      });

      test('returns true when event is liked', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);

        repository = createRepository();
        expect(await repository.isLiked(testEventId), isTrue);
      });
    });

    group('getLikedEventIds', () {
      test('returns empty set when no likes', () async {
        repository = createRepository();
        expect(await repository.getLikedEventIds(), isEmpty);
      });

      test('returns set of liked event IDs', () async {
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(targetEventId: 'event1', reactionEventId: 'r1'),
            createLikeRecord(targetEventId: 'event2', reactionEventId: 'r2'),
          ],
        );

        repository = createRepository();
        final result = await repository.getLikedEventIds();

        expect(result, containsAll(['event1', 'event2']));
        expect(result.length, equals(2));
      });
    });

    group('getOrderedLikedEventIds', () {
      test('returns empty list when no likes', () async {
        repository = createRepository();
        expect(await repository.getOrderedLikedEventIds(), isEmpty);
      });

      test('returns event IDs ordered by createdAt descending', () async {
        final oldest = DateTime(2024, 1, 1, 10);
        final middle = DateTime(2024, 1, 1, 12);
        final newest = DateTime(2024, 1, 1, 14);

        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: 'oldest_event_id_1234567890abcdef',
              reactionEventId: 'r_oldest',
              createdAt: oldest,
            ),
            createLikeRecord(
              targetEventId: 'newest_event_id_1234567890abcdef',
              reactionEventId: 'r_newest',
              createdAt: newest,
            ),
            createLikeRecord(
              targetEventId: 'middle_event_id_1234567890abcdef',
              reactionEventId: 'r_middle',
              createdAt: middle,
            ),
          ],
        );

        repository = createRepository();
        final result = await repository.getOrderedLikedEventIds();

        expect(result, [
          'newest_event_id_1234567890abcdef',
          'middle_event_id_1234567890abcdef',
          'oldest_event_id_1234567890abcdef',
        ]);
      });

      test('works without local storage', () async {
        repository = createRepository(withLocalStorage: false);
        expect(await repository.getOrderedLikedEventIds(), isEmpty);
      });
    });

    group('likeEvent', () {
      test('publishes like reaction and stores record', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, equals(testReactionEventId));
        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
            targetAuthorPubkey: testAuthorPubkey,
          ),
        ).called(1);
        verify(() => mockLocalStorage.saveLikeRecord(any())).called(1);
      });

      test('publishes like with addressable ID when provided', () async {
        const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          addressableId: testAddressableId,
          targetKind: 34236,
        );

        expect(result, equals(testReactionEventId));
        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
            addressableId: testAddressableId,
            targetAuthorPubkey: testAuthorPubkey,
            targetKind: 34236,
          ),
        ).called(1);
      });

      test('throws LikeFailedException when publish fails', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => null);

        repository = createRepository();

        expect(
          () => repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LikeFailedException>()),
        );
      });

      test('throws AlreadyLikedException when already liked', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);

        repository = createRepository();
        await repository.isLiked(testEventId); // Initialize

        expect(
          () => repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<AlreadyLikedException>()),
        );
      });
    });

    group('unlikeEvent', () {
      test('publishes deletion and removes record', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => MockEvent());
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        repository = createRepository();
        await repository.isLiked(testEventId); // Initialize
        await repository.unlikeEvent(testEventId);

        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
        verify(() => mockLocalStorage.deleteLikeRecord(testEventId)).called(1);
      });

      test('throws NotLikedException when not liked', () async {
        repository = createRepository();
        expect(
          () => repository.unlikeEvent(testEventId),
          throwsA(isA<NotLikedException>()),
        );
      });

      test('throws UnlikeFailedException when deletion fails', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => null);

        repository = createRepository();
        await repository.isLiked(testEventId); // Initialize

        expect(
          () => repository.unlikeEvent(testEventId),
          throwsA(isA<UnlikeFailedException>()),
        );
      });

      test('falls back to database when record not in memory cache', () async {
        when(
          () => mockLocalStorage.getLikeRecord(testEventId),
        ).thenAnswer((_) async => createLikeRecord());
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => MockEvent());
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        repository = createRepository();
        await repository.unlikeEvent(testEventId);

        verify(() => mockLocalStorage.getLikeRecord(testEventId)).called(1);
        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
      });
    });

    group('toggleLike', () {
      test('likes when not liked and returns true', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        expect(
          await repository.toggleLike(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          isTrue,
        );
      });

      test('toggleLike passes addressableId and targetKind', () async {
        const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        await repository.toggleLike(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          addressableId: testAddressableId,
          targetKind: 34236,
        );

        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
            addressableId: testAddressableId,
            targetAuthorPubkey: testAuthorPubkey,
            targetKind: 34236,
          ),
        ).called(1);
      });

      test('unlikes when liked and returns false', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);
        when(
          () => mockLocalStorage.isLiked(testEventId),
        ).thenAnswer((_) async => true);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => MockEvent());
        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        repository = createRepository();
        await repository.isLiked(testEventId); // Initialize

        expect(
          await repository.toggleLike(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          isFalse,
        );
      });

      test('uses in-memory cache when no localStorage', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => mockEvent);
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => MockEvent());

        repository = createRepository(withLocalStorage: false);
        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(
          await repository.toggleLike(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          isFalse,
        );
      });
    });

    group('getLikeCount', () {
      test('queries relay for like count by event ID', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 42));

        repository = createRepository();
        expect(await repository.getLikeCount(testEventId), equals(42));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test(
        'queries by both e and a tags when addressableId provided',
        () async {
          const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';

          // First call returns e-tag count, second call returns a-tag count
          var callCount = 0;
          when(
            () => mockNostrClient.countEvents(any()),
          ).thenAnswer((_) async {
            callCount++;
            return callCount == 1
                ? const CountResult(count: 10)
                : const CountResult(count: 15);
          });

          repository = createRepository();
          final count = await repository.getLikeCount(
            testEventId,
            addressableId: testAddressableId,
          );

          // Should return the max of both counts
          expect(count, equals(15));
          verify(() => mockNostrClient.countEvents(any())).called(2);
        },
      );

      test('returns max count when e-tag count is higher', () async {
        const testAddressableId = '34236:$testAuthorPubkey:test-d-tag';

        var callCount = 0;
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async {
          callCount++;
          return callCount == 1
              ? const CountResult(count: 20) // e-tag count
              : const CountResult(count: 5); // a-tag count
        });

        repository = createRepository();
        final count = await repository.getLikeCount(
          testEventId,
          addressableId: testAddressableId,
        );

        expect(count, equals(20));
      });

      test('ignores empty addressableId', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer((_) async => const CountResult(count: 7));

        repository = createRepository();
        final count = await repository.getLikeCount(
          testEventId,
          addressableId: '',
        );

        expect(count, equals(7));
        // Should only call once (e-tag only) since addressableId is empty
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });
    });

    group('getLikeCounts', () {
      test('returns empty map for empty input', () async {
        repository = createRepository();
        expect(await repository.getLikeCounts([]), isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('queries relay for multiple event counts', () async {
        const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';
        const eventId2 = 'event_id_2_1234567890abcdef01234567890abcdef';
        const eventId3 = 'event_id_3_1234567890abcdef01234567890abcdef';

        final mockReaction1 = MockEvent();
        when(() => mockReaction1.tags).thenReturn([
          ['e', eventId1],
        ]);
        final mockReaction2 = MockEvent();
        when(() => mockReaction2.tags).thenReturn([
          ['e', eventId1],
        ]);
        final mockReaction3 = MockEvent();
        when(() => mockReaction3.tags).thenReturn([
          ['e', eventId2],
        ]);

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [mockReaction1, mockReaction2, mockReaction3],
        );

        repository = createRepository();
        final result = await repository.getLikeCounts([
          eventId1,
          eventId2,
          eventId3,
        ]);

        expect(result, {eventId1: 2, eventId2: 1, eventId3: 0});
      });

      test('handles events with non-list or empty tags', () async {
        const eventId = 'event_id_1234567890abcdef01234567890abcdef';

        final mockReaction1 = MockEvent();
        when(() => mockReaction1.tags).thenReturn(['not_a_list']);
        final mockReaction2 = MockEvent();
        when(() => mockReaction2.tags).thenReturn([]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockReaction1, mockReaction2]);

        repository = createRepository();
        expect(await repository.getLikeCounts([eventId]), {eventId: 0});
      });

      test(
        'queries by both e and a tags when addressableIds provided',
        () async {
          const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';
          const eventId2 = 'event_id_2_1234567890abcdef01234567890abcdef';
          const aTag1 = '34236:author1:d1';
          const aTag2 = '34236:author2:d2';

          // Reaction found via e-tag for event1
          final mockReactionByE = MockEvent();
          when(() => mockReactionByE.tags).thenReturn([
            ['e', eventId1],
          ]);

          // Reactions found via a-tag for event2
          final mockReactionByA1 = MockEvent();
          when(() => mockReactionByA1.tags).thenReturn([
            ['a', aTag2],
          ]);
          final mockReactionByA2 = MockEvent();
          when(() => mockReactionByA2.tags).thenReturn([
            ['a', aTag2],
          ]);

          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async {
            callCount++;
            // First call is e-tag query, second is a-tag query
            return callCount == 1
                ? [mockReactionByE]
                : [mockReactionByA1, mockReactionByA2];
          });

          repository = createRepository();
          final counts = await repository.getLikeCounts(
            [eventId1, eventId2],
            addressableIds: {
              eventId1: aTag1,
              eventId2: aTag2,
            },
          );

          // event1 has 1 from e-tag, event2 has 2 from a-tag
          expect(counts, {eventId1: 1, eventId2: 2});
          verify(() => mockNostrClient.queryEvents(any())).called(2);
        },
      );

      test('returns max count when merging e and a tag results', () async {
        const eventId = 'event_id_1234567890abcdef01234567890abcdef';
        const aTag = '34236:author:d-tag';

        // 3 reactions via e-tag
        final mockReactionByE1 = MockEvent();
        when(() => mockReactionByE1.tags).thenReturn([
          ['e', eventId],
        ]);
        final mockReactionByE2 = MockEvent();
        when(() => mockReactionByE2.tags).thenReturn([
          ['e', eventId],
        ]);
        final mockReactionByE3 = MockEvent();
        when(() => mockReactionByE3.tags).thenReturn([
          ['e', eventId],
        ]);

        // 2 reactions via a-tag
        final mockReactionByA1 = MockEvent();
        when(() => mockReactionByA1.tags).thenReturn([
          ['a', aTag],
        ]);
        final mockReactionByA2 = MockEvent();
        when(() => mockReactionByA2.tags).thenReturn([
          ['a', aTag],
        ]);

        var callCount = 0;
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async {
          callCount++;
          return callCount == 1
              ? [mockReactionByE1, mockReactionByE2, mockReactionByE3]
              : [mockReactionByA1, mockReactionByA2];
        });

        repository = createRepository();
        final counts = await repository.getLikeCounts(
          [eventId],
          addressableIds: {eventId: aTag},
        );

        // Should return 3 (max of 3 from e-tag and 2 from a-tag)
        expect(counts[eventId], equals(3));
      });
    });

    group('syncUserReactions', () {
      test('fetches reactions from relay and stores locally', () async {
        const targetId = 'target_event_1234567890abcdef';
        const reactionId = 'reaction_event_1234567890abcdef';

        final mockReaction = createMockReaction(
          id: reactionId,
          targetEventId: targetId,
        );

        mockQueryEventsSequence([
          [mockReaction],
          [],
        ]);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, contains(targetId));
        expect(result.eventIdToReactionId[targetId], equals(reactionId));
      });

      test('filters out deleted reactions using Kind 5 events', () async {
        const targetId1 = 'target_event_1_1234567890abcdef';
        const reactionId1 = 'reaction_event_1_1234567890abcdef';
        const targetId2 = 'target_event_2_1234567890abcdef';
        const reactionId2 = 'reaction_event_2_1234567890abcdef';

        final mockReaction1 = createMockReaction(
          id: reactionId1,
          targetEventId: targetId1,
        );
        final mockReaction2 = createMockReaction(
          id: reactionId2,
          targetEventId: targetId2,
        );
        final mockDeletion = createMockDeletion([reactionId1]);

        mockQueryEventsSequence([
          [mockReaction1, mockReaction2],
          [mockDeletion],
        ]);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, contains(targetId2));
        expect(result.orderedEventIds, isNot(contains(targetId1)));
      });

      test('removes deleted likes from local storage', () async {
        const targetId = 'target_event_1234567890abcdef';
        const reactionId = 'reaction_event_1234567890abcdef';

        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: targetId,
              reactionEventId: reactionId,
            ),
          ],
        );

        final mockReaction = createMockReaction(
          id: reactionId,
          targetEventId: targetId,
        );
        final mockDeletion = createMockDeletion([reactionId]);

        mockQueryEventsSequence([
          [mockReaction],
          [mockDeletion],
        ]);
        when(
          () => mockLocalStorage.deleteLikeRecord(targetId),
        ).thenAnswer((_) async => true);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        await repository.syncUserReactions();

        verify(() => mockLocalStorage.deleteLikeRecord(targetId)).called(1);
      });

      test('ignores non-like reactions (content != "+")', () async {
        final mockReaction = createMockReaction(
          id: 'reaction_id_1234567890abcdef',
          targetEventId: 'target_id_1234567890abcdef',
          content: '-', // Dislike
        );

        mockQueryEventsSequence([
          [mockReaction],
          [],
        ]);

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, isEmpty);
      });

      test('handles empty relay response', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, isEmpty);
        expect(result.eventIdToReactionId, isEmpty);
      });

      test('falls back to local data when relay query fails', () async {
        when(() => mockLocalStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: 'local_target_event_1234567890abcdef',
              reactionEventId: 'local_reaction_1234567890abcdef',
            ),
          ],
        );
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(
          result.orderedEventIds,
          contains('local_target_event_1234567890abcdef'),
        );
      });

      test(
        'throws SyncFailedException when relay fails and no local data',
        () async {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenThrow(Exception('Network error'));

          repository = createRepository();

          expect(
            () => repository.syncUserReactions(),
            throwsA(isA<SyncFailedException>()),
          );
        },
      );

      test('handles continuous like/unlike cycles correctly', () async {
        const targetId = 'target_event_1234567890abcdef';
        const reactionId1 = 'reaction_1_1234567890abcdef';
        const reactionId2 = 'reaction_2_1234567890abcdef';

        final mockReaction1 = createMockReaction(
          id: reactionId1,
          targetEventId: targetId,
        );
        final mockReaction2 = createMockReaction(
          id: reactionId2,
          targetEventId: targetId,
          createdAt: 1700000100,
        );
        final mockDeletion = createMockDeletion([reactionId1]);

        mockQueryEventsSequence([
          [mockReaction1, mockReaction2],
          [mockDeletion],
        ]);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, contains(targetId));
        expect(result.eventIdToReactionId[targetId], equals(reactionId2));
      });

      test('handles deletion events with multiple e tags', () async {
        const targetId1 = 'target_1_1234567890abcdef';
        const reactionId1 = 'reaction_1_1234567890abcdef';
        const targetId2 = 'target_2_1234567890abcdef';
        const reactionId2 = 'reaction_2_1234567890abcdef';

        final mockReaction1 = createMockReaction(
          id: reactionId1,
          targetEventId: targetId1,
        );
        final mockReaction2 = createMockReaction(
          id: reactionId2,
          targetEventId: targetId2,
        );
        final mockDeletion = createMockDeletion([reactionId1, reactionId2]);

        mockQueryEventsSequence([
          [mockReaction1, mockReaction2],
          [mockDeletion],
        ]);

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, isEmpty);
      });

      test('updates newer record when duplicate target events exist', () async {
        const targetId = 'target_event_1234567890abcdef';
        const olderReactionId = 'older_reaction_1234567890abcdef';
        const newerReactionId = 'newer_reaction_1234567890abcdef';

        final mockOlder = createMockReaction(
          id: olderReactionId,
          targetEventId: targetId,
        );
        final mockNewer = createMockReaction(
          id: newerReactionId,
          targetEventId: targetId,
          createdAt: 1700000100,
        );

        mockQueryEventsSequence([
          [mockOlder, mockNewer],
          [],
        ]);
        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        final result = await repository.syncUserReactions();

        expect(result.eventIdToReactionId[targetId], equals(newerReactionId));
      });
    });

    group('fetchUserLikes', () {
      const otherUserPubkey = 'other_user_pubkey_1234567890abcdef';

      test('fetches likes for another user from relay', () async {
        const targetId = 'target_event_1234567890abcdef';

        final mockReaction = MockEvent();
        when(() => mockReaction.content).thenReturn('+');
        when(() => mockReaction.createdAt).thenReturn(defaultTimestamp);
        when(() => mockReaction.tags).thenReturn([
          ['e', targetId],
        ]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockReaction]);

        repository = createRepository();
        expect(await repository.fetchUserLikes(otherUserPubkey), [targetId]);
      });

      test('returns likes ordered by recency', () async {
        const olderId = 'older_target_1234567890abcdef';
        const newerId = 'newer_target_1234567890abcdef';

        final mockOlder = MockEvent();
        when(() => mockOlder.content).thenReturn('+');
        when(() => mockOlder.createdAt).thenReturn(1700000000);
        when(() => mockOlder.tags).thenReturn([
          ['e', olderId],
        ]);

        final mockNewer = MockEvent();
        when(() => mockNewer.content).thenReturn('+');
        when(() => mockNewer.createdAt).thenReturn(1700000100);
        when(() => mockNewer.tags).thenReturn([
          ['e', newerId],
        ]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockOlder, mockNewer]);

        repository = createRepository();
        expect(
          await repository.fetchUserLikes(otherUserPubkey),
          [newerId, olderId],
        );
      });

      test('deduplicates target event IDs', () async {
        const targetId = 'target_event_1234567890abcdef';

        final mockReaction1 = MockEvent();
        when(() => mockReaction1.content).thenReturn('+');
        when(() => mockReaction1.createdAt).thenReturn(1700000000);
        when(() => mockReaction1.tags).thenReturn([
          ['e', targetId],
        ]);

        final mockReaction2 = MockEvent();
        when(() => mockReaction2.content).thenReturn('+');
        when(() => mockReaction2.createdAt).thenReturn(1700000100);
        when(() => mockReaction2.tags).thenReturn([
          ['e', targetId],
        ]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockReaction1, mockReaction2]);

        repository = createRepository();
        final result = await repository.fetchUserLikes(otherUserPubkey);

        expect(result, hasLength(1));
        expect(result[0], equals(targetId));
      });

      test('ignores non-like reactions', () async {
        final mockReaction = MockEvent();
        when(() => mockReaction.content).thenReturn('-'); // Dislike
        when(() => mockReaction.createdAt).thenReturn(defaultTimestamp);
        when(() => mockReaction.tags).thenReturn([
          ['e', 'target_id'],
        ]);

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [mockReaction]);

        repository = createRepository();
        expect(await repository.fetchUserLikes(otherUserPubkey), isEmpty);
      });

      test('throws FetchLikesFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        repository = createRepository();

        expect(
          () => repository.fetchUserLikes(otherUserPubkey),
          throwsA(isA<FetchLikesFailedException>()),
        );
      });
    });

    group('getLikeRecord', () {
      test('returns record when event is liked', () async {
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [createLikeRecord()]);

        repository = createRepository();
        final result = await repository.getLikeRecord(testEventId);

        expect(result, isNotNull);
        expect(result!.targetEventId, equals(testEventId));
      });

      test('returns null when event is not liked', () async {
        repository = createRepository();
        expect(await repository.getLikeRecord('nonexistent'), isNull);
      });
    });

    group('clearCache', () {
      test('clears local storage and in-memory cache', () async {
        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = createRepository();
        await repository.clearCache();

        verify(() => mockLocalStorage.clearAll()).called(1);
        expect(await repository.getLikedEventIds(), isEmpty);
      });

      test('does not throw when called after dispose', () async {
        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = createRepository()..dispose();

        // clearCache after dispose should not throw "Cannot add new events
        // after calling close" on the BehaviorSubject.
        await expectLater(repository.clearCache(), completes);
      });
    });

    group('watchLikedEventIds', () {
      test('returns stream from local storage when available', () async {
        when(
          () => mockLocalStorage.watchLikedEventIds(),
        ).thenAnswer((_) => Stream.value(<String>['event1', 'event2']));

        repository = createRepository();
        expect(
          await repository.watchLikedEventIds().first,
          containsAll(['event1', 'event2']),
        );
      });

      test('returns internal stream when no local storage', () async {
        repository = createRepository(withLocalStorage: false);
        expect(await repository.watchLikedEventIds().first, isEmpty);
      });
    });

    group('initialize', () {
      test('loads records from local storage', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer(
          (_) async => [
            createLikeRecord(
              targetEventId: 'event_a_1234567890abcdef',
              reactionEventId: 'reaction_a_1234567890abcdef',
            ),
          ],
        );

        repository = createRepository();
        await repository.initialize();

        expect(
          await repository.isLiked('event_a_1234567890abcdef'),
          isTrue,
        );
      });

      test('sets up subscription when client has keys', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => const Stream.empty());

        repository = createRepository();
        await repository.initialize();

        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(1);
      });

      test('skips subscription when client has no keys', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        repository = createRepository();
        await repository.initialize();

        verifyNever(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        );
      });

      test('is idempotent', () async {
        when(() => mockNostrClient.hasKeys).thenReturn(false);

        repository = createRepository();
        await repository.initialize();
        await repository.initialize();

        verify(() => mockLocalStorage.getAllLikeRecords()).called(1);
      });
    });

    group('real-time sync', () {
      test('processes incoming reaction event', () async {
        final streamController = StreamController<Event>.broadcast();
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();
        await repository.initialize();

        // Emit a Kind 7 reaction event
        final reactionEvent = MockEvent();
        when(() => reactionEvent.id).thenReturn(testReactionEventId);
        when(() => reactionEvent.kind).thenReturn(EventKind.reaction);
        when(() => reactionEvent.content).thenReturn('+');
        when(() => reactionEvent.pubkey).thenReturn(testUserPubkey);
        when(() => reactionEvent.createdAt).thenReturn(defaultTimestamp);
        when(() => reactionEvent.tags).thenReturn([
          ['e', testEventId],
        ]);

        streamController.add(reactionEvent);
        await Future<void>.delayed(Duration.zero);

        expect(await repository.isLiked(testEventId), isTrue);
        verify(() => mockLocalStorage.saveLikeRecord(any())).called(1);

        await streamController.close();
      });

      test('ignores non-like reaction content', () async {
        final streamController = StreamController<Event>.broadcast();
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);

        repository = createRepository();
        await repository.initialize();

        final dislikeEvent = MockEvent();
        when(() => dislikeEvent.kind).thenReturn(EventKind.reaction);
        when(() => dislikeEvent.content).thenReturn('-');
        when(() => dislikeEvent.pubkey).thenReturn(testUserPubkey);

        streamController.add(dislikeEvent);
        await Future<void>.delayed(Duration.zero);

        expect(await repository.isLiked(testEventId), isFalse);

        await streamController.close();
      });

      test('deduplicates older events', () async {
        final streamController = StreamController<Event>.broadcast();
        when(() => mockNostrClient.hasKeys).thenReturn(true);
        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        // Pre-populate with an existing record
        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer(
          (_) async => [
            createLikeRecord(
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                defaultTimestamp * 1000,
              ),
            ),
          ],
        );

        repository = createRepository();
        await repository.initialize();

        // Emit an older event for the same target
        final olderEvent = MockEvent();
        when(() => olderEvent.id).thenReturn('older_reaction_id');
        when(() => olderEvent.kind).thenReturn(EventKind.reaction);
        when(() => olderEvent.content).thenReturn('+');
        when(() => olderEvent.pubkey).thenReturn(testUserPubkey);
        when(() => olderEvent.createdAt).thenReturn(defaultTimestamp - 100);
        when(() => olderEvent.tags).thenReturn([
          ['e', testEventId],
        ]);

        streamController.add(olderEvent);
        await Future<void>.delayed(Duration.zero);

        // The older event should not replace the existing record
        final record = await repository.getLikeRecord(testEventId);
        expect(record!.reactionEventId, equals(testReactionEventId));

        await streamController.close();
      });
    });

    group('offline queuing', () {
      test('likeEvent queues action when offline', () async {
        var queuedAction = <String, dynamic>{};

        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queuedAction = {
                  'isLike': isLike,
                  'eventId': eventId,
                  'authorPubkey': authorPubkey,
                  'addressableId': addressableId,
                  'targetKind': targetKind,
                };
              },
        );

        final reactionId = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
          addressableId: '34236:author:video',
          targetKind: 34236,
        );

        expect(reactionId, startsWith('pending_like_'));
        expect(queuedAction['isLike'], isTrue);
        expect(queuedAction['eventId'], equals(testEventId));
        expect(queuedAction['authorPubkey'], equals(testAuthorPubkey));
        expect(queuedAction['addressableId'], equals('34236:author:video'));
        expect(queuedAction['targetKind'], equals(34236));

        // Should still show as liked locally
        expect(await repository.isLiked(testEventId), isTrue);

        // Should save to local storage
        verify(() => mockLocalStorage.saveLikeRecord(any())).called(1);
      });

      test('unlikeEvent queues action when offline', () async {
        var queuedAction = <String, dynamic>{};

        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        // Create repository with offline callbacks
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {
                queuedAction = {
                  'isLike': isLike,
                  'eventId': eventId,
                };
              },
        );

        // Add a like (will be queued since offline)
        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(await repository.isLiked(testEventId), isTrue);

        // Now unlike while offline
        await repository.unlikeEvent(testEventId);

        expect(queuedAction['isLike'], isFalse);
        expect(queuedAction['eventId'], equals(testEventId));

        // Should no longer show as liked locally
        expect(await repository.isLiked(testEventId), isFalse);
      });
    });

    group('executeLikeAction', () {
      test('publishes like directly to relays', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
          ),
        );

        repository = createRepository();

        final eventId = await repository.executeLikeAction(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(eventId, equals(testReactionEventId));

        verify(
          () => mockNostrClient.sendLike(
            testEventId,
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: testAuthorPubkey,
            targetKind: any(named: 'targetKind'),
          ),
        ).called(1);
      });

      test('updates placeholder record with real event ID', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
          ),
        );
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        // First create a pending like (offline)
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {},
        );

        final placeholderId = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(placeholderId, startsWith('pending_like_'));

        // Now execute the real action (simulating sync)
        final realEventId = await repository.executeLikeAction(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(realEventId, equals(testReactionEventId));

        // Verify local storage was updated
        verify(() => mockLocalStorage.saveLikeRecord(any())).called(2);
      });

      test('throws LikeFailedException when publish fails', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer((_) async => null);

        repository = createRepository();

        expect(
          () => repository.executeLikeAction(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LikeFailedException>()),
        );
      });
    });

    group('executeUnlikeAction', () {
      test('publishes deletion directly to relays', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
          ),
        );
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => createMockDeletion([testReactionEventId]));
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        repository = createRepository();

        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        // Now execute unlike directly
        await repository.executeUnlikeAction(testEventId);

        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
        verify(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).called(1);
      });

      test('skips deletion for pending likes', () async {
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        // Create a pending like (offline)
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {},
        );

        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        // Execute unlike - should not call deleteEvent since never synced
        await repository.executeUnlikeAction(testEventId);

        verifyNever(() => mockNostrClient.deleteEvent(any()));
        verify(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).called(1);
      });

      test('does nothing when no record exists', () async {
        when(
          () => mockLocalStorage.getLikeRecord(any()),
        ).thenAnswer((_) async => null);

        repository = createRepository();

        // Should not throw, just return
        await repository.executeUnlikeAction(testEventId);

        verifyNever(() => mockNostrClient.deleteEvent(any()));
        verifyNever(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        );
      });

      test('throws UnlikeFailedException when deletion fails', () async {
        when(
          () => mockNostrClient.sendLike(
            any(),
            content: any(named: 'content'),
            addressableId: any(named: 'addressableId'),
            targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
            targetKind: any(named: 'targetKind'),
          ),
        ).thenAnswer(
          (_) async => createMockReaction(
            id: testReactionEventId,
            targetEventId: testEventId,
          ),
        );
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = createRepository();

        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(
          () => repository.executeUnlikeAction(testEventId),
          throwsA(isA<UnlikeFailedException>()),
        );
      });

      test('falls back to local storage when not in cache', () async {
        final record = createLikeRecord();

        when(
          () => mockLocalStorage.getLikeRecord(testEventId),
        ).thenAnswer((_) async => record);
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => createMockDeletion([testReactionEventId]));
        when(
          () => mockLocalStorage.deleteLikeRecord(any()),
        ).thenAnswer((_) async => true);

        repository = createRepository();

        await repository.executeUnlikeAction(testEventId);

        verify(
          () => mockLocalStorage.getLikeRecord(testEventId),
        ).called(1);
        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
      });
    });
  });
}

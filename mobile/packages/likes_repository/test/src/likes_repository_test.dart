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

    const testUserPubkey = 'test_user_pubkey_1234567890abcdef';
    const testEventId = 'test_event_id_1234567890abcdef';
    const testAuthorPubkey = 'test_author_pubkey_1234567890abcdef';
    const testReactionEventId = 'test_reaction_event_id_1234567890abcdef';

    setUpAll(() {
      registerFallbackValue(MockEvent());
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(
        LikeRecord(
          targetEventId: '',
          reactionEventId: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockLocalStorage = MockLikesLocalStorage();

      // Default mock behaviors
      when(() => mockNostrClient.publicKey).thenReturn(testUserPubkey);
      when(
        () => mockLocalStorage.getAllLikeRecords(),
      ).thenAnswer((_) async => []);
      when(
        () => mockLocalStorage.watchLikedEventIds(),
      ).thenAnswer((_) => Stream.value(<String>{}));
      // Default: not liked, no record found
      when(
        () => mockLocalStorage.isLiked(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockLocalStorage.getLikeRecord(any()),
      ).thenAnswer((_) async => null);
    });

    tearDown(() {
      repository.dispose();
    });

    group('constructor', () {
      test('creates repository without local storage', () {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
        );
        expect(repository, isNotNull);
      });

      test('creates repository with local storage', () {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );
        expect(repository, isNotNull);
      });
    });

    group('isLiked', () {
      test('returns false when event is not liked', () async {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.isLiked(testEventId);
        expect(result, isFalse);
      });

      test('returns true when event is liked', () async {
        final likeRecord = LikeRecord(
          targetEventId: testEventId,
          reactionEventId: testReactionEventId,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [likeRecord]);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.isLiked(testEventId);
        expect(result, isTrue);
      });
    });

    group('getLikedEventIds', () {
      test('returns empty set when no likes', () async {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikedEventIds();
        expect(result, isEmpty);
      });

      test('returns set of liked event IDs', () async {
        final likeRecords = [
          LikeRecord(
            targetEventId: 'event1',
            reactionEventId: 'reaction1',
            createdAt: DateTime.now(),
          ),
          LikeRecord(
            targetEventId: 'event2',
            reactionEventId: 'reaction2',
            createdAt: DateTime.now(),
          ),
        ];

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => likeRecords);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikedEventIds();
        expect(result, containsAll(['event1', 'event2']));
        expect(result.length, equals(2));
      });
    });

    group('getOrderedLikedEventIds', () {
      test('returns empty list when no likes', () async {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getOrderedLikedEventIds();
        expect(result, isEmpty);
      });

      test('returns event IDs ordered by createdAt descending', () async {
        final oldestTime = DateTime(2024, 1, 1, 10);
        final middleTime = DateTime(2024, 1, 1, 12);
        final newestTime = DateTime(2024, 1, 1, 14);

        final likeRecords = [
          LikeRecord(
            targetEventId: 'oldest_event_id_1234567890abcdef',
            reactionEventId: 'reaction_oldest_1234567890abcdef',
            createdAt: oldestTime,
          ),
          LikeRecord(
            targetEventId: 'newest_event_id_1234567890abcdef',
            reactionEventId: 'reaction_newest_1234567890abcdef',
            createdAt: newestTime,
          ),
          LikeRecord(
            targetEventId: 'middle_event_id_1234567890abcdef',
            reactionEventId: 'reaction_middle_1234567890abcdef',
            createdAt: middleTime,
          ),
        ];

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => likeRecords);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getOrderedLikedEventIds();

        expect(result.length, equals(3));
        expect(result[0], equals('newest_event_id_1234567890abcdef'));
        expect(result[1], equals('middle_event_id_1234567890abcdef'));
        expect(result[2], equals('oldest_event_id_1234567890abcdef'));
      });

      test('returns single event ID when only one like exists', () async {
        final likeRecords = [
          LikeRecord(
            targetEventId: 'single_event_id_1234567890abcdef',
            reactionEventId: 'reaction_single_1234567890abcdef',
            createdAt: DateTime.now(),
          ),
        ];

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => likeRecords);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getOrderedLikedEventIds();

        expect(result.length, equals(1));
        expect(result[0], equals('single_event_id_1234567890abcdef'));
      });

      test('handles records with identical timestamps', () async {
        final sameTime = DateTime(2024, 1, 1, 12);

        final likeRecords = [
          LikeRecord(
            targetEventId: 'event_a_id_1234567890abcdef0123',
            reactionEventId: 'reaction_a_1234567890abcdef0123',
            createdAt: sameTime,
          ),
          LikeRecord(
            targetEventId: 'event_b_id_1234567890abcdef0123',
            reactionEventId: 'reaction_b_1234567890abcdef0123',
            createdAt: sameTime,
          ),
        ];

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => likeRecords);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getOrderedLikedEventIds();

        expect(result.length, equals(2));
        expect(
          result,
          containsAll([
            'event_a_id_1234567890abcdef0123',
            'event_b_id_1234567890abcdef0123',
          ]),
        );
      });

      test('works without local storage', () async {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
        );

        final result = await repository.getOrderedLikedEventIds();
        expect(result, isEmpty);
      });
    });

    group('likeEvent', () {
      test('publishes like reaction and stores record', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);

        when(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
          ),
        ).thenAnswer((_) async => mockEvent);

        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, equals(testReactionEventId));
        verify(
          () => mockNostrClient.sendLike(testEventId, content: '+'),
        ).called(1);
        verify(() => mockLocalStorage.saveLikeRecord(any())).called(1);
      });

      test('throws LikeFailedException when publish fails', () async {
        when(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
          ),
        ).thenAnswer((_) async => null);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        expect(
          () => repository.likeEvent(
            eventId: testEventId,
            authorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<LikeFailedException>()),
        );
      });

      test('throws AlreadyLikedException when already liked', () async {
        final likeRecord = LikeRecord(
          targetEventId: testEventId,
          reactionEventId: testReactionEventId,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [likeRecord]);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // First call to initialize
        await repository.isLiked(testEventId);

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
        final likeRecord = LikeRecord(
          targetEventId: testEventId,
          reactionEventId: testReactionEventId,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [likeRecord]);

        final mockDeletionEvent = MockEvent();
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => mockDeletionEvent);

        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // Initialize to load the like record
        await repository.isLiked(testEventId);

        await repository.unlikeEvent(testEventId);

        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
        verify(() => mockLocalStorage.deleteLikeRecord(testEventId)).called(1);
      });

      test('throws NotLikedException when not liked', () async {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        expect(
          () => repository.unlikeEvent(testEventId),
          throwsA(isA<NotLikedException>()),
        );
      });

      test('throws UnlikeFailedException when deletion fails', () async {
        final likeRecord = LikeRecord(
          targetEventId: testEventId,
          reactionEventId: testReactionEventId,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [likeRecord]);

        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => null);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // Initialize
        await repository.isLiked(testEventId);

        expect(
          () => repository.unlikeEvent(testEventId),
          throwsA(isA<UnlikeFailedException>()),
        );
      });

      test('falls back to database when record not in memory cache', () async {
        final likeRecord = LikeRecord(
          targetEventId: testEventId,
          reactionEventId: testReactionEventId,
          createdAt: DateTime.now(),
        );

        // getAllLikeRecords returns empty (cache not populated)
        // but getLikeRecord returns the record from database
        when(
          () => mockLocalStorage.getLikeRecord(testEventId),
        ).thenAnswer((_) async => likeRecord);

        final mockDeletionEvent = MockEvent();
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => mockDeletionEvent);

        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // Don't call isLiked first, go directly to unlike
        await repository.unlikeEvent(testEventId);

        verify(() => mockLocalStorage.getLikeRecord(testEventId)).called(1);
        verify(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).called(1);
        verify(() => mockLocalStorage.deleteLikeRecord(testEventId)).called(1);
      });
    });

    group('toggleLike', () {
      test('likes when not liked and returns true', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);

        when(
          () => mockNostrClient.sendLike(
            testEventId,
            content: '+',
          ),
        ).thenAnswer((_) async => mockEvent);

        when(
          () => mockLocalStorage.saveLikeRecord(any()),
        ).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.toggleLike(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, isTrue);
      });

      test('unlikes when liked and returns false', () async {
        final likeRecord = LikeRecord(
          targetEventId: testEventId,
          reactionEventId: testReactionEventId,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [likeRecord]);

        // Mock isLiked to return true since toggleLike queries DB directly
        when(
          () => mockLocalStorage.isLiked(testEventId),
        ).thenAnswer((_) async => true);

        final mockDeletionEvent = MockEvent();
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => mockDeletionEvent);

        when(
          () => mockLocalStorage.deleteLikeRecord(testEventId),
        ).thenAnswer((_) async => true);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // Initialize
        await repository.isLiked(testEventId);

        final result = await repository.toggleLike(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, isFalse);
      });

      test('uses in-memory cache when no localStorage', () async {
        final mockEvent = MockEvent();
        when(() => mockEvent.id).thenReturn(testReactionEventId);

        when(
          () => mockNostrClient.sendLike(testEventId, content: '+'),
        ).thenAnswer((_) async => mockEvent);

        final mockDeletionEvent = MockEvent();
        when(
          () => mockNostrClient.deleteEvent(testReactionEventId),
        ).thenAnswer((_) async => mockDeletionEvent);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          // No localStorage
        );

        // Like the event first (adds to in-memory cache)
        await repository.likeEvent(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        // Toggle should unlike since it's in memory cache
        final result = await repository.toggleLike(
          eventId: testEventId,
          authorPubkey: testAuthorPubkey,
        );

        expect(result, isFalse);
      });
    });

    group('getLikeCount', () {
      test('queries relay for like count', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 42),
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikeCount(testEventId);

        expect(result, equals(42));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });
    });

    group('getLikeCounts', () {
      test('returns empty map for empty input', () async {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikeCounts([]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test(
        'queries relay for multiple event counts in single request',
        () async {
          const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';
          const eventId2 = 'event_id_2_1234567890abcdef01234567890abcdef';
          const eventId3 = 'event_id_3_1234567890abcdef01234567890abcdef';

          // Create mock reaction events with 'e' tags pointing to target events
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

          repository = LikesRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          final result = await repository.getLikeCounts([
            eventId1,
            eventId2,
            eventId3,
          ]);

          expect(result[eventId1], equals(2));
          expect(result[eventId2], equals(1));
          expect(result[eventId3], equals(0));
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        },
      );

      test('initializes all event IDs to zero', () async {
        const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';
        const eventId2 = 'event_id_2_1234567890abcdef01234567890abcdef';

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [],
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikeCounts([eventId1, eventId2]);

        expect(result[eventId1], equals(0));
        expect(result[eventId2], equals(0));
      });

      test('ignores reactions to events not in request', () async {
        const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';
        const otherEventId = 'other_event_1234567890abcdef01234567890abc';

        final mockReaction = MockEvent();
        when(() => mockReaction.tags).thenReturn([
          ['e', otherEventId],
        ]);

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [mockReaction],
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikeCounts([eventId1]);

        expect(result[eventId1], equals(0));
        expect(result.containsKey(otherEventId), isFalse);
      });

      test('handles events with non-list tags', () async {
        const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';

        final mockReaction = MockEvent();
        // Return tags with non-list items to test the `tag is List` check
        when(() => mockReaction.tags).thenReturn(['not_a_list']);

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [mockReaction],
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikeCounts([eventId1]);

        expect(result[eventId1], equals(0));
      });

      test('handles events with empty tags', () async {
        const eventId1 = 'event_id_1_1234567890abcdef01234567890abcdef';

        final mockReaction = MockEvent();
        when(() => mockReaction.tags).thenReturn([]);

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [mockReaction],
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikeCounts([eventId1]);

        expect(result[eventId1], equals(0));
      });
    });

    group('syncUserReactions', () {
      test('fetches reactions from relay and stores locally', () async {
        const targetEventId = 'target_event_1234567890abcdef';
        const reactionEventId = 'reaction_event_1234567890abcdef';
        const reactionCreatedAt = 1700000000;

        final mockReactionEvent = MockEvent();
        when(() => mockReactionEvent.id).thenReturn(reactionEventId);
        when(() => mockReactionEvent.content).thenReturn('+');
        when(() => mockReactionEvent.createdAt).thenReturn(reactionCreatedAt);
        when(() => mockReactionEvent.tags).thenReturn([
          ['e', targetEventId],
        ]);

        // First call returns reactions, second returns deletions (empty)
        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return [mockReactionEvent];
          }
          return []; // No deletions
        });

        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, contains(targetEventId));
        expect(
          result.eventIdToReactionId[targetEventId],
          equals(reactionEventId),
        );
        verify(() => mockLocalStorage.saveLikeRecordsBatch(any())).called(1);
      });

      test('filters out deleted reactions using Kind 5 events', () async {
        const targetEventId1 = 'target_event_1_1234567890abcdef';
        const reactionEventId1 = 'reaction_event_1_1234567890abcdef';
        const targetEventId2 = 'target_event_2_1234567890abcdef';
        const reactionEventId2 = 'reaction_event_2_1234567890abcdef';
        const reactionCreatedAt = 1700000000;

        // Two reaction events
        final mockReaction1 = MockEvent();
        when(() => mockReaction1.id).thenReturn(reactionEventId1);
        when(() => mockReaction1.content).thenReturn('+');
        when(() => mockReaction1.createdAt).thenReturn(reactionCreatedAt);
        when(() => mockReaction1.tags).thenReturn([
          ['e', targetEventId1],
        ]);

        final mockReaction2 = MockEvent();
        when(() => mockReaction2.id).thenReturn(reactionEventId2);
        when(() => mockReaction2.content).thenReturn('+');
        when(() => mockReaction2.createdAt).thenReturn(reactionCreatedAt);
        when(() => mockReaction2.tags).thenReturn([
          ['e', targetEventId2],
        ]);

        // Deletion event for reaction1
        final mockDeletion = MockEvent();
        when(() => mockDeletion.tags).thenReturn([
          ['e', reactionEventId1], // References the deleted reaction
        ]);

        // First call returns reactions, second returns deletions
        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return [mockReaction1, mockReaction2];
          }
          return [mockDeletion];
        });

        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReactions();

        // Only reaction2 should remain (reaction1 was deleted)
        expect(result.orderedEventIds, contains(targetEventId2));
        expect(result.orderedEventIds, isNot(contains(targetEventId1)));
        expect(result.eventIdToReactionId.containsKey(targetEventId2), isTrue);
        expect(
          result.eventIdToReactionId.containsKey(targetEventId1),
          isFalse,
        );
      });

      test('removes deleted likes from local storage', () async {
        const targetEventId = 'target_event_1234567890abcdef';
        const reactionEventId = 'reaction_event_1234567890abcdef';
        const reactionCreatedAt = 1700000000;

        // Pre-existing like in local storage
        final existingRecord = LikeRecord(
          targetEventId: targetEventId,
          reactionEventId: reactionEventId,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            reactionCreatedAt * 1000,
          ),
        );

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [existingRecord]);

        // Reaction event from relay
        final mockReaction = MockEvent();
        when(() => mockReaction.id).thenReturn(reactionEventId);
        when(() => mockReaction.content).thenReturn('+');
        when(() => mockReaction.createdAt).thenReturn(reactionCreatedAt);
        when(() => mockReaction.tags).thenReturn([
          ['e', targetEventId],
        ]);

        // Deletion event that deletes this reaction
        final mockDeletion = MockEvent();
        when(() => mockDeletion.tags).thenReturn([
          ['e', reactionEventId],
        ]);

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return [mockReaction];
          }
          return [mockDeletion];
        });

        when(
          () => mockLocalStorage.deleteLikeRecord(targetEventId),
        ).thenAnswer((_) async => true);

        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.syncUserReactions();

        // Should have deleted the local record
        verify(
          () => mockLocalStorage.deleteLikeRecord(targetEventId),
        ).called(1);
      });

      test('ignores non-like reactions (content != "+")', () async {
        const targetEventId = 'target_event_1234567890abcdef';
        const reactionEventId = 'reaction_event_1234567890abcdef';
        const reactionCreatedAt = 1700000000;

        final mockReaction = MockEvent();
        when(() => mockReaction.id).thenReturn(reactionEventId);
        when(() => mockReaction.content).thenReturn('-'); // Dislike, not like
        when(() => mockReaction.createdAt).thenReturn(reactionCreatedAt);
        when(() => mockReaction.tags).thenReturn([
          ['e', targetEventId],
        ]);

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return [mockReaction];
          }
          return [];
        });

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, isEmpty);
      });

      test('handles empty relay response', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [],
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReactions();

        expect(result.orderedEventIds, isEmpty);
        expect(result.eventIdToReactionId, isEmpty);
      });

      test('falls back to local data when relay query fails', () async {
        final existingRecord = LikeRecord(
          targetEventId: 'local_target_event_1234567890abcdef',
          reactionEventId: 'local_reaction_event_1234567890abcdef',
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [existingRecord]);

        when(() => mockNostrClient.queryEvents(any())).thenThrow(
          Exception('Network error'),
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReactions();

        // Should still have local data
        expect(
          result.orderedEventIds,
          contains('local_target_event_1234567890abcdef'),
        );
      });

      test(
        'throws SyncFailedException when relay fails and no local data',
        () async {
          when(() => mockNostrClient.queryEvents(any())).thenThrow(
            Exception('Network error'),
          );

          repository = LikesRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          expect(
            () => repository.syncUserReactions(),
            throwsA(isA<SyncFailedException>()),
          );
        },
      );

      test('handles continuous like/unlike cycles correctly', () async {
        // Simulates: like → unlike → like again
        // relay has: reaction1 (deleted), reaction2 (active)
        const targetEventId = 'target_event_1234567890abcdef';
        const reactionEventId1 = 'reaction_1_1234567890abcdef';
        const reactionEventId2 = 'reaction_2_1234567890abcdef';
        const reactionCreatedAt1 = 1700000000;
        const reactionCreatedAt2 = 1700000100;

        // First like (now deleted)
        final mockReaction1 = MockEvent();
        when(() => mockReaction1.id).thenReturn(reactionEventId1);
        when(() => mockReaction1.content).thenReturn('+');
        when(() => mockReaction1.createdAt).thenReturn(reactionCreatedAt1);
        when(() => mockReaction1.tags).thenReturn([
          ['e', targetEventId],
        ]);

        // Second like (still active)
        final mockReaction2 = MockEvent();
        when(() => mockReaction2.id).thenReturn(reactionEventId2);
        when(() => mockReaction2.content).thenReturn('+');
        when(() => mockReaction2.createdAt).thenReturn(reactionCreatedAt2);
        when(() => mockReaction2.tags).thenReturn([
          ['e', targetEventId],
        ]);

        // Deletion for first reaction only
        final mockDeletion = MockEvent();
        when(() => mockDeletion.tags).thenReturn([
          ['e', reactionEventId1],
        ]);

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return [mockReaction1, mockReaction2];
          }
          return [mockDeletion];
        });

        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReactions();

        // Should have the target event (from reaction2, the newer active one)
        expect(result.orderedEventIds, contains(targetEventId));
        expect(
          result.eventIdToReactionId[targetEventId],
          equals(reactionEventId2),
        );
      });

      test('handles deletion events with multiple e tags', () async {
        const targetEventId1 = 'target_1_1234567890abcdef';
        const reactionEventId1 = 'reaction_1_1234567890abcdef';
        const targetEventId2 = 'target_2_1234567890abcdef';
        const reactionEventId2 = 'reaction_2_1234567890abcdef';
        const reactionCreatedAt = 1700000000;

        final mockReaction1 = MockEvent();
        when(() => mockReaction1.id).thenReturn(reactionEventId1);
        when(() => mockReaction1.content).thenReturn('+');
        when(() => mockReaction1.createdAt).thenReturn(reactionCreatedAt);
        when(() => mockReaction1.tags).thenReturn([
          ['e', targetEventId1],
        ]);

        final mockReaction2 = MockEvent();
        when(() => mockReaction2.id).thenReturn(reactionEventId2);
        when(() => mockReaction2.content).thenReturn('+');
        when(() => mockReaction2.createdAt).thenReturn(reactionCreatedAt);
        when(() => mockReaction2.tags).thenReturn([
          ['e', targetEventId2],
        ]);

        // Single deletion event that deletes both reactions
        final mockDeletion = MockEvent();
        when(() => mockDeletion.tags).thenReturn([
          ['e', reactionEventId1],
          ['e', reactionEventId2],
        ]);

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return [mockReaction1, mockReaction2];
          }
          return [mockDeletion];
        });

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReactions();

        // Both should be filtered out
        expect(result.orderedEventIds, isEmpty);
      });

      test('updates newer record when duplicate target events exist', () async {
        const targetEventId = 'target_event_1234567890abcdef';
        const olderReactionId = 'older_reaction_1234567890abcdef';
        const newerReactionId = 'newer_reaction_1234567890abcdef';
        const olderCreatedAt = 1700000000;
        const newerCreatedAt = 1700000100;

        // Older reaction
        final mockOlderReaction = MockEvent();
        when(() => mockOlderReaction.id).thenReturn(olderReactionId);
        when(() => mockOlderReaction.content).thenReturn('+');
        when(() => mockOlderReaction.createdAt).thenReturn(olderCreatedAt);
        when(() => mockOlderReaction.tags).thenReturn([
          ['e', targetEventId],
        ]);

        // Newer reaction to same target
        final mockNewerReaction = MockEvent();
        when(() => mockNewerReaction.id).thenReturn(newerReactionId);
        when(() => mockNewerReaction.content).thenReturn('+');
        when(() => mockNewerReaction.createdAt).thenReturn(newerCreatedAt);
        when(() => mockNewerReaction.tags).thenReturn([
          ['e', targetEventId],
        ]);

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            // Return older first, then newer
            return [mockOlderReaction, mockNewerReaction];
          }
          return [];
        });

        when(
          () => mockLocalStorage.saveLikeRecordsBatch(any()),
        ).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReactions();

        // Should use the newer reaction ID
        expect(
          result.eventIdToReactionId[targetEventId],
          equals(newerReactionId),
        );
      });
    });

    group('fetchUserLikes', () {
      test('fetches likes for another user from relay', () async {
        const otherUserPubkey = 'other_user_pubkey_1234567890abcdef';
        const targetEventId = 'target_event_1234567890abcdef';

        final mockReaction = MockEvent();
        when(() => mockReaction.content).thenReturn('+');
        when(() => mockReaction.createdAt).thenReturn(1700000000);
        when(() => mockReaction.tags).thenReturn([
          ['e', targetEventId],
        ]);

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [mockReaction],
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.fetchUserLikes(otherUserPubkey);

        expect(result, contains(targetEventId));
      });

      test('returns likes ordered by recency', () async {
        const otherUserPubkey = 'other_user_pubkey_1234567890abcdef';
        const olderTargetId = 'older_target_1234567890abcdef';
        const newerTargetId = 'newer_target_1234567890abcdef';

        final mockOlderReaction = MockEvent();
        when(() => mockOlderReaction.content).thenReturn('+');
        when(() => mockOlderReaction.createdAt).thenReturn(1700000000);
        when(() => mockOlderReaction.tags).thenReturn([
          ['e', olderTargetId],
        ]);

        final mockNewerReaction = MockEvent();
        when(() => mockNewerReaction.content).thenReturn('+');
        when(() => mockNewerReaction.createdAt).thenReturn(1700000100);
        when(() => mockNewerReaction.tags).thenReturn([
          ['e', newerTargetId],
        ]);

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [mockOlderReaction, mockNewerReaction],
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.fetchUserLikes(otherUserPubkey);

        expect(result[0], equals(newerTargetId));
        expect(result[1], equals(olderTargetId));
      });

      test('deduplicates target event IDs', () async {
        const otherUserPubkey = 'other_user_pubkey_1234567890abcdef';
        const targetEventId = 'target_event_1234567890abcdef';

        // Two reactions to the same target (e.g., from like/unlike/like cycle)
        final mockReaction1 = MockEvent();
        when(() => mockReaction1.content).thenReturn('+');
        when(() => mockReaction1.createdAt).thenReturn(1700000000);
        when(() => mockReaction1.tags).thenReturn([
          ['e', targetEventId],
        ]);

        final mockReaction2 = MockEvent();
        when(() => mockReaction2.content).thenReturn('+');
        when(() => mockReaction2.createdAt).thenReturn(1700000100);
        when(() => mockReaction2.tags).thenReturn([
          ['e', targetEventId],
        ]);

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [mockReaction1, mockReaction2],
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.fetchUserLikes(otherUserPubkey);

        // Should only have one entry for the target
        expect(result.length, equals(1));
        expect(result[0], equals(targetEventId));
      });

      test('ignores non-like reactions', () async {
        const otherUserPubkey = 'other_user_pubkey_1234567890abcdef';
        const targetEventId = 'target_event_1234567890abcdef';

        final mockReaction = MockEvent();
        when(() => mockReaction.content).thenReturn('-'); // Dislike
        when(() => mockReaction.createdAt).thenReturn(1700000000);
        when(() => mockReaction.tags).thenReturn([
          ['e', targetEventId],
        ]);

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [mockReaction],
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.fetchUserLikes(otherUserPubkey);

        expect(result, isEmpty);
      });

      test('throws FetchLikesFailedException on error', () async {
        const otherUserPubkey = 'other_user_pubkey_1234567890abcdef';

        when(() => mockNostrClient.queryEvents(any())).thenThrow(
          Exception('Network error'),
        );

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        expect(
          () => repository.fetchUserLikes(otherUserPubkey),
          throwsA(isA<FetchLikesFailedException>()),
        );
      });
    });

    group('getLikeRecord', () {
      test('returns record when event is liked', () async {
        final likeRecord = LikeRecord(
          targetEventId: testEventId,
          reactionEventId: testReactionEventId,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllLikeRecords(),
        ).thenAnswer((_) async => [likeRecord]);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikeRecord(testEventId);

        expect(result, isNotNull);
        expect(result!.targetEventId, equals(testEventId));
        expect(result.reactionEventId, equals(testReactionEventId));
      });

      test('returns null when event is not liked', () async {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.getLikeRecord('nonexistent_event_id');

        expect(result, isNull);
      });
    });

    group('clearCache', () {
      test('clears local storage and in-memory cache', () async {
        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.clearCache();

        verify(() => mockLocalStorage.clearAll()).called(1);

        final likedIds = await repository.getLikedEventIds();
        expect(likedIds, isEmpty);
      });
    });

    group('watchLikedEventIds', () {
      test('returns stream from local storage when available', () async {
        final testStream = Stream.value(<String>{'event1', 'event2'});
        when(
          () => mockLocalStorage.watchLikedEventIds(),
        ).thenAnswer((_) => testStream);

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final stream = repository.watchLikedEventIds();
        final result = await stream.first;

        expect(result, containsAll(['event1', 'event2']));
      });

      test('returns internal stream when no local storage', () async {
        repository = LikesRepository(
          nostrClient: mockNostrClient,
        );

        final stream = repository.watchLikedEventIds();
        final result = await stream.first;

        expect(result, isEmpty);
      });
    });

    group('auth state changes', () {
      test('clears cache when user logs out', () async {
        final authController = StreamController<bool>.broadcast();

        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          authStateStream: authController.stream,
          isAuthenticated: true,
        );

        // Simulate logout
        authController.add(false);

        // Give time for the stream to process
        await Future<void>.delayed(Duration.zero);

        verify(() => mockLocalStorage.clearAll()).called(1);

        await authController.close();
      });

      test('does not clear cache when auth state unchanged', () async {
        final authController = StreamController<bool>.broadcast();

        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          authStateStream: authController.stream,
        );

        // Send same state
        authController.add(false);

        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockLocalStorage.clearAll());

        await authController.close();
      });

      test('marks as not initialized when user logs in', () async {
        final authController = StreamController<bool>.broadcast();

        when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});

        repository = LikesRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          authStateStream: authController.stream,
        );

        // Initialize the repository
        await repository.getLikedEventIds();

        // Simulate login
        authController.add(true);

        // Give time for the stream to process
        await Future<void>.delayed(Duration.zero);

        // clearAll should NOT be called on login
        verifyNever(() => mockLocalStorage.clearAll());

        await authController.close();
      });
    });
  });
}

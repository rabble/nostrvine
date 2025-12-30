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
    });
  });

  group('LikeRecord', () {
    test('equals works correctly', () {
      final now = DateTime.now();
      final record1 = LikeRecord(
        targetEventId: 'target1',
        reactionEventId: 'reaction1',
        createdAt: now,
      );
      final record2 = LikeRecord(
        targetEventId: 'target1',
        reactionEventId: 'reaction1',
        createdAt: now,
      );
      final record3 = LikeRecord(
        targetEventId: 'target2',
        reactionEventId: 'reaction1',
        createdAt: now,
      );

      expect(record1, equals(record2));
      expect(record1, isNot(equals(record3)));
    });

    test('copyWith works correctly', () {
      final now = DateTime.now();
      final record = LikeRecord(
        targetEventId: 'target1',
        reactionEventId: 'reaction1',
        createdAt: now,
      );

      final copied = record.copyWith(targetEventId: 'target2');

      expect(copied.targetEventId, equals('target2'));
      expect(copied.reactionEventId, equals('reaction1'));
      expect(copied.createdAt, equals(now));
    });

    test('toString returns expected format', () {
      final now = DateTime.now();
      final record = LikeRecord(
        targetEventId: 'target1',
        reactionEventId: 'reaction1',
        createdAt: now,
      );

      final str = record.toString();
      expect(str, contains('LikeRecord'));
      expect(str, contains('target1'));
      expect(str, contains('reaction1'));
    });
  });

  group('Exceptions', () {
    test('LikeFailedException has correct message', () {
      const exception = LikeFailedException('test message');
      expect(exception.message, equals('test message'));
      expect(exception.toString(), contains('LikeFailedException'));
    });

    test('UnlikeFailedException has correct message', () {
      const exception = UnlikeFailedException('test message');
      expect(exception.message, equals('test message'));
      expect(exception.toString(), contains('UnlikeFailedException'));
    });

    test('NotAuthenticatedException has default message', () {
      const exception = NotAuthenticatedException();
      expect(exception.message, equals('User not authenticated'));
    });

    test('AlreadyLikedException includes event ID', () {
      const exception = AlreadyLikedException('event123');
      expect(exception.message, contains('event123'));
    });

    test('NotLikedException includes event ID', () {
      const exception = NotLikedException('event123');
      expect(exception.message, contains('event123'));
    });
  });
}

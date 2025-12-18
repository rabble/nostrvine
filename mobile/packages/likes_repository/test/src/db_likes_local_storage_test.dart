// ABOUTME: Unit tests for DbLikesLocalStorage implementation.
// ABOUTME: Tests the db_client-backed local storage for like records.

// Null safety ignore for test files
// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockPersonalReactionsDao extends Mock implements PersonalReactionsDao {}

void main() {
  group('DbLikesLocalStorage', () {
    late MockPersonalReactionsDao mockDao;
    late DbLikesLocalStorage storage;

    /// Valid 64-char hex pubkey for testing
    const testUserPubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    /// Valid 64-char hex event IDs for testing
    const testTargetEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testTargetEventId2 =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const testReactionEventId =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const testReactionEventId2 =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

    setUpAll(() {
      registerFallbackValue(
        PersonalReactionRow(
          targetEventId: '',
          reactionEventId: '',
          userPubkey: '',
          createdAt: 0,
        ),
      );
      registerFallbackValue(<PersonalReactionRow>[]);
    });

    setUp(() {
      mockDao = MockPersonalReactionsDao();
      storage = DbLikesLocalStorage(
        dao: mockDao,
        userPubkey: testUserPubkey,
      );
    });

    group('constructor', () {
      test('creates storage with dao and userPubkey', () {
        final storage = DbLikesLocalStorage(
          dao: mockDao,
          userPubkey: testUserPubkey,
        );
        expect(storage, isNotNull);
      });
    });

    group('saveLikeRecord', () {
      test('calls dao.upsertReaction with correct parameters', () async {
        when(
          () => mockDao.upsertReaction(
            targetEventId: any(named: 'targetEventId'),
            reactionEventId: any(named: 'reactionEventId'),
            userPubkey: any(named: 'userPubkey'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) async {});

        final now = DateTime.now();
        final record = LikeRecord(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          createdAt: now,
        );

        await storage.saveLikeRecord(record);

        verify(
          () => mockDao.upsertReaction(
            targetEventId: testTargetEventId,
            reactionEventId: testReactionEventId,
            userPubkey: testUserPubkey,
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
          ),
        ).called(1);
      });
    });

    group('saveLikeRecordsBatch', () {
      test('calls dao.upsertReactionsBatch with converted rows', () async {
        when(
          () => mockDao.upsertReactionsBatch(any()),
        ).thenAnswer((_) async {});

        final now = DateTime.now();
        final records = [
          LikeRecord(
            targetEventId: testTargetEventId,
            reactionEventId: testReactionEventId,
            createdAt: now,
          ),
          LikeRecord(
            targetEventId: testTargetEventId2,
            reactionEventId: testReactionEventId2,
            createdAt: now,
          ),
        ];

        await storage.saveLikeRecordsBatch(records);

        final captured = verify(
          () => mockDao.upsertReactionsBatch(captureAny()),
        ).captured;
        expect(captured.length, equals(1));

        final rows = captured.first as List<PersonalReactionRow>;
        expect(rows.length, equals(2));
        expect(rows[0].targetEventId, equals(testTargetEventId));
        expect(rows[0].reactionEventId, equals(testReactionEventId));
        expect(rows[0].userPubkey, equals(testUserPubkey));
        expect(rows[1].targetEventId, equals(testTargetEventId2));
        expect(rows[1].reactionEventId, equals(testReactionEventId2));
      });

      test('does not call dao when records list is empty', () async {
        await storage.saveLikeRecordsBatch([]);

        verifyNever(() => mockDao.upsertReactionsBatch(any()));
      });
    });

    group('deleteLikeRecord', () {
      test('returns true when deletion succeeds', () async {
        when(
          () => mockDao.deleteReaction(
            targetEventId: any(named: 'targetEventId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => 1);

        final result = await storage.deleteLikeRecord(testTargetEventId);

        expect(result, isTrue);
        verify(
          () => mockDao.deleteReaction(
            targetEventId: testTargetEventId,
            userPubkey: testUserPubkey,
          ),
        ).called(1);
      });

      test('returns false when no record exists', () async {
        when(
          () => mockDao.deleteReaction(
            targetEventId: any(named: 'targetEventId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => 0);

        final result = await storage.deleteLikeRecord(testTargetEventId);

        expect(result, isFalse);
      });
    });

    group('getLikeRecord', () {
      test('returns LikeRecord when found', () async {
        final row = PersonalReactionRow(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        when(
          () => mockDao.getReaction(
            targetEventId: any(named: 'targetEventId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => row);

        final result = await storage.getLikeRecord(testTargetEventId);

        expect(result, isNotNull);
        expect(result!.targetEventId, equals(testTargetEventId));
        expect(result.reactionEventId, equals(testReactionEventId));
        expect(
          result.createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(1000 * 1000)),
        );
      });

      test('returns null when not found', () async {
        when(
          () => mockDao.getReaction(
            targetEventId: any(named: 'targetEventId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final result = await storage.getLikeRecord(testTargetEventId);

        expect(result, isNull);
      });
    });

    group('getReactionEventId', () {
      test('returns reaction event ID when liked', () async {
        when(
          () => mockDao.getReactionEventId(
            targetEventId: any(named: 'targetEventId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => testReactionEventId);

        final result = await storage.getReactionEventId(testTargetEventId);

        expect(result, equals(testReactionEventId));
        verify(
          () => mockDao.getReactionEventId(
            targetEventId: testTargetEventId,
            userPubkey: testUserPubkey,
          ),
        ).called(1);
      });

      test('returns null when not liked', () async {
        when(
          () => mockDao.getReactionEventId(
            targetEventId: any(named: 'targetEventId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final result = await storage.getReactionEventId(testTargetEventId);

        expect(result, isNull);
      });
    });

    group('getAllLikeRecords', () {
      test('returns converted LikeRecords', () async {
        final rows = [
          PersonalReactionRow(
            targetEventId: testTargetEventId,
            reactionEventId: testReactionEventId,
            userPubkey: testUserPubkey,
            createdAt: 1000,
          ),
          PersonalReactionRow(
            targetEventId: testTargetEventId2,
            reactionEventId: testReactionEventId2,
            userPubkey: testUserPubkey,
            createdAt: 2000,
          ),
        ];

        when(
          () => mockDao.getAllReactions(any()),
        ).thenAnswer((_) async => rows);

        final result = await storage.getAllLikeRecords();

        expect(result.length, equals(2));
        expect(result[0].targetEventId, equals(testTargetEventId));
        expect(result[0].reactionEventId, equals(testReactionEventId));
        expect(
          result[0].createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(1000 * 1000)),
        );
        expect(result[1].targetEventId, equals(testTargetEventId2));
        expect(result[1].reactionEventId, equals(testReactionEventId2));
        expect(
          result[1].createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(2000 * 1000)),
        );

        verify(() => mockDao.getAllReactions(testUserPubkey)).called(1);
      });

      test('returns empty list when no records', () async {
        when(() => mockDao.getAllReactions(any())).thenAnswer((_) async => []);

        final result = await storage.getAllLikeRecords();

        expect(result, isEmpty);
      });
    });

    group('getLikedEventIds', () {
      test('returns set of liked event IDs', () async {
        when(() => mockDao.getLikedEventIds(any())).thenAnswer(
          (_) async => {testTargetEventId, testTargetEventId2},
        );

        final result = await storage.getLikedEventIds();

        expect(result.length, equals(2));
        expect(result, containsAll([testTargetEventId, testTargetEventId2]));
        verify(() => mockDao.getLikedEventIds(testUserPubkey)).called(1);
      });

      test('returns empty set when no likes', () async {
        when(() => mockDao.getLikedEventIds(any())).thenAnswer(
          (_) async => <String>{},
        );

        final result = await storage.getLikedEventIds();

        expect(result, isEmpty);
      });
    });

    group('isLiked', () {
      test('returns true when event is liked', () async {
        when(
          () => mockDao.isLiked(
            targetEventId: any(named: 'targetEventId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => true);

        final result = await storage.isLiked(testTargetEventId);

        expect(result, isTrue);
        verify(
          () => mockDao.isLiked(
            targetEventId: testTargetEventId,
            userPubkey: testUserPubkey,
          ),
        ).called(1);
      });

      test('returns false when event is not liked', () async {
        when(
          () => mockDao.isLiked(
            targetEventId: any(named: 'targetEventId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => false);

        final result = await storage.isLiked(testTargetEventId);

        expect(result, isFalse);
      });
    });

    group('watchLikedEventIds', () {
      test('returns stream from dao', () async {
        final controller = StreamController<Set<String>>();
        when(
          () => mockDao.watchLikedEventIds(any()),
        ).thenAnswer((_) => controller.stream);

        final stream = storage.watchLikedEventIds();

        // Add values to controller
        controller
          ..add({testTargetEventId})
          ..add({testTargetEventId, testTargetEventId2});

        final emissions = await stream.take(2).toList();

        expect(emissions[0], equals({testTargetEventId}));
        expect(
          emissions[1],
          equals({testTargetEventId, testTargetEventId2}),
        );

        verify(() => mockDao.watchLikedEventIds(testUserPubkey)).called(1);

        await controller.close();
      });
    });

    group('clearAll', () {
      test('calls dao.deleteAllForUser', () async {
        when(() => mockDao.deleteAllForUser(any())).thenAnswer((_) async => 5);

        await storage.clearAll();

        verify(() => mockDao.deleteAllForUser(testUserPubkey)).called(1);
      });
    });

    group('timestamp conversion', () {
      test('converts DateTime to Unix timestamp correctly', () async {
        when(
          () => mockDao.upsertReaction(
            targetEventId: any(named: 'targetEventId'),
            reactionEventId: any(named: 'reactionEventId'),
            userPubkey: any(named: 'userPubkey'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((_) async {});

        // Use a specific timestamp to verify conversion
        final dateTime = DateTime.utc(2024, 1, 15, 12, 30, 45);
        final expectedUnix = dateTime.millisecondsSinceEpoch ~/ 1000;

        final record = LikeRecord(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          createdAt: dateTime,
        );

        await storage.saveLikeRecord(record);

        verify(
          () => mockDao.upsertReaction(
            targetEventId: testTargetEventId,
            reactionEventId: testReactionEventId,
            userPubkey: testUserPubkey,
            createdAt: expectedUnix,
          ),
        ).called(1);
      });

      test('converts Unix timestamp to DateTime correctly', () async {
        const unixTimestamp = 1705322445; // 2024-01-15 12:00:45 UTC
        final expectedDateTime = DateTime.fromMillisecondsSinceEpoch(
          unixTimestamp * 1000,
        );

        final row = PersonalReactionRow(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: unixTimestamp,
        );

        when(
          () => mockDao.getReaction(
            targetEventId: any(named: 'targetEventId'),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => row);

        final result = await storage.getLikeRecord(testTargetEventId);

        expect(result, isNotNull);
        expect(result!.createdAt, equals(expectedDateTime));
      });
    });
  });
}

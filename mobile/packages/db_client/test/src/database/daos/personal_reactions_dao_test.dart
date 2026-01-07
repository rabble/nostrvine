// ABOUTME: Unit tests for PersonalReactionsDao with reaction record operations.
// ABOUTME: Tests all DAO methods including batch operations
// ABOUTME: and reactive streams.

// No need for const constructors in tests
// ignore_for_file: prefer_const_constructors

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PersonalReactionsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testUserPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const testUserPubkey2 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  /// Valid 64-char hex event IDs for testing
  const testTargetEventId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const testTargetEventId2 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const testTargetEventId3 =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const testReactionEventId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
  const testReactionEventId2 =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  const testReactionEventId3 =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.personalReactionsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('PersonalReactionsDao', () {
    group('upsertReaction', () {
      test('inserts a new reaction record', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(result, isNotNull);
        expect(result!.targetEventId, equals(testTargetEventId));
        expect(result.reactionEventId, equals(testReactionEventId));
        expect(result.userPubkey, equals(testUserPubkey));
        expect(result.createdAt, equals(1000));
      });

      test('updates existing reaction with same target and user', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        // Update with new reaction event ID
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final result = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(result, isNotNull);
        expect(result!.reactionEventId, equals(testReactionEventId2));
        expect(result.createdAt, equals(2000));
      });

      test('allows same target for different users', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result1 = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );
        final result2 = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey2,
        );

        expect(result1, isNotNull);
        expect(result2, isNotNull);
        expect(result1!.reactionEventId, equals(testReactionEventId));
        expect(result2!.reactionEventId, equals(testReactionEventId2));
      });
    });

    group('upsertReactionsBatch', () {
      test('inserts multiple reactions in a batch', () async {
        final reactions = [
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
          PersonalReactionRow(
            targetEventId: testTargetEventId3,
            reactionEventId: testReactionEventId3,
            userPubkey: testUserPubkey,
            createdAt: 3000,
          ),
        ];

        await dao.upsertReactionsBatch(reactions);

        final results = await dao.getAllReactions(testUserPubkey);
        expect(results.length, equals(3));
      });

      test('handles empty list gracefully', () async {
        await dao.upsertReactionsBatch([]);

        final results = await dao.getAllReactions(testUserPubkey);
        expect(results, isEmpty);
      });

      test('updates existing reactions in batch', () async {
        // Insert initial reaction
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        // Batch with updated and new reactions
        final reactions = [
          PersonalReactionRow(
            targetEventId: testTargetEventId,
            reactionEventId: testReactionEventId2, // Updated
            userPubkey: testUserPubkey,
            createdAt: 2000,
          ),
          PersonalReactionRow(
            targetEventId: testTargetEventId2,
            reactionEventId: testReactionEventId3,
            userPubkey: testUserPubkey,
            createdAt: 3000,
          ),
        ];

        await dao.upsertReactionsBatch(reactions);

        final results = await dao.getAllReactions(testUserPubkey);
        expect(results.length, equals(2));

        final updated = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );
        expect(updated!.reactionEventId, equals(testReactionEventId2));
      });
    });

    group('deleteReaction', () {
      test('deletes reaction by target event ID and user', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final deleted = await dao.deleteReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(deleted, equals(1));

        final result = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );
        expect(result, isNull);
      });

      test('returns 0 when reaction does not exist', () async {
        final deleted = await dao.deleteReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(deleted, equals(0));
      });

      test('only deletes reaction for specified user', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        await dao.deleteReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        final result1 = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );
        final result2 = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey2,
        );

        expect(result1, isNull);
        expect(result2, isNotNull);
      });
    });

    group('deleteByReactionEventId', () {
      test('deletes reaction by reaction event ID', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final deleted = await dao.deleteByReactionEventId(testReactionEventId);

        expect(deleted, equals(1));

        final result = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );
        expect(result, isNull);
      });

      test('returns 0 when reaction event ID does not exist', () async {
        final deleted = await dao.deleteByReactionEventId('nonexistent_id');

        expect(deleted, equals(0));
      });
    });

    group('getReactionEventId', () {
      test('returns reaction event ID when liked', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result = await dao.getReactionEventId(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(result, equals(testReactionEventId));
      });

      test('returns null when not liked', () async {
        final result = await dao.getReactionEventId(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(result, isNull);
      });

      test('returns correct ID for specific user', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result1 = await dao.getReactionEventId(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );
        final result2 = await dao.getReactionEventId(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey2,
        );

        expect(result1, equals(testReactionEventId));
        expect(result2, equals(testReactionEventId2));
      });
    });

    group('getLikedEventIds', () {
      test('returns empty set when no likes', () async {
        final result = await dao.getLikedEventIds(testUserPubkey);

        expect(result, isEmpty);
      });

      test('returns set of liked event IDs', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final result = await dao.getLikedEventIds(testUserPubkey);

        expect(result.length, equals(2));
        expect(result, containsAll([testTargetEventId, testTargetEventId2]));
      });

      test('only returns IDs for specified user', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result = await dao.getLikedEventIds(testUserPubkey);

        expect(result.length, equals(1));
        expect(result, contains(testTargetEventId));
        expect(result, isNot(contains(testTargetEventId2)));
      });
    });

    group('getAllReactions', () {
      test('returns empty list when no reactions', () async {
        final result = await dao.getAllReactions(testUserPubkey);

        expect(result, isEmpty);
      });

      test('returns all reactions for user sorted by createdAt desc', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey,
          createdAt: 3000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId3,
          reactionEventId: testReactionEventId3,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final result = await dao.getAllReactions(testUserPubkey);

        expect(result.length, equals(3));
        // Should be sorted by createdAt descending
        expect(result[0].createdAt, equals(3000));
        expect(result[1].createdAt, equals(2000));
        expect(result[2].createdAt, equals(1000));
      });

      test('only returns reactions for specified user', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result = await dao.getAllReactions(testUserPubkey);

        expect(result.length, equals(1));
        expect(result.first.userPubkey, equals(testUserPubkey));
      });
    });

    group('watchLikedEventIds', () {
      test('emits initial liked event IDs', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final stream = dao.watchLikedEventIds(testUserPubkey);
        final result = await stream.first;

        expect(result, contains(testTargetEventId));
      });

      test('emits updates when reactions are added', () async {
        final stream = dao.watchLikedEventIds(testUserPubkey);

        // Collect two emissions
        final emissionsFuture = stream.take(2).toList();

        // Wait for stream to be listening
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Add a reaction
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));
        expect(emissions[0], isEmpty);
        expect(emissions[1], contains(testTargetEventId));
      });

      test('emits updates when reactions are deleted', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final stream = dao.watchLikedEventIds(testUserPubkey);

        // Collect two emissions
        final emissionsFuture = stream.take(2).toList();

        // Wait for stream to be listening
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Delete the reaction
        await dao.deleteReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));
        expect(emissions[0], contains(testTargetEventId));
        expect(emissions[1], isEmpty);
      });
    });

    group('watchAllReactions', () {
      test('emits initial reactions sorted by createdAt desc', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final stream = dao.watchAllReactions(testUserPubkey);
        final result = await stream.first;

        expect(result.length, equals(2));
        expect(result[0].createdAt, equals(2000));
        expect(result[1].createdAt, equals(1000));
      });

      test('emits updates when reactions change', () async {
        final stream = dao.watchAllReactions(testUserPubkey);

        // Collect two emissions
        final emissionsFuture = stream.take(2).toList();

        // Wait for stream to be listening
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Add a reaction
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));
        expect(emissions[0], isEmpty);
        expect(emissions[1].length, equals(1));
      });
    });

    group('isLiked', () {
      test('returns true when event is liked', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result = await dao.isLiked(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(result, isTrue);
      });

      test('returns false when event is not liked', () async {
        final result = await dao.isLiked(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(result, isFalse);
      });

      test('returns correct status for specific user', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result1 = await dao.isLiked(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );
        final result2 = await dao.isLiked(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey2,
        );

        expect(result1, isTrue);
        expect(result2, isFalse);
      });
    });

    group('getLikeCount', () {
      test('returns 0 when no likes', () async {
        final result = await dao.getLikeCount(testUserPubkey);

        expect(result, equals(0));
      });

      test('returns correct count of likes', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId3,
          reactionEventId: testReactionEventId3,
          userPubkey: testUserPubkey,
          createdAt: 3000,
        );

        final result = await dao.getLikeCount(testUserPubkey);

        expect(result, equals(3));
      });

      test('only counts likes for specified user', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result = await dao.getLikeCount(testUserPubkey);

        expect(result, equals(1));
      });
    });

    group('deleteAllForUser', () {
      test('deletes all reactions for user', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final deleted = await dao.deleteAllForUser(testUserPubkey);

        expect(deleted, equals(2));

        final remaining = await dao.getAllReactions(testUserPubkey);
        expect(remaining, isEmpty);
      });

      test('does not delete reactions for other users', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        await dao.deleteAllForUser(testUserPubkey);

        final remaining = await dao.getAllReactions(testUserPubkey2);
        expect(remaining.length, equals(1));
      });

      test('returns 0 when no reactions exist', () async {
        final deleted = await dao.deleteAllForUser(testUserPubkey);

        expect(deleted, equals(0));
      });
    });

    group('deleteAll', () {
      test('deletes all reactions', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertReaction(
          targetEventId: testTargetEventId2,
          reactionEventId: testReactionEventId2,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final deleted = await dao.deleteAll();

        expect(deleted, equals(2));

        final remaining1 = await dao.getAllReactions(testUserPubkey);
        final remaining2 = await dao.getAllReactions(testUserPubkey2);
        expect(remaining1, isEmpty);
        expect(remaining2, isEmpty);
      });

      test('returns 0 when no reactions exist', () async {
        final deleted = await dao.deleteAll();

        expect(deleted, equals(0));
      });
    });

    group('getReaction', () {
      test('returns reaction record when found', () async {
        await dao.upsertReaction(
          targetEventId: testTargetEventId,
          reactionEventId: testReactionEventId,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(result, isNotNull);
        expect(result!.targetEventId, equals(testTargetEventId));
        expect(result.reactionEventId, equals(testReactionEventId));
        expect(result.userPubkey, equals(testUserPubkey));
        expect(result.createdAt, equals(1000));
      });

      test('returns null when not found', () async {
        final result = await dao.getReaction(
          targetEventId: testTargetEventId,
          userPubkey: testUserPubkey,
        );

        expect(result, isNull);
      });
    });
  });
}

// ABOUTME: Unit tests for PersonalRepostsDao with repost record operations.
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
  late PersonalRepostsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testUserPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const testUserPubkey2 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const testOriginalAuthorPubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';

  /// Valid addressable IDs for testing (format: 34236:pubkey:d-tag)
  const testAddressableId = '34236:$testOriginalAuthorPubkey:video1';
  const testAddressableId2 = '34236:$testOriginalAuthorPubkey:video2';
  const testAddressableId3 = '34236:$testOriginalAuthorPubkey:video3';

  /// Valid 64-char hex event IDs for testing
  const testRepostEventId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
  const testRepostEventId2 =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  const testRepostEventId3 =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.personalRepostsDao;
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

  group('PersonalRepostsDao', () {
    group('upsertRepost', () {
      test('inserts a new repost record', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        expect(result, isNotNull);
        expect(result!.addressableId, equals(testAddressableId));
        expect(result.repostEventId, equals(testRepostEventId));
        expect(result.originalAuthorPubkey, equals(testOriginalAuthorPubkey));
        expect(result.userPubkey, equals(testUserPubkey));
        expect(result.createdAt, equals(1000));
      });

      test(
        'updates existing repost with same addressable ID and user',
        () async {
          await dao.upsertRepost(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: 1000,
          );

          // Update with new repost event ID
          await dao.upsertRepost(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId2,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: 2000,
          );

          final result = await dao.getRepost(
            addressableId: testAddressableId,
            userPubkey: testUserPubkey,
          );

          expect(result, isNotNull);
          expect(result!.repostEventId, equals(testRepostEventId2));
          expect(result.createdAt, equals(2000));
        },
      );

      test('allows same addressable ID for different users', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result1 = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );
        final result2 = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey2,
        );

        expect(result1, isNotNull);
        expect(result2, isNotNull);
        expect(result1!.repostEventId, equals(testRepostEventId));
        expect(result2!.repostEventId, equals(testRepostEventId2));
      });
    });

    group('upsertRepostsBatch', () {
      test('inserts multiple reposts in a batch', () async {
        final reposts = [
          PersonalRepostRow(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: 1000,
          ),
          PersonalRepostRow(
            addressableId: testAddressableId2,
            repostEventId: testRepostEventId2,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: 2000,
          ),
          PersonalRepostRow(
            addressableId: testAddressableId3,
            repostEventId: testRepostEventId3,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: 3000,
          ),
        ];

        await dao.upsertRepostsBatch(reposts);

        final results = await dao.getAllReposts(testUserPubkey);
        expect(results.length, equals(3));
      });

      test('handles empty list gracefully', () async {
        await dao.upsertRepostsBatch([]);

        final results = await dao.getAllReposts(testUserPubkey);
        expect(results, isEmpty);
      });

      test('updates existing reposts in batch', () async {
        // Insert initial repost
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        // Batch with updated and new reposts
        final reposts = [
          PersonalRepostRow(
            addressableId: testAddressableId,
            repostEventId: testRepostEventId2, // Updated
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: 2000,
          ),
          PersonalRepostRow(
            addressableId: testAddressableId2,
            repostEventId: testRepostEventId3,
            originalAuthorPubkey: testOriginalAuthorPubkey,
            userPubkey: testUserPubkey,
            createdAt: 3000,
          ),
        ];

        await dao.upsertRepostsBatch(reposts);

        final results = await dao.getAllReposts(testUserPubkey);
        expect(results.length, equals(2));

        final updated = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );
        expect(updated!.repostEventId, equals(testRepostEventId2));
      });
    });

    group('deleteRepost', () {
      test('deletes repost by addressable ID and user', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final deleted = await dao.deleteRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        expect(deleted, equals(1));

        final result = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );
        expect(result, isNull);
      });

      test('returns 0 when repost does not exist', () async {
        final deleted = await dao.deleteRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        expect(deleted, equals(0));
      });

      test('only deletes repost for specified user', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        await dao.deleteRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        final result1 = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );
        final result2 = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey2,
        );

        expect(result1, isNull);
        expect(result2, isNotNull);
      });
    });

    group('deleteByRepostEventId', () {
      test('deletes repost by repost event ID', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final deleted = await dao.deleteByRepostEventId(testRepostEventId);

        expect(deleted, equals(1));

        final result = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );
        expect(result, isNull);
      });

      test('returns 0 when repost event ID does not exist', () async {
        final deleted = await dao.deleteByRepostEventId('nonexistent_id');

        expect(deleted, equals(0));
      });
    });

    group('getRepostEventId', () {
      test('returns repost event ID when reposted', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result = await dao.getRepostEventId(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        expect(result, equals(testRepostEventId));
      });

      test('returns null when not reposted', () async {
        final result = await dao.getRepostEventId(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        expect(result, isNull);
      });

      test('returns correct ID for specific user', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result1 = await dao.getRepostEventId(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );
        final result2 = await dao.getRepostEventId(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey2,
        );

        expect(result1, equals(testRepostEventId));
        expect(result2, equals(testRepostEventId2));
      });
    });

    group('getRepostedAddressableIds', () {
      test('returns empty set when no reposts', () async {
        final result = await dao.getRepostedAddressableIds(testUserPubkey);

        expect(result, isEmpty);
      });

      test('returns set of reposted addressable IDs', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final result = await dao.getRepostedAddressableIds(testUserPubkey);

        expect(result.length, equals(2));
        expect(result, containsAll([testAddressableId, testAddressableId2]));
      });

      test('only returns IDs for specified user', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result = await dao.getRepostedAddressableIds(testUserPubkey);

        expect(result.length, equals(1));
        expect(result, contains(testAddressableId));
        expect(result, isNot(contains(testAddressableId2)));
      });
    });

    group('getAllReposts', () {
      test('returns empty list when no reposts', () async {
        final result = await dao.getAllReposts(testUserPubkey);

        expect(result, isEmpty);
      });

      test('returns all reposts for user sorted by createdAt desc', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 3000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId3,
          repostEventId: testRepostEventId3,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final result = await dao.getAllReposts(testUserPubkey);

        expect(result.length, equals(3));
        // Should be sorted by createdAt descending
        expect(result[0].createdAt, equals(3000));
        expect(result[1].createdAt, equals(2000));
        expect(result[2].createdAt, equals(1000));
      });

      test('only returns reposts for specified user', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result = await dao.getAllReposts(testUserPubkey);

        expect(result.length, equals(1));
        expect(result.first.userPubkey, equals(testUserPubkey));
      });
    });

    group('watchRepostedAddressableIds', () {
      test('emits initial reposted addressable IDs', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final stream = dao.watchRepostedAddressableIds(testUserPubkey);
        final result = await stream.first;

        expect(result, contains(testAddressableId));
      });

      test('emits updates when reposts are added', () async {
        final stream = dao.watchRepostedAddressableIds(testUserPubkey);

        // Collect two emissions
        final emissionsFuture = stream.take(2).toList();

        // Wait for stream to be listening
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Add a repost
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));
        expect(emissions[0], isEmpty);
        expect(emissions[1], contains(testAddressableId));
      });

      test('emits updates when reposts are deleted', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final stream = dao.watchRepostedAddressableIds(testUserPubkey);

        // Collect two emissions
        final emissionsFuture = stream.take(2).toList();

        // Wait for stream to be listening
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Delete the repost
        await dao.deleteRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));
        expect(emissions[0], contains(testAddressableId));
        expect(emissions[1], isEmpty);
      });
    });

    group('watchAllReposts', () {
      test('emits initial reposts sorted by createdAt desc', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final stream = dao.watchAllReposts(testUserPubkey);
        final result = await stream.first;

        expect(result.length, equals(2));
        expect(result[0].createdAt, equals(2000));
        expect(result[1].createdAt, equals(1000));
      });

      test('emits updates when reposts change', () async {
        final stream = dao.watchAllReposts(testUserPubkey);

        // Collect two emissions
        final emissionsFuture = stream.take(2).toList();

        // Wait for stream to be listening
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Add a repost
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));
        expect(emissions[0], isEmpty);
        expect(emissions[1].length, equals(1));
      });
    });

    group('isReposted', () {
      test('returns true when event is reposted', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result = await dao.isReposted(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        expect(result, isTrue);
      });

      test('returns false when event is not reposted', () async {
        final result = await dao.isReposted(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        expect(result, isFalse);
      });

      test('returns correct status for specific user', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result1 = await dao.isReposted(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );
        final result2 = await dao.isReposted(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey2,
        );

        expect(result1, isTrue);
        expect(result2, isFalse);
      });
    });

    group('getRepostCount', () {
      test('returns 0 when no reposts', () async {
        final result = await dao.getRepostCount(testUserPubkey);

        expect(result, equals(0));
      });

      test('returns correct count of reposts', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId3,
          repostEventId: testRepostEventId3,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 3000,
        );

        final result = await dao.getRepostCount(testUserPubkey);

        expect(result, equals(3));
      });

      test('only counts reposts for specified user', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final result = await dao.getRepostCount(testUserPubkey);

        expect(result, equals(1));
      });
    });

    group('deleteAllForUser', () {
      test('deletes all reposts for user', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final deleted = await dao.deleteAllForUser(testUserPubkey);

        expect(deleted, equals(2));

        final remaining = await dao.getAllReposts(testUserPubkey);
        expect(remaining, isEmpty);
      });

      test('does not delete reposts for other users', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        await dao.deleteAllForUser(testUserPubkey);

        final remaining = await dao.getAllReposts(testUserPubkey2);
        expect(remaining.length, equals(1));
      });

      test('returns 0 when no reposts exist', () async {
        final deleted = await dao.deleteAllForUser(testUserPubkey);

        expect(deleted, equals(0));
      });
    });

    group('deleteAll', () {
      test('deletes all reposts', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );
        await dao.upsertRepost(
          addressableId: testAddressableId2,
          repostEventId: testRepostEventId2,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey2,
          createdAt: 2000,
        );

        final deleted = await dao.deleteAll();

        expect(deleted, equals(2));

        final remaining1 = await dao.getAllReposts(testUserPubkey);
        final remaining2 = await dao.getAllReposts(testUserPubkey2);
        expect(remaining1, isEmpty);
        expect(remaining2, isEmpty);
      });

      test('returns 0 when no reposts exist', () async {
        final deleted = await dao.deleteAll();

        expect(deleted, equals(0));
      });
    });

    group('getRepost', () {
      test('returns repost record when found', () async {
        await dao.upsertRepost(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testOriginalAuthorPubkey,
          userPubkey: testUserPubkey,
          createdAt: 1000,
        );

        final result = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        expect(result, isNotNull);
        expect(result!.addressableId, equals(testAddressableId));
        expect(result.repostEventId, equals(testRepostEventId));
        expect(result.originalAuthorPubkey, equals(testOriginalAuthorPubkey));
        expect(result.userPubkey, equals(testUserPubkey));
        expect(result.createdAt, equals(1000));
      });

      test('returns null when not found', () async {
        final result = await dao.getRepost(
          addressableId: testAddressableId,
          userPubkey: testUserPubkey,
        );

        expect(result, isNull);
      });
    });
  });
}

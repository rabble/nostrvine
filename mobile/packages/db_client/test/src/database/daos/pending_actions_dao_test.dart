// ABOUTME: Unit tests for PendingActionsDao with offline action queue
// ABOUTME: operations. Tests all DAO methods including CRUD, status updates,
// ABOUTME: and reactive streams.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PendingActionsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testUserPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const testUserPubkey2 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  /// Valid 64-char hex event IDs for testing
  const testTargetId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const testTargetId2 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const testTargetId3 =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const testAuthorPubkey =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.pendingActionsDao;
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

  group('PendingActionsDao', () {
    group('upsertAction', () {
      test('inserts a new pending action', () async {
        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
          authorPubkey: testAuthorPubkey,
        );

        await dao.upsertAction(action);

        final result = await dao.getAction(action.id);
        expect(result, isNotNull);
        expect(result!.type, equals(PendingActionType.like));
        expect(result.targetId, equals(testTargetId));
        expect(result.userPubkey, equals(testUserPubkey));
        expect(result.status, equals(PendingActionStatus.pending));
      });

      test('updates existing action', () async {
        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(action);

        final updated = action.copyWith(status: PendingActionStatus.syncing);
        await dao.upsertAction(updated);

        final result = await dao.getAction(action.id);
        expect(result!.status, equals(PendingActionStatus.syncing));
      });

      test('inserts action with all optional fields', () async {
        final action = PendingAction.create(
          type: PendingActionType.repost,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
          authorPubkey: testAuthorPubkey,
          addressableId: '34236:$testAuthorPubkey:video1',
          targetKind: 34236,
        );

        await dao.upsertAction(action);

        final result = await dao.getAction(action.id);
        expect(result, isNotNull);
        expect(result!.authorPubkey, equals(testAuthorPubkey));
        expect(result.addressableId, equals('34236:$testAuthorPubkey:video1'));
        expect(result.targetKind, equals(34236));
      });
    });

    group('getAction', () {
      test('returns action by ID', () async {
        final action = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(action);

        final result = await dao.getAction(action.id);
        expect(result, isNotNull);
        expect(result!.id, equals(action.id));
      });

      test('returns null for non-existent ID', () async {
        final result = await dao.getAction('non_existent_id');
        expect(result, isNull);
      });
    });

    group('getPendingActions', () {
      test('returns only pending actions for user', () async {
        final pending = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        await dao.upsertAction(pending);

        final syncing = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId2,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.syncing);
        await dao.upsertAction(syncing);

        final completed = PendingAction.create(
          type: PendingActionType.repost,
          targetId: testTargetId3,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.completed);
        await dao.upsertAction(completed);

        final result = await dao.getPendingActions(testUserPubkey);

        expect(result.length, equals(1));
        expect(result.first.id, equals(pending.id));
        expect(result.first.status, equals(PendingActionStatus.pending));
      });

      test('returns actions sorted by createdAt', () async {
        final action1 = PendingAction(
          id: 'id1',
          type: PendingActionType.like,
          targetId: testTargetId,
          status: PendingActionStatus.pending,
          userPubkey: testUserPubkey,
          createdAt: DateTime(2024),
        );
        final action2 = PendingAction(
          id: 'id2',
          type: PendingActionType.follow,
          targetId: testTargetId2,
          status: PendingActionStatus.pending,
          userPubkey: testUserPubkey,
          createdAt: DateTime(2024, 1, 3),
        );
        final action3 = PendingAction(
          id: 'id3',
          type: PendingActionType.repost,
          targetId: testTargetId3,
          status: PendingActionStatus.pending,
          userPubkey: testUserPubkey,
          createdAt: DateTime(2024, 1, 2),
        );

        await dao.upsertAction(action1);
        await dao.upsertAction(action2);
        await dao.upsertAction(action3);

        final result = await dao.getPendingActions(testUserPubkey);

        expect(result.length, equals(3));
        expect(result[0].id, equals('id1'));
        expect(result[1].id, equals('id3'));
        expect(result[2].id, equals('id2'));
      });

      test('only returns actions for specified user', () async {
        final action1 = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        final action2 = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId2,
          userPubkey: testUserPubkey2,
        );

        await dao.upsertAction(action1);
        await dao.upsertAction(action2);

        final result = await dao.getPendingActions(testUserPubkey);

        expect(result.length, equals(1));
        expect(result.first.userPubkey, equals(testUserPubkey));
      });
    });

    group('getAllActions', () {
      test('returns all actions for user regardless of status', () async {
        final pending = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        final syncing = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId2,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.syncing);
        final completed = PendingAction.create(
          type: PendingActionType.repost,
          targetId: testTargetId3,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.completed);

        await dao.upsertAction(pending);
        await dao.upsertAction(syncing);
        await dao.upsertAction(completed);

        final result = await dao.getAllActions(testUserPubkey);

        expect(result.length, equals(3));
      });
    });

    group('getActionsByStatus', () {
      test('returns actions with specified status', () async {
        final pending = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        final syncing = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId2,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.syncing);

        await dao.upsertAction(pending);
        await dao.upsertAction(syncing);

        final result = await dao.getActionsByStatus(
          testUserPubkey,
          PendingActionStatus.syncing,
        );

        expect(result.length, equals(1));
        expect(result.first.status, equals(PendingActionStatus.syncing));
      });
    });

    group('findConflictingAction', () {
      test('finds conflicting opposite action', () async {
        final likeAction = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(likeAction);

        final conflict = await dao.findConflictingAction(
          testUserPubkey,
          testTargetId,
          PendingActionType.like, // Looking for the opposite of unlike
        );

        expect(conflict, isNotNull);
        expect(conflict!.id, equals(likeAction.id));
      });

      test('returns null when no conflict exists', () async {
        final conflict = await dao.findConflictingAction(
          testUserPubkey,
          testTargetId,
          PendingActionType.like,
        );

        expect(conflict, isNull);
      });

      test('ignores completed actions', () async {
        final completedAction = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.completed);

        await dao.upsertAction(completedAction);

        final conflict = await dao.findConflictingAction(
          testUserPubkey,
          testTargetId,
          PendingActionType.like,
        );

        expect(conflict, isNull);
      });
    });

    group('hasPendingAction', () {
      test('returns true when pending action exists', () async {
        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(action);

        final result = await dao.hasPendingAction(
          testUserPubkey,
          testTargetId,
          PendingActionType.like,
        );

        expect(result, isTrue);
      });

      test('returns false when no pending action exists', () async {
        final result = await dao.hasPendingAction(
          testUserPubkey,
          testTargetId,
          PendingActionType.like,
        );

        expect(result, isFalse);
      });

      test('returns false for different action type', () async {
        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(action);

        final result = await dao.hasPendingAction(
          testUserPubkey,
          testTargetId,
          PendingActionType.unlike,
        );

        expect(result, isFalse);
      });
    });

    group('updateStatus', () {
      test('updates action status', () async {
        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(action);

        final updated = await dao.updateStatus(
          action.id,
          PendingActionStatus.syncing,
        );

        expect(updated, isTrue);

        final result = await dao.getAction(action.id);
        expect(result!.status, equals(PendingActionStatus.syncing));
        expect(result.lastAttemptAt, isNotNull);
      });

      test('updates status with error info', () async {
        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(action);

        await dao.updateStatus(
          action.id,
          PendingActionStatus.failed,
          lastError: 'Network error',
          retryCount: 3,
        );

        final result = await dao.getAction(action.id);
        expect(result!.status, equals(PendingActionStatus.failed));
        expect(result.lastError, equals('Network error'));
        expect(result.retryCount, equals(3));
      });

      test('returns false for non-existent action', () async {
        final updated = await dao.updateStatus(
          'non_existent_id',
          PendingActionStatus.syncing,
        );

        expect(updated, isFalse);
      });
    });

    group('deleteAction', () {
      test('deletes action by ID', () async {
        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(action);

        final deleted = await dao.deleteAction(action.id);

        expect(deleted, equals(1));

        final result = await dao.getAction(action.id);
        expect(result, isNull);
      });

      test('returns 0 for non-existent action', () async {
        final deleted = await dao.deleteAction('non_existent_id');

        expect(deleted, equals(0));
      });
    });

    group('deleteCompleted', () {
      test('deletes only completed actions for user', () async {
        final pending = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        final completed = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId2,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.completed);

        await dao.upsertAction(pending);
        await dao.upsertAction(completed);

        final deleted = await dao.deleteCompleted(testUserPubkey);

        expect(deleted, equals(1));

        final remaining = await dao.getAllActions(testUserPubkey);
        expect(remaining.length, equals(1));
        expect(remaining.first.status, equals(PendingActionStatus.pending));
      });
    });

    group('deleteOldCompleted', () {
      test('deletes completed actions older than duration', () async {
        final oldCompleted = PendingAction(
          id: 'old_id',
          type: PendingActionType.like,
          targetId: testTargetId,
          status: PendingActionStatus.completed,
          userPubkey: testUserPubkey,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
        );
        final recentCompleted = PendingAction(
          id: 'recent_id',
          type: PendingActionType.follow,
          targetId: testTargetId2,
          status: PendingActionStatus.completed,
          userPubkey: testUserPubkey,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        await dao.upsertAction(oldCompleted);
        await dao.upsertAction(recentCompleted);

        final deleted = await dao.deleteOldCompleted(
          testUserPubkey,
          const Duration(days: 7),
        );

        expect(deleted, equals(1));

        final remaining = await dao.getAllActions(testUserPubkey);
        expect(remaining.length, equals(1));
        expect(remaining.first.id, equals('recent_id'));
      });
    });

    group('watchPendingActions', () {
      test('emits initial pending actions', () async {
        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(action);

        final stream = dao.watchPendingActions(testUserPubkey);
        final result = await stream.first;

        expect(result.length, equals(1));
        expect(result.first.id, equals(action.id));
      });

      test('emits updates when actions change', () async {
        final stream = dao.watchPendingActions(testUserPubkey);

        final emissionsFuture = stream.take(2).toList();

        await Future<void>.delayed(const Duration(milliseconds: 10));

        final action = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        await dao.upsertAction(action);

        final emissions = await emissionsFuture;
        expect(emissions.length, equals(2));
        expect(emissions[0], isEmpty);
        expect(emissions[1].length, equals(1));
      });
    });

    group('watchAllActions', () {
      test('emits all actions regardless of status', () async {
        final pending = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        final completed = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId2,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.completed);

        await dao.upsertAction(pending);
        await dao.upsertAction(completed);

        final stream = dao.watchAllActions(testUserPubkey);
        final result = await stream.first;

        expect(result.length, equals(2));
      });
    });

    group('clearAll', () {
      test('deletes all actions for user', () async {
        final action1 = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        final action2 = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId2,
          userPubkey: testUserPubkey,
        );

        await dao.upsertAction(action1);
        await dao.upsertAction(action2);

        final deleted = await dao.clearAll(testUserPubkey);

        expect(deleted, equals(2));

        final remaining = await dao.getAllActions(testUserPubkey);
        expect(remaining, isEmpty);
      });

      test('does not delete actions for other users', () async {
        final action1 = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        final action2 = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId2,
          userPubkey: testUserPubkey2,
        );

        await dao.upsertAction(action1);
        await dao.upsertAction(action2);

        await dao.clearAll(testUserPubkey);

        final remaining = await dao.getAllActions(testUserPubkey2);
        expect(remaining.length, equals(1));
      });
    });

    group('resetSyncingToPending', () {
      test('resets syncing actions to pending', () async {
        final syncing = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.syncing);

        await dao.upsertAction(syncing);

        final reset = await dao.resetSyncingToPending(testUserPubkey);

        expect(reset, equals(1));

        final result = await dao.getAction(syncing.id);
        expect(result!.status, equals(PendingActionStatus.pending));
      });

      test('does not affect other statuses', () async {
        final pending = PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        );
        final completed = PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId2,
          userPubkey: testUserPubkey,
        ).copyWith(status: PendingActionStatus.completed);

        await dao.upsertAction(pending);
        await dao.upsertAction(completed);

        final reset = await dao.resetSyncingToPending(testUserPubkey);

        expect(reset, equals(0));

        final pendingResult = await dao.getAction(pending.id);
        final completedResult = await dao.getAction(completed.id);

        expect(pendingResult!.status, equals(PendingActionStatus.pending));
        expect(completedResult!.status, equals(PendingActionStatus.completed));
      });
    });
  });

  group('PendingAction model', () {
    test('create sets correct default values', () {
      final action = PendingAction.create(
        type: PendingActionType.like,
        targetId: testTargetId,
        userPubkey: testUserPubkey,
      );

      expect(action.id, isNotEmpty);
      expect(action.status, equals(PendingActionStatus.pending));
      expect(action.retryCount, equals(0));
      expect(action.createdAt, isNotNull);
    });

    test('isPositiveAction returns correct values', () {
      expect(
        PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isTrue,
      );
      expect(
        PendingAction.create(
          type: PendingActionType.unlike,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isFalse,
      );
      expect(
        PendingAction.create(
          type: PendingActionType.repost,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isTrue,
      );
      expect(
        PendingAction.create(
          type: PendingActionType.unrepost,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isFalse,
      );
      expect(
        PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isTrue,
      );
      expect(
        PendingAction.create(
          type: PendingActionType.unfollow,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).isPositiveAction,
        isFalse,
      );
    });

    test('oppositeType returns correct type', () {
      expect(
        PendingAction.create(
          type: PendingActionType.like,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).oppositeType,
        equals(PendingActionType.unlike),
      );
      expect(
        PendingAction.create(
          type: PendingActionType.unlike,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).oppositeType,
        equals(PendingActionType.like),
      );
      expect(
        PendingAction.create(
          type: PendingActionType.repost,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).oppositeType,
        equals(PendingActionType.unrepost),
      );
      expect(
        PendingAction.create(
          type: PendingActionType.unrepost,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).oppositeType,
        equals(PendingActionType.repost),
      );
      expect(
        PendingAction.create(
          type: PendingActionType.follow,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).oppositeType,
        equals(PendingActionType.unfollow),
      );
      expect(
        PendingAction.create(
          type: PendingActionType.unfollow,
          targetId: testTargetId,
          userPubkey: testUserPubkey,
        ).oppositeType,
        equals(PendingActionType.follow),
      );
    });

    test('cancels returns true for opposite actions on same target', () {
      final like = PendingAction.create(
        type: PendingActionType.like,
        targetId: testTargetId,
        userPubkey: testUserPubkey,
      );
      final unlike = PendingAction.create(
        type: PendingActionType.unlike,
        targetId: testTargetId,
        userPubkey: testUserPubkey,
      );

      expect(like.cancels(unlike), isTrue);
      expect(unlike.cancels(like), isTrue);
    });

    test('cancels returns false for different targets', () {
      final like = PendingAction.create(
        type: PendingActionType.like,
        targetId: testTargetId,
        userPubkey: testUserPubkey,
      );
      final unlike = PendingAction.create(
        type: PendingActionType.unlike,
        targetId: testTargetId2,
        userPubkey: testUserPubkey,
      );

      expect(like.cancels(unlike), isFalse);
    });

    test('canRetry returns correct value', () {
      final failedWithRetries = PendingAction(
        id: 'id1',
        type: PendingActionType.like,
        targetId: testTargetId,
        status: PendingActionStatus.failed,
        userPubkey: testUserPubkey,
        createdAt: DateTime.now(),
        retryCount: 3,
      );

      final failedMaxRetries = PendingAction(
        id: 'id2',
        type: PendingActionType.like,
        targetId: testTargetId,
        status: PendingActionStatus.failed,
        userPubkey: testUserPubkey,
        createdAt: DateTime.now(),
        retryCount: PendingAction.maxRetries,
      );

      final pending = PendingAction.create(
        type: PendingActionType.like,
        targetId: testTargetId,
        userPubkey: testUserPubkey,
      );

      expect(failedWithRetries.canRetry, isTrue);
      expect(failedMaxRetries.canRetry, isFalse);
      expect(pending.canRetry, isFalse); // Not failed
    });

    test('copyWith creates new instance with updated values', () {
      final original = PendingAction.create(
        type: PendingActionType.like,
        targetId: testTargetId,
        userPubkey: testUserPubkey,
      );

      final copied = original.copyWith(
        status: PendingActionStatus.completed,
        retryCount: 5,
      );

      expect(copied.id, equals(original.id));
      expect(copied.type, equals(original.type));
      expect(copied.status, equals(PendingActionStatus.completed));
      expect(copied.retryCount, equals(5));
    });

    test('equality is based on ID', () {
      final action1 = PendingAction(
        id: 'same_id',
        type: PendingActionType.like,
        targetId: testTargetId,
        status: PendingActionStatus.pending,
        userPubkey: testUserPubkey,
        createdAt: DateTime(2024),
      );

      final action2 = PendingAction(
        id: 'same_id',
        type: PendingActionType.follow, // Different type
        targetId: testTargetId2, // Different target
        status: PendingActionStatus.completed, // Different status
        userPubkey: testUserPubkey2, // Different user
        createdAt: DateTime(2024, 1, 2), // Different date
      );

      expect(action1, equals(action2));
      expect(action1.hashCode, equals(action2.hashCode));
    });

    test('toString contains relevant info', () {
      final action = PendingAction.create(
        type: PendingActionType.like,
        targetId: testTargetId,
        userPubkey: testUserPubkey,
      );

      final str = action.toString();
      expect(str, contains('PendingAction'));
      expect(str, contains('like'));
      expect(str, contains(testTargetId));
      expect(str, contains('pending'));
    });
  });
}

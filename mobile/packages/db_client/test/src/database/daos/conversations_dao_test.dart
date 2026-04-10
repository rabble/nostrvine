// ABOUTME: Unit tests for ConversationsDao with CRUD, reactive watch streams,
// ABOUTME: unread counts, and ordering operations.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ConversationsDao dao;
  late String tempDbPath;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'conversations_dao_test_',
    );
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.conversationsDao;
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

  group(ConversationsDao, () {
    group('upsertConversation', () {
      test('inserts new conversation', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["pubkey_a","pubkey_b"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageContent: 'Hello!',
          lastMessageTimestamp: 1700000100,
          lastMessageSenderPubkey: 'pubkey_a',
        );

        final result = await dao.getConversation('conv_1');
        expect(result, isNotNull);
        expect(result!.id, equals('conv_1'));
        expect(
          result.participantPubkeys,
          equals('["pubkey_a","pubkey_b"]'),
        );
        expect(result.isGroup, isFalse);
        expect(result.lastMessageContent, equals('Hello!'));
        expect(result.lastMessageTimestamp, equals(1700000100));
        expect(result.lastMessageSenderPubkey, equals('pubkey_a'));
        expect(result.isRead, isTrue);
      });

      test('updates existing conversation with same ID', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["pubkey_a","pubkey_b"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageContent: 'Hello!',
          lastMessageTimestamp: 1700000100,
          lastMessageSenderPubkey: 'pubkey_a',
        );

        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["pubkey_a","pubkey_b"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageContent: 'Updated message',
          lastMessageTimestamp: 1700000200,
          lastMessageSenderPubkey: 'pubkey_b',
          isRead: false,
        );

        final result = await dao.getConversation('conv_1');
        expect(result, isNotNull);
        expect(result!.lastMessageContent, equals('Updated message'));
        expect(result.lastMessageTimestamp, equals(1700000200));
        expect(result.lastMessageSenderPubkey, equals('pubkey_b'));
        expect(result.isRead, isFalse);
      });

      test('inserts conversation with subject', () async {
        await dao.upsertConversation(
          id: 'conv_group',
          participantPubkeys: '["pubkey_a","pubkey_b","pubkey_c"]',
          isGroup: true,
          createdAt: 1700000000,
          subject: 'Group Chat',
        );

        final result = await dao.getConversation('conv_group');
        expect(result, isNotNull);
        expect(result!.isGroup, isTrue);
        expect(result.subject, equals('Group Chat'));
      });
    });

    group('getAllConversations', () {
      test(
        'returns conversations sorted by lastMessageTimestamp desc',
        () async {
          await dao.upsertConversation(
            id: 'conv_old',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageTimestamp: 1700000100,
          );
          await dao.upsertConversation(
            id: 'conv_new',
            participantPubkeys: '["a","c"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageTimestamp: 1700000300,
          );
          await dao.upsertConversation(
            id: 'conv_mid',
            participantPubkeys: '["a","d"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageTimestamp: 1700000200,
          );

          final results = await dao.getAllConversations();
          expect(results, hasLength(3));
          expect(results[0].id, equals('conv_new'));
          expect(results[1].id, equals('conv_mid'));
          expect(results[2].id, equals('conv_old'));
        },
      );

      test('respects limit parameter', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000100,
        );
        await dao.upsertConversation(
          id: 'conv_2',
          participantPubkeys: '["a","c"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000200,
        );
        await dao.upsertConversation(
          id: 'conv_3',
          participantPubkeys: '["a","d"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000300,
        );

        final results = await dao.getAllConversations(limit: 2);
        expect(results, hasLength(2));
      });

      test('returns empty list when no conversations exist', () async {
        final results = await dao.getAllConversations();
        expect(results, isEmpty);
      });
    });

    group('getConversation', () {
      test('returns conversation when found', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
        );

        final result = await dao.getConversation('conv_1');
        expect(result, isNotNull);
        expect(result!.id, equals('conv_1'));
      });

      test('returns null for non-existent conversation', () async {
        final result = await dao.getConversation('nonexistent');
        expect(result, isNull);
      });
    });

    group('watchAllConversations', () {
      test('emits initial list sorted by lastMessageTimestamp desc', () async {
        await dao.upsertConversation(
          id: 'conv_old',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000100,
        );
        await dao.upsertConversation(
          id: 'conv_new',
          participantPubkeys: '["a","c"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000200,
        );

        final stream = dao.watchAllConversations();
        final results = await stream.first;

        expect(results, hasLength(2));
        expect(results[0].id, equals('conv_new'));
        expect(results[1].id, equals('conv_old'));
      });

      test('respects limit parameter', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000100,
        );
        await dao.upsertConversation(
          id: 'conv_2',
          participantPubkeys: '["a","c"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000200,
        );

        final stream = dao.watchAllConversations(limit: 1);
        final results = await stream.first;

        expect(results, hasLength(1));
        expect(results[0].id, equals('conv_2'));
      });

      test('emits empty list when no conversations exist', () async {
        final stream = dao.watchAllConversations();
        final results = await stream.first;
        expect(results, isEmpty);
      });
    });

    group('watchConversation', () {
      test('emits conversation when found', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
        );

        final stream = dao.watchConversation('conv_1');
        final result = await stream.first;

        expect(result, isNotNull);
        expect(result!.id, equals('conv_1'));
      });

      test('emits null for non-existent conversation', () async {
        final stream = dao.watchConversation('nonexistent');
        final result = await stream.first;
        expect(result, isNull);
      });
    });

    group('markAsRead', () {
      test('marks unread conversation as read', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
          isRead: false,
        );

        final updated = await dao.markAsRead('conv_1');
        expect(updated, isTrue);

        final result = await dao.getConversation('conv_1');
        expect(result!.isRead, isTrue);
      });

      test('returns false for non-existent conversation', () async {
        final updated = await dao.markAsRead('nonexistent');
        expect(updated, isFalse);
      });

      test('does not affect other conversations', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
          isRead: false,
        );
        await dao.upsertConversation(
          id: 'conv_2',
          participantPubkeys: '["a","c"]',
          isGroup: false,
          createdAt: 1700000000,
          isRead: false,
        );

        await dao.markAsRead('conv_1');

        final conv2 = await dao.getConversation('conv_2');
        expect(conv2!.isRead, isFalse);
      });
    });

    group('getUnreadCount', () {
      test('returns count of unread conversations', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
          isRead: false,
        );
        await dao.upsertConversation(
          id: 'conv_2',
          participantPubkeys: '["a","c"]',
          isGroup: false,
          createdAt: 1700000000,
          isRead: false,
        );
        await dao.upsertConversation(
          id: 'conv_3',
          participantPubkeys: '["a","d"]',
          isGroup: false,
          createdAt: 1700000000,
        );

        final count = await dao.getUnreadCount();
        expect(count, equals(2));
      });

      test('returns 0 when all conversations are read', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
        );

        final count = await dao.getUnreadCount();
        expect(count, equals(0));
      });

      test('returns 0 when no conversations exist', () async {
        final count = await dao.getUnreadCount();
        expect(count, equals(0));
      });
    });

    group('watchUnreadCount', () {
      test('emits initial unread count', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
          isRead: false,
        );
        await dao.upsertConversation(
          id: 'conv_2',
          participantPubkeys: '["a","c"]',
          isGroup: true,
          createdAt: 1700000000,
        );

        final stream = dao.watchUnreadCount();
        final count = await stream.first;

        expect(count, equals(1));
      });

      test('emits 0 when no unread conversations', () async {
        final stream = dao.watchUnreadCount();
        final count = await stream.first;
        expect(count, equals(0));
      });
    });

    group('deleteConversation', () {
      test('deletes conversation by ID', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
        );
        await dao.upsertConversation(
          id: 'conv_2',
          participantPubkeys: '["a","c"]',
          isGroup: false,
          createdAt: 1700000000,
        );

        final deleted = await dao.deleteConversation('conv_1');

        expect(deleted, equals(1));
        final result = await dao.getConversation('conv_1');
        expect(result, isNull);
        final remaining = await dao.getAllConversations();
        expect(remaining, hasLength(1));
      });

      test('returns 0 for non-existent conversation', () async {
        final deleted = await dao.deleteConversation('nonexistent');
        expect(deleted, equals(0));
      });
    });

    group('clearAll', () {
      test('deletes all conversations', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["a","b"]',
          isGroup: false,
          createdAt: 1700000000,
        );
        await dao.upsertConversation(
          id: 'conv_2',
          participantPubkeys: '["a","c"]',
          isGroup: false,
          createdAt: 1700000000,
        );

        final deleted = await dao.clearAll();

        expect(deleted, equals(2));
        final results = await dao.getAllConversations();
        expect(results, isEmpty);
      });

      test('returns 0 when table is empty', () async {
        final deleted = await dao.clearAll();
        expect(deleted, equals(0));
      });
    });

    group('ownerPubkey scoping', () {
      const userA = 'pubkey_user_a';
      const userB = 'pubkey_user_b';

      test(
        'queries scoped by ownerPubkey only return that user conversations',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageTimestamp: 1700000100,
            ownerPubkey: userA,
          );
          await dao.upsertConversation(
            id: 'conv_2',
            participantPubkeys: '["pubkey_c","pubkey_d"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageTimestamp: 1700000200,
            ownerPubkey: userB,
          );

          final userAConvs = await dao.getAllConversations(ownerPubkey: userA);
          final userBConvs = await dao.getAllConversations(ownerPubkey: userB);

          expect(userAConvs, hasLength(1));
          expect(userAConvs.first.id, equals('conv_1'));
          expect(userBConvs, hasLength(1));
          expect(userBConvs.first.id, equals('conv_2'));
        },
      );

      test(
        'legacy conversations (NULL ownerPubkey) are visible to scoped queries',
        () async {
          await dao.upsertConversation(
            id: 'conv_legacy',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageTimestamp: 1700000100,
          );
          await dao.upsertConversation(
            id: 'conv_a1',
            participantPubkeys: '["pubkey_c","pubkey_d"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageTimestamp: 1700000200,
            ownerPubkey: userA,
          );

          final userAConvs = await dao.getAllConversations(ownerPubkey: userA);
          expect(userAConvs, hasLength(2));
        },
      );

      test('clearAllForUser only deletes that user conversations', () async {
        await dao.upsertConversation(
          id: 'conv_a1',
          participantPubkeys: '["pubkey_a","pubkey_b"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000100,
          ownerPubkey: userA,
        );
        await dao.upsertConversation(
          id: 'conv_b1',
          participantPubkeys: '["pubkey_c","pubkey_d"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000200,
          ownerPubkey: userB,
        );

        final deleted = await dao.clearAllForUser(userA);

        expect(deleted, equals(1));
        final remaining = await dao.getAllConversations(ownerPubkey: userB);
        expect(remaining, hasLength(1));
        expect(remaining.first.id, equals('conv_b1'));
      });

      test('unread count respects ownerPubkey', () async {
        await dao.upsertConversation(
          id: 'conv_a1',
          participantPubkeys: '["pubkey_a","pubkey_b"]',
          isGroup: false,
          createdAt: 1700000000,
          isRead: false,
          ownerPubkey: userA,
        );
        await dao.upsertConversation(
          id: 'conv_b1',
          participantPubkeys: '["pubkey_c","pubkey_d"]',
          isGroup: false,
          createdAt: 1700000000,
          isRead: false,
          ownerPubkey: userB,
        );

        final countA = await dao.getUnreadCount(ownerPubkey: userA);
        final countB = await dao.getUnreadCount(ownerPubkey: userB);

        expect(countA, equals(1));
        expect(countB, equals(1));
      });
    });

    group('backfillCurrentUserHasSent', () {
      const userA = 'pubkey_a';
      const userB = 'pubkey_b';

      test('sets flag for conversations where user sent messages', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["$userA","$userB"]',
          isGroup: false,
          createdAt: 1700000000,
          ownerPubkey: userA,
        );
        await database.directMessagesDao.insertMessage(
          id: 'msg_1',
          conversationId: 'conv_1',
          senderPubkey: userA,
          content: 'hello',
          createdAt: 1700000001,
          giftWrapId: 'gw_1',
          ownerPubkey: userA,
        );

        final updated = await dao.backfillCurrentUserHasSent(userA);

        expect(updated, equals(1));
        final conv = await dao.getConversation('conv_1', ownerPubkey: userA);
        expect(conv!.currentUserHasSent, isTrue);
      });

      test('does not flip true back to false', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["$userA","$userB"]',
          isGroup: false,
          createdAt: 1700000000,
          currentUserHasSent: true,
          ownerPubkey: userA,
        );

        final updated = await dao.backfillCurrentUserHasSent(userA);

        expect(updated, equals(0));
        final conv = await dao.getConversation('conv_1', ownerPubkey: userA);
        expect(conv!.currentUserHasSent, isTrue);
      });

      test('skips conversations with no sent messages from user', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["$userA","$userB"]',
          isGroup: false,
          createdAt: 1700000000,
          ownerPubkey: userA,
        );
        // Only a received message (sender is userB, not userA).
        await database.directMessagesDao.insertMessage(
          id: 'msg_1',
          conversationId: 'conv_1',
          senderPubkey: userB,
          content: 'hey',
          createdAt: 1700000001,
          giftWrapId: 'gw_1',
          ownerPubkey: userA,
        );

        final updated = await dao.backfillCurrentUserHasSent(userA);

        expect(updated, equals(0));
        final conv = await dao.getConversation('conv_1', ownerPubkey: userA);
        expect(conv!.currentUserHasSent, isFalse);
      });

      test('idempotent — second run is a no-op', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["$userA","$userB"]',
          isGroup: false,
          createdAt: 1700000000,
          ownerPubkey: userA,
        );
        await database.directMessagesDao.insertMessage(
          id: 'msg_1',
          conversationId: 'conv_1',
          senderPubkey: userA,
          content: 'hello',
          createdAt: 1700000001,
          giftWrapId: 'gw_1',
          ownerPubkey: userA,
        );

        await dao.backfillCurrentUserHasSent(userA);
        final secondRun = await dao.backfillCurrentUserHasSent(userA);

        expect(secondRun, equals(0));
      });

      test('handles legacy rows with null owner_pubkey', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["$userA","$userB"]',
          isGroup: false,
          createdAt: 1700000000,
        );
        await database.directMessagesDao.insertMessage(
          id: 'msg_1',
          conversationId: 'conv_1',
          senderPubkey: userA,
          content: 'hello',
          createdAt: 1700000001,
          giftWrapId: 'gw_1',
        );

        final updated = await dao.backfillCurrentUserHasSent(userA);

        expect(updated, equals(1));
        final conv = await dao.getConversation('conv_1');
        expect(conv!.currentUserHasSent, isTrue);
      });
    });
  });
}

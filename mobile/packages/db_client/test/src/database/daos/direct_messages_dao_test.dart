// ABOUTME: Unit tests for DirectMessagesDao with CRUD, deduplication,
// ABOUTME: conversation-scoped queries, reactive watch streams, and counting.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DirectMessagesDao dao;
  late String tempDbPath;

  const conversationId1 = 'conv_abc123';
  const conversationId2 = 'conv_def456';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'direct_messages_dao_test_',
    );
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.directMessagesDao;
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

  group(DirectMessagesDao, () {
    group('insertMessage', () {
      test('inserts new text message (kind 14)', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Hello Bob!',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.id, equals('msg_1'));
        expect(results.first.conversationId, equals(conversationId1));
        expect(results.first.senderPubkey, equals('pubkey_alice'));
        expect(results.first.content, equals('Hello Bob!'));
        expect(results.first.createdAt, equals(1700000000));
        expect(results.first.giftWrapId, equals('gw_1'));
        expect(results.first.messageKind, equals(14));
        expect(results.first.replyToId, isNull);
      });

      test('inserts file message (kind 15) with metadata', () async {
        await dao.insertMessage(
          id: 'msg_file',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'https://example.com/encrypted.bin',
          createdAt: 1700000100,
          giftWrapId: 'gw_file',
          messageKind: 15,
          fileType: 'image/jpeg',
          encryptionAlgorithm: 'aes-gcm',
          decryptionKey: 'deadbeef',
          decryptionNonce: 'cafebabe',
          fileHash: 'abc123hash',
          originalFileHash: 'orig123hash',
          fileSize: 204800,
          dimensions: '1920x1080',
          blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          thumbnailUrl: 'https://example.com/thumb.bin',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        final msg = results.first;
        expect(msg.messageKind, equals(15));
        expect(msg.fileType, equals('image/jpeg'));
        expect(msg.encryptionAlgorithm, equals('aes-gcm'));
        expect(msg.decryptionKey, equals('deadbeef'));
        expect(msg.decryptionNonce, equals('cafebabe'));
        expect(msg.fileHash, equals('abc123hash'));
        expect(msg.originalFileHash, equals('orig123hash'));
        expect(msg.fileSize, equals(204800));
        expect(msg.dimensions, equals('1920x1080'));
        expect(
          msg.blurhash,
          equals('LEHV6nWB2yk8pyo0adR*.7kCMdnj'),
        );
        expect(msg.thumbnailUrl, equals('https://example.com/thumb.bin'));
      });

      test('inserts message with reply', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Hello!',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'Hi Alice!',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
          replyToId: 'msg_1',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        // Newest first
        expect(results[0].replyToId, equals('msg_1'));
      });

      test('updates existing message with same ID (upsert)', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Original',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );

        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Updated',
          createdAt: 1700000000,
          giftWrapId: 'gw_1_new',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.content, equals('Updated'));
      });
    });

    group('getMessagesForConversation', () {
      test(
        'returns messages sorted by createdAt desc (newest first)',
        () async {
          await dao.insertMessage(
            id: 'msg_old',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'First message',
            createdAt: 1700000000,
            giftWrapId: 'gw_old',
          );
          await dao.insertMessage(
            id: 'msg_new',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_bob',
            content: 'Latest message',
            createdAt: 1700000200,
            giftWrapId: 'gw_new',
          );
          await dao.insertMessage(
            id: 'msg_mid',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Middle message',
            createdAt: 1700000100,
            giftWrapId: 'gw_mid',
          );

          final results = await dao.getMessagesForConversation(conversationId1);
          expect(results, hasLength(3));
          expect(results[0].id, equals('msg_new'));
          expect(results[1].id, equals('msg_mid'));
          expect(results[2].id, equals('msg_old'));
        },
      );

      test('respects limit and offset parameters', () async {
        for (var i = 0; i < 5; i++) {
          await dao.insertMessage(
            id: 'msg_$i',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Message $i',
            createdAt: 1700000000 + i * 100,
            giftWrapId: 'gw_$i',
          );
        }

        final results = await dao.getMessagesForConversation(
          conversationId1,
          limit: 2,
          offset: 1,
        );
        expect(results, hasLength(2));
        // Newest first, skip 1 => msg_3, msg_2
        expect(results[0].id, equals('msg_3'));
        expect(results[1].id, equals('msg_2'));
      });

      test('does not return messages from other conversations', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Conv 1 message',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId2,
          senderPubkey: 'pubkey_bob',
          content: 'Conv 2 message',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
        );

        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.id, equals('msg_1'));
      });

      test('returns empty list for non-existent conversation', () async {
        final results = await dao.getMessagesForConversation('nonexistent');
        expect(results, isEmpty);
      });
    });

    group('watchMessagesForConversation', () {
      test('emits initial list sorted by createdAt desc', () async {
        await dao.insertMessage(
          id: 'msg_old',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Old',
          createdAt: 1700000000,
          giftWrapId: 'gw_old',
        );
        await dao.insertMessage(
          id: 'msg_new',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'New',
          createdAt: 1700000100,
          giftWrapId: 'gw_new',
        );

        final stream = dao.watchMessagesForConversation(conversationId1);
        final results = await stream.first;

        expect(results, hasLength(2));
        expect(results[0].id, equals('msg_new'));
        expect(results[1].id, equals('msg_old'));
      });

      test('respects limit parameter', () async {
        for (var i = 0; i < 3; i++) {
          await dao.insertMessage(
            id: 'msg_$i',
            conversationId: conversationId1,
            senderPubkey: 'pubkey_alice',
            content: 'Message $i',
            createdAt: 1700000000 + i * 100,
            giftWrapId: 'gw_$i',
          );
        }

        final stream = dao.watchMessagesForConversation(
          conversationId1,
          limit: 2,
        );
        final results = await stream.first;

        expect(results, hasLength(2));
      });

      test('emits empty list for non-existent conversation', () async {
        final stream = dao.watchMessagesForConversation('nonexistent');
        final results = await stream.first;
        expect(results, isEmpty);
      });
    });

    group('hasGiftWrap', () {
      test('returns true when gift wrap ID exists', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Hello!',
          createdAt: 1700000000,
          giftWrapId: 'gw_unique_123',
        );

        final exists = await dao.hasGiftWrap('gw_unique_123');
        expect(exists, isTrue);
      });

      test('returns false when gift wrap ID does not exist', () async {
        final exists = await dao.hasGiftWrap('gw_nonexistent');
        expect(exists, isFalse);
      });

      test('returns false when table is empty', () async {
        final exists = await dao.hasGiftWrap('gw_any');
        expect(exists, isFalse);
      });
    });

    group('deleteConversationMessages', () {
      test('deletes all messages in a conversation', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Msg 1',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'Msg 2',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
        );
        await dao.insertMessage(
          id: 'msg_3',
          conversationId: conversationId2,
          senderPubkey: 'pubkey_alice',
          content: 'Other conv',
          createdAt: 1700000200,
          giftWrapId: 'gw_3',
        );

        final deleted = await dao.deleteConversationMessages(conversationId1);

        expect(deleted, equals(2));
        final conv1Msgs = await dao.getMessagesForConversation(conversationId1);
        expect(conv1Msgs, isEmpty);
        final conv2Msgs = await dao.getMessagesForConversation(conversationId2);
        expect(conv2Msgs, hasLength(1));
      });

      test('returns 0 when conversation has no messages', () async {
        final deleted = await dao.deleteConversationMessages('nonexistent');
        expect(deleted, equals(0));
      });
    });

    group('deleteMessage', () {
      test('deletes single message by ID', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Msg 1',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'Msg 2',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
        );

        final deleted = await dao.deleteMessage('msg_1');

        expect(deleted, equals(1));
        final results = await dao.getMessagesForConversation(conversationId1);
        expect(results, hasLength(1));
        expect(results.first.id, equals('msg_2'));
      });

      test('returns 0 for non-existent message', () async {
        final deleted = await dao.deleteMessage('nonexistent');
        expect(deleted, equals(0));
      });
    });

    group('countMessages', () {
      test('returns count of messages in a conversation', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Msg 1',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_bob',
          content: 'Msg 2',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
        );
        await dao.insertMessage(
          id: 'msg_3',
          conversationId: conversationId2,
          senderPubkey: 'pubkey_alice',
          content: 'Other conv',
          createdAt: 1700000200,
          giftWrapId: 'gw_3',
        );

        final count = await dao.countMessages(conversationId1);
        expect(count, equals(2));
      });

      test('returns 0 for conversation with no messages', () async {
        final count = await dao.countMessages('nonexistent');
        expect(count, equals(0));
      });
    });

    group('clearAll', () {
      test('deletes all direct messages', () async {
        await dao.insertMessage(
          id: 'msg_1',
          conversationId: conversationId1,
          senderPubkey: 'pubkey_alice',
          content: 'Msg 1',
          createdAt: 1700000000,
          giftWrapId: 'gw_1',
        );
        await dao.insertMessage(
          id: 'msg_2',
          conversationId: conversationId2,
          senderPubkey: 'pubkey_bob',
          content: 'Msg 2',
          createdAt: 1700000100,
          giftWrapId: 'gw_2',
        );

        final deleted = await dao.clearAll();

        expect(deleted, equals(2));
        final conv1 = await dao.getMessagesForConversation(conversationId1);
        final conv2 = await dao.getMessagesForConversation(conversationId2);
        expect(conv1, isEmpty);
        expect(conv2, isEmpty);
      });

      test('returns 0 when table is empty', () async {
        final deleted = await dao.clearAll();
        expect(deleted, equals(0));
      });
    });
  });
}

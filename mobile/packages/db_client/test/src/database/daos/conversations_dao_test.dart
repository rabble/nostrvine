// ABOUTME: Unit tests for ConversationsDao with CRUD, reactive watch streams,
// ABOUTME: unread counts, and ordering operations.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event_kind.dart';

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
        expect(result.participantPubkeys, equals('["pubkey_a","pubkey_b"]'));
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

      test(
        'does not overwrite newer preview with older timestamp (out-of-order '
        'gift-wrap protection)',
        () async {
          // Simulate newer message arriving first.
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Newer message',
            lastMessageTimestamp: 1700000200,
            lastMessageSenderPubkey: 'pubkey_b',
          );

          // Out-of-order older message arrives — must NOT overwrite preview.
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Older stale message',
            lastMessageTimestamp: 1700000100,
            lastMessageSenderPubkey: 'pubkey_a',
          );

          final result = await dao.getConversation('conv_1');
          expect(result, isNotNull);
          expect(result!.lastMessageContent, equals('Newer message'));
          expect(result.lastMessageTimestamp, equals(1700000200));
          expect(result.lastMessageSenderPubkey, equals('pubkey_b'));
        },
      );

      test('updates preview when new timestamp is strictly newer', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["pubkey_a","pubkey_b"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageContent: 'First message',
          lastMessageTimestamp: 1700000100,
          lastMessageSenderPubkey: 'pubkey_a',
        );

        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["pubkey_a","pubkey_b"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageContent: 'Second message',
          lastMessageTimestamp: 1700000200,
          lastMessageSenderPubkey: 'pubkey_b',
        );

        final result = await dao.getConversation('conv_1');
        expect(result, isNotNull);
        expect(result!.lastMessageContent, equals('Second message'));
        expect(result.lastMessageTimestamp, equals(1700000200));
        expect(result.lastMessageSenderPubkey, equals('pubkey_b'));
      });

      test(
        'forceUpdateLastMessage overwrites even with older timestamp',
        () async {
          // Simulate newer preview already stored.
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Newer message',
            lastMessageTimestamp: 1700000200,
            lastMessageSenderPubkey: 'pubkey_b',
          );

          // Force refresh with older-but-correct remaining message
          // (post-delete).
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Remaining older message',
            lastMessageTimestamp: 1700000100,
            lastMessageSenderPubkey: 'pubkey_a',
            forceUpdateLastMessage: true,
          );

          final result = await dao.getConversation('conv_1');
          expect(result, isNotNull);
          expect(result!.lastMessageContent, equals('Remaining older message'));
          expect(result.lastMessageTimestamp, equals(1700000100));
          expect(result.lastMessageSenderPubkey, equals('pubkey_a'));
        },
      );

      test(
        'currentUserHasSent is only ever flipped true, never back to false',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000000,
            currentUserHasSent: true,
          );

          // Incoming message from other party with currentUserHasSent: false
          // must not clear the existing true value.
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000000,
          );

          final result = await dao.getConversation('conv_1');
          expect(result, isNotNull);
          expect(result!.currentUserHasSent, isTrue);
        },
      );

      test(
        'preserves existing nullable fields when conflict update omits them',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: true,
            createdAt: 1700000000,
            subject: 'Original Subject',
            ownerPubkey: 'owner_a',
            dmProtocol: 'nip04',
          );

          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b","pubkey_c"]',
            isGroup: true,
            createdAt: 1700000100,
          );

          final result = await dao.getConversation('conv_1');
          expect(result, isNotNull);
          expect(result!.subject, equals('Original Subject'));
          expect(result.ownerPubkey, equals('owner_a'));
          expect(result.dmProtocol, equals('nip04'));
        },
      );

      test(
        'overwrites nullable fields when conflict update provides values',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000000,
            subject: 'Original Subject',
            ownerPubkey: 'owner_a',
            dmProtocol: 'nip04',
          );

          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["pubkey_a","pubkey_b"]',
            isGroup: false,
            createdAt: 1700000100,
            subject: 'Updated Subject',
            ownerPubkey: 'owner_b',
            dmProtocol: 'nip17',
          );

          final result = await dao.getConversation('conv_1');
          expect(result, isNotNull);
          expect(result!.subject, equals('Updated Subject'));
          expect(result.ownerPubkey, equals('owner_b'));
          expect(result.dmProtocol, equals('nip17'));
        },
      );

      test('preserves original createdAt on conflict update', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["pubkey_a","pubkey_b"]',
          isGroup: false,
          createdAt: 1700000000,
        );

        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["pubkey_a","pubkey_b"]',
          isGroup: false,
          createdAt: 1700000100,
        );

        final result = await dao.getConversation('conv_1');
        expect(result, isNotNull);
        expect(result!.createdAt, equals(1700000000));
      });

      test(
        'covers every mutable conversation column in the conflict contract',
        () {
          final schemaColumns = database.conversations.$columns
              .map((column) => column.$name)
              .toSet();
          const immutableColumns = {'id', 'created_at'};
          const handledColumns = {
            'participant_pubkeys',
            'is_group',
            'last_message_content',
            'last_message_timestamp',
            'last_message_sender_pubkey',
            'subject',
            'is_read',
            'current_user_has_sent',
            'owner_pubkey',
            'dm_protocol',
          };

          expect(
            handledColumns,
            unorderedEquals(schemaColumns.difference(immutableColumns)),
          );
        },
      );
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

    group('isRead conflict semantics', () {
      test(
        'older backfill wrap does not re-mark a read conversation unread',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Newer received',
            lastMessageTimestamp: 1700000200,
            lastMessageSenderPubkey: 'b',
            isRead: false,
          );
          await dao.markAsRead('conv_1');

          // A delayed older received wrap arrives during backfill.
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Older backfill',
            lastMessageTimestamp: 1700000100,
            lastMessageSenderPubkey: 'b',
            isRead: false,
          );

          final result = await dao.getConversation('conv_1');
          expect(result!.isRead, isTrue);
        },
      );

      test(
        'forceUpdateLastMessage refresh preserves unread read state',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Unread received',
            lastMessageTimestamp: 1700000200,
            lastMessageSenderPubkey: 'b',
            isRead: false,
          );

          // Deletion preview refresh: older replacement, isRead defaults true.
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Remaining older message',
            lastMessageTimestamp: 1700000100,
            lastMessageSenderPubkey: 'a',
            forceUpdateLastMessage: true,
          );

          final result = await dao.getConversation('conv_1');
          // Preview force-updates...
          expect(result!.lastMessageContent, equals('Remaining older message'));
          expect(result.lastMessageTimestamp, equals(1700000100));
          // ...but read state is untouched.
          expect(result.isRead, isFalse);
        },
      );

      test(
        're-ingesting the latest wrap (equal timestamp) preserves read state',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Received',
            lastMessageTimestamp: 1700000200,
            lastMessageSenderPubkey: 'b',
            isRead: false,
          );
          await dao.markAsRead('conv_1');

          // Reconcile / re-drain replays the same wrap (equal timestamp).
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Received',
            lastMessageTimestamp: 1700000200,
            lastMessageSenderPubkey: 'b',
            isRead: false,
          );

          final result = await dao.getConversation('conv_1');
          expect(result!.isRead, isTrue);
        },
      );

      test(
        'a genuinely newer received message marks a read conversation unread',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'First',
            lastMessageTimestamp: 1700000100,
            lastMessageSenderPubkey: 'b',
            isRead: false,
          );
          await dao.markAsRead('conv_1');

          // New received message — strictly newer.
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Second',
            lastMessageTimestamp: 1700000200,
            lastMessageSenderPubkey: 'b',
            isRead: false,
          );

          final result = await dao.getConversation('conv_1');
          expect(result!.isRead, isFalse);
        },
      );

      test(
        'an older sent wrap during drain does not mark a newer unread '
        'received conversation read',
        () async {
          // Newest message is received and still unread.
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Newer received',
            lastMessageTimestamp: 1700000200,
            lastMessageSenderPubkey: 'b',
            isRead: false,
          );

          // The reinstall drain re-ingests an OLDER message we sent
          // ourselves: ingest passes isRead: isSentByMe == true (the default
          // here), but the timestamp is older, so the strict gate must
          // preserve unread.
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["a","b"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'Older sent',
            lastMessageTimestamp: 1700000100,
            lastMessageSenderPubkey: 'a',
          );

          final result = await dao.getConversation('conv_1');
          expect(result!.isRead, isFalse);
        },
      );
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

    group('backfillLatestMessagePreviews', () {
      const userA = 'pubkey_a';
      const userB = 'pubkey_b';

      test(
        'updates stale preview columns to the newest non-deleted message',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["$userA","$userB"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'stale older message',
            lastMessageTimestamp: 1700000001,
            lastMessageSenderPubkey: userA,
            ownerPubkey: userA,
          );
          await database.directMessagesDao.insertMessage(
            id: 'msg_old',
            conversationId: 'conv_1',
            senderPubkey: userA,
            content: 'first',
            createdAt: 1700000001,
            giftWrapId: 'gw_old',
            ownerPubkey: userA,
          );
          await database.directMessagesDao.insertMessage(
            id: 'msg_new',
            conversationId: 'conv_1',
            senderPubkey: userB,
            content: 'latest',
            createdAt: 1700000002,
            giftWrapId: 'gw_new',
            ownerPubkey: userA,
          );

          final updated = await dao.backfillLatestMessagePreviews(
            ownerPubkey: userA,
          );

          expect(updated, equals(1));
          final conv = await dao.getConversation('conv_1', ownerPubkey: userA);
          expect(conv!.lastMessageContent, equals('latest'));
          expect(conv.lastMessageTimestamp, equals(1700000002));
          expect(conv.lastMessageSenderPubkey, equals(userB));
        },
      );

      test('converts file messages to human-readable preview text', () async {
        await dao.upsertConversation(
          id: 'conv_1',
          participantPubkeys: '["$userA","$userB"]',
          isGroup: false,
          createdAt: 1700000000,
          ownerPubkey: userA,
        );
        await database.directMessagesDao.insertMessage(
          id: 'msg_file',
          conversationId: 'conv_1',
          senderPubkey: userB,
          content: 'https://cdn.example.com/video.mp4',
          createdAt: 1700000002,
          giftWrapId: 'gw_file',
          messageKind: EventKind.fileMessage,
          fileType: 'video/mp4',
          ownerPubkey: userA,
        );

        final updated = await dao.backfillLatestMessagePreviews(
          ownerPubkey: userA,
        );

        expect(updated, equals(1));
        final conv = await dao.getConversation('conv_1', ownerPubkey: userA);
        expect(conv!.lastMessageContent, equals('Sent a video'));
        expect(conv.lastMessageTimestamp, equals(1700000002));
        expect(conv.lastMessageSenderPubkey, equals(userB));
      });

      test(
        'clears stale preview when no non-deleted messages remain',
        () async {
          await dao.upsertConversation(
            id: 'conv_1',
            participantPubkeys: '["$userA","$userB"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'stale preview',
            lastMessageTimestamp: 1700000002,
            lastMessageSenderPubkey: userB,
            ownerPubkey: userA,
          );
          await database.directMessagesDao.insertMessage(
            id: 'msg_deleted',
            conversationId: 'conv_1',
            senderPubkey: userB,
            content: 'latest',
            createdAt: 1700000002,
            giftWrapId: 'gw_deleted',
            ownerPubkey: userA,
          );
          await database.directMessagesDao.markMessageDeleted(
            'msg_deleted',
            ownerPubkey: userA,
          );

          final updated = await dao.backfillLatestMessagePreviews(
            ownerPubkey: userA,
          );

          expect(updated, equals(1));
          final conv = await dao.getConversation('conv_1', ownerPubkey: userA);
          expect(conv!.lastMessageContent, isNull);
          expect(conv.lastMessageTimestamp, isNull);
          expect(conv.lastMessageSenderPubkey, isNull);
        },
      );

      test('only updates conversations in the requested owner scope', () async {
        await dao.upsertConversation(
          id: 'conv_a',
          participantPubkeys: '["$userA","$userB"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageContent: 'stale a',
          lastMessageTimestamp: 1700000001,
          lastMessageSenderPubkey: userA,
          ownerPubkey: userA,
        );
        await dao.upsertConversation(
          id: 'conv_b',
          participantPubkeys: '["$userA","$userB"]',
          isGroup: false,
          createdAt: 1700000000,
          lastMessageContent: 'stale b',
          lastMessageTimestamp: 1700000001,
          lastMessageSenderPubkey: userA,
          ownerPubkey: userB,
        );
        await database.directMessagesDao.insertMessage(
          id: 'msg_a',
          conversationId: 'conv_a',
          senderPubkey: userB,
          content: 'fresh a',
          createdAt: 1700000002,
          giftWrapId: 'gw_a',
          ownerPubkey: userA,
        );
        await database.directMessagesDao.insertMessage(
          id: 'msg_b',
          conversationId: 'conv_b',
          senderPubkey: userB,
          content: 'fresh b',
          createdAt: 1700000002,
          giftWrapId: 'gw_b',
          ownerPubkey: userB,
        );

        final updated = await dao.backfillLatestMessagePreviews(
          ownerPubkey: userA,
        );

        expect(updated, equals(1));
        final convA = await dao.getConversation('conv_a', ownerPubkey: userA);
        final convB = await dao.getConversation('conv_b', ownerPubkey: userB);
        expect(convA!.lastMessageContent, equals('fresh a'));
        expect(convB!.lastMessageContent, equals('stale b'));
      });

      test(
        'backfills legacy ownerless conversations from scoped owner messages',
        () async {
          await dao.upsertConversation(
            id: 'conv_legacy',
            participantPubkeys: '["$userA","$userB"]',
            isGroup: false,
            createdAt: 1700000000,
            lastMessageContent: 'stale legacy preview',
            lastMessageTimestamp: 1700000001,
            lastMessageSenderPubkey: userA,
          );
          await database.directMessagesDao.insertMessage(
            id: 'msg_legacy',
            conversationId: 'conv_legacy',
            senderPubkey: userB,
            content: 'fresh legacy message',
            createdAt: 1700000002,
            giftWrapId: 'gw_legacy',
            ownerPubkey: userA,
          );

          final updated = await dao.backfillLatestMessagePreviews(
            ownerPubkey: userA,
          );

          expect(updated, equals(1));
          final conv = await dao.getConversation(
            'conv_legacy',
            ownerPubkey: userA,
          );
          expect(conv!.lastMessageContent, equals('fresh legacy message'));
          expect(conv.lastMessageTimestamp, equals(1700000002));
          expect(conv.lastMessageSenderPubkey, equals(userB));
        },
      );
    });
  });
}

// dart format width=80
import 'package:db_client/src/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v10.dart' as v10;
import 'generated/schema_v11.dart' as v11;
import 'generated/schema_v12.dart' as v12;
import 'generated/schema_v9.dart' as v9;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('schema validation', () {
    test('current schema version is 12', () {
      expect(AppDatabase(NativeDatabase.memory()).schemaVersion, 12);
    });

    test('v12 schema is valid and up to date', () async {
      final schema = await verifier.schemaAt(12);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      await db.close();
    });

    test(
      'a v10 direct message arrives at v12 with no twin already absorbed',
      () async {
        // twin_collapsed defaults to false for historical rows. Defaulting the
        // other way would let a genuine duplicate through on every row that
        // predates the column, which is the bug this column exists to stop.
        // See #8211.
        await verifier.testWithDataIntegrity(
          oldVersion: 10,
          newVersion: 12,
          createOld: v10.DatabaseAtV10.new,
          createNew: v12.DatabaseAtV12.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) => batch.insert(
            oldDb.directMessages,
            v10.DirectMessagesCompanion.insert(
              id: 'e' * 64,
              conversationId: 'f' * 64,
              senderPubkey: 'a' * 64,
              content: 'a message that predates the twin marker',
              createdAt: 1700000000,
              giftWrapId: 'b' * 64,
            ),
          ),
          validateItems: (newDb) async {
            final row = await newDb.select(newDb.directMessages).getSingle();
            expect(row.content, 'a message that predates the twin marker');
            expect(row.twinCollapsed, 0);
          },
        );
      },
    );

    test(
      'a v9 direct message survives the upgrade with no pending deletion',
      () async {
        // The v10 columns are additive and nullable: an existing message must
        // arrive at current carrying no deletion, so the retry sweep does not pick
        // up every historical row as work. See #8165.
        await verifier.testWithDataIntegrity(
          oldVersion: 9,
          newVersion: 12,
          createOld: v9.DatabaseAtV9.new,
          createNew: v12.DatabaseAtV12.new,
          openTestedDatabase: AppDatabase.new,
          createItems: (batch, oldDb) => batch.insert(
            oldDb.directMessages,
            v9.DirectMessagesCompanion.insert(
              id: 'a' * 64,
              conversationId: 'b' * 64,
              senderPubkey: 'c' * 64,
              content: 'a message that predates the deletion columns',
              createdAt: 1700000000,
              giftWrapId: 'd' * 64,
            ),
          ),
          validateItems: (newDb) async {
            final row = await newDb.select(newDb.directMessages).getSingle();
            expect(row.content, 'a message that predates the deletion columns');
            expect(row.deletionRumorJson, isNull);
            expect(row.deletionPublishStatus, isNull);
          },
        );
      },
    );

    test('v8 schema migrates to v12', () async {
      final schema = await verifier.schemaAt(8);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      const conversationId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const ownerPubkey =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      await db.removedConversationsDao.record(
        conversationId: conversationId,
        ownerPubkey: ownerPubkey,
        removedAt: 1700000000,
      );
      expect(
        await db.removedConversationsDao.removedAtFor(
          conversationId: conversationId,
          ownerPubkey: ownerPubkey,
        ),
        1700000000,
      );
      await db.close();
    });

    test('v7 schema migrates to v12', () async {
      final schema = await verifier.schemaAt(7);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      await db.close();
    });

    test('v6 schema migrates to v12', () async {
      final schema = await verifier.schemaAt(6);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      await db.close();
    });

    test('v5 schema migrates to v12', () async {
      final schema = await verifier.schemaAt(5);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      await db.close();
    });

    test('v3 schema migrates to v12', () async {
      final schema = await verifier.schemaAt(3);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      await db.close();
    });

    test('v2 schema migrates to v12', () async {
      final schema = await verifier.schemaAt(2);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      await db.close();
    });

    test('legacy v1 schema migrates to v12', () async {
      final schema = await verifier.schemaAt(1);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);
      await db.close();
    });

    test('migrates v2 profile statistic follower timestamps', () async {
      final schema = await verifier.schemaAt(2);
      final cachedAt =
          DateTime.now()
              .subtract(const Duration(hours: 10))
              .millisecondsSinceEpoch ~/
          1000;

      schema.rawDatabase.execute(
        'INSERT INTO profile_statistics '
        '(pubkey, video_count, follower_count, following_count, total_views, '
        'total_likes, cached_at) '
        'VALUES (?, NULL, ?, ?, NULL, NULL, ?)',
        ['withcounts', 12, 7, cachedAt],
      );
      schema.rawDatabase.execute(
        'INSERT INTO profile_statistics '
        '(pubkey, video_count, follower_count, following_count, total_views, '
        'total_likes, cached_at) '
        'VALUES (?, NULL, NULL, NULL, NULL, NULL, ?)',
        ['withoutcounts', cachedAt],
      );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);

      final rows = await db
          .customSelect(
            'SELECT pubkey, follower_counts_updated_at '
            'FROM profile_statistics ORDER BY pubkey',
          )
          .get();
      final byPubkey = {
        for (final row in rows) row.read<String>('pubkey'): row,
      };

      expect(
        byPubkey['withcounts']!.read<int?>('follower_counts_updated_at'),
        cachedAt,
      );
      expect(byPubkey.containsKey('withoutcounts'), isFalse);
      await db.close();
    });

    test('v2 identity_events rows survive the upgrade unstamped', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 12,
        createOld: v2.DatabaseAtV2.new,
        createNew: v12.DatabaseAtV12.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.insert(
          oldDb.identityEvents,
          v2.IdentityEventsData(
            pubkey: 'a' * 64,
            tagsJson: '[["i","github:alice","proof-a"]]',
            sourceKind: 10011,
          ),
        ),
        validateItems: (newDb) async {
          final row = await newDb.select(newDb.identityEvents).getSingle();
          expect(row.tagsJson, '[["i","github:alice","proof-a"]]');
          expect(row.sourceKind, 10011);
          // Nothing knows which event a pre-upgrade row came from, so it
          // stays out of the staleness comparison until the next read
          // stamps it.
          expect(row.sourceCreatedAt, null);
          expect(row.sourceEventId, null);
        },
      );
    });

    test(
      'v2 clips survive the migration uncategorized and unarchived',
      () async {
        final schema = await verifier.schemaAt(2);
        schema.rawDatabase.execute(
          'INSERT INTO clips (id, duration_ms, recorded_at, data) '
          'VALUES (?, ?, ?, ?)',
          ['clip-1', 3000, 1700000000, '{}'],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 12);

        final migrated = await db.clipsDao.getClipById('clip-1');
        expect(migrated?.id, 'clip-1');
        expect(migrated?.categoryId, null);
        expect(migrated?.archivedAt, null);
        await db.close();
      },
    );

    test(
      'v3 clips survive the migration uncategorized and unarchived',
      () async {
        final schema = await verifier.schemaAt(3);
        schema.rawDatabase.execute(
          'INSERT INTO clips (id, duration_ms, recorded_at, data) '
          'VALUES (?, ?, ?, ?)',
          ['clip-1', 3000, 1700000000, '{}'],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 12);

        final migrated = await db.clipsDao.getClipById('clip-1');
        expect(migrated?.id, 'clip-1');
        expect(migrated?.categoryId, null);
        expect(migrated?.archivedAt, null);
        await db.close();
      },
    );

    test('v6 copies a distinct pre-v5 vine id into the d-tag column', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 12,
        createOld: v3.DatabaseAtV3.new,
        createNew: v12.DatabaseAtV12.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch
            ..insert(
              oldDb.pendingViewEvents,
              v3.PendingViewEventsCompanion.insert(
                id: 'queued-with-d-tag',
                videoId: 'b' * 64,
                videoPubkey: 'c' * 64,
                videoVineId: const Value('the-d-tag'),
                userPubkey: 'd' * 64,
                watchDurationMs: 4200,
                trafficSource: 'feed',
                status: 'pending',
                createdAt:
                    DateTime.utc(2026, 8, 12).millisecondsSinceEpoch ~/ 1000,
              ),
            )
            ..insert(
              oldDb.pendingViewEvents,
              v3.PendingViewEventsCompanion.insert(
                id: 'queued-event-id-fallback',
                videoId: 'e' * 64,
                videoPubkey: 'c' * 64,
                videoVineId: Value('e' * 64),
                userPubkey: 'd' * 64,
                watchDurationMs: 2500,
                trafficSource: 'feed',
                status: 'pending',
                createdAt:
                    DateTime.utc(2026, 8, 12).millisecondsSinceEpoch ~/ 1000,
              ),
            );
        },
        validateItems: (newDb) async {
          final rows = await newDb.select(newDb.pendingViewEvents).get();
          expect(rows, hasLength(2));
          final byId = {for (final row in rows) row.id: row};
          expect(byId['queued-with-d-tag']!.videoAddressableDTag, 'the-d-tag');
          expect(byId['queued-event-id-fallback']!.videoAddressableDTag, null);
        },
      );
    });

    test('v7 queued view rows gain a NULL phase at v8', () async {
      final schema = await verifier.schemaAt(7);
      schema.rawDatabase.execute(
        'INSERT INTO pending_view_events '
        '(id, video_id, video_pubkey, user_pubkey, watch_duration_ms, '
        'traffic_source, status, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'legacy-row',
          'b' * 64,
          'c' * 64,
          'd' * 64,
          4200,
          'feed',
          'pending',
          1786483200,
        ],
      );

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);

      final row = await db
          .customSelect(
            'SELECT phase FROM pending_view_events WHERE id = ?',
            variables: [Variable.withString('legacy-row')],
          )
          .getSingle();
      // Pre-phase rows must stay NULL: the replay path publishes them without
      // a phase tag so the relay still counts their view.
      expect(row.read<String?>('phase'), isNull);

      // And post-upgrade rows can carry the two-phase marker.
      await db.customStatement(
        'INSERT INTO pending_view_events '
        '(id, video_id, video_pubkey, user_pubkey, watch_duration_ms, '
        'traffic_source, status, created_at, phase) '
        "VALUES ('start-row', '${'b' * 64}', '${'c' * 64}', '${'d' * 64}', "
        "0, 'feed', 'pending', 1786483201, 'start')",
      );
      final phased = await db
          .customSelect(
            'SELECT phase FROM pending_view_events WHERE id = ?',
            variables: [Variable.withString('start-row')],
          )
          .getSingle();
      expect(phased.read<String?>('phase'), 'start');
      await db.close();
    });

    test(
      'v5 restores the follower column on an original-v3 database',
      () async {
        final schema = await verifier.schemaAt(3);
        // #6911 redefined v3 in place, so a database cut at the original v3
        // reports user_version 3 without the follower column — and hadUpgrade
        // suppresses the beforeOpen repair during the 3 -> 4 open.
        schema.rawDatabase.execute(
          'ALTER TABLE profile_statistics '
          'DROP COLUMN follower_counts_updated_at',
        );
        final cachedAt =
            DateTime.now()
                .subtract(const Duration(hours: 10))
                .millisecondsSinceEpoch ~/
            1000;
        schema.rawDatabase.execute(
          'INSERT INTO profile_statistics '
          '(pubkey, video_count, follower_count, following_count, total_views, '
          'total_likes, cached_at) '
          'VALUES (?, NULL, ?, ?, NULL, NULL, ?)',
          ['healme', 12, 7, cachedAt],
        );

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 12);

        final row = await db
            .customSelect(
              'SELECT follower_counts_updated_at FROM profile_statistics '
              'WHERE pubkey = ?',
              variables: [Variable.withString('healme')],
            )
            .getSingle();
        expect(row.read<int?>('follower_counts_updated_at'), cachedAt);
        await db.close();
      },
    );

    test('v7 backfills the consolidated indexes onto a v6 database', () async {
      // The `List<Index>` getters these replace were never read by Drift, so
      // a v6 database has none of them. Folding the backfill into an earlier
      // `from <` block would silently skip every database already at v6.
      const consolidated = <String>[
        'idx_metrics_loop_count',
        'idx_metrics_likes',
        'idx_metrics_views',
        'idx_hashtag_video_count',
        'idx_notification_timestamp',
        'idx_notification_is_read',
        'idx_notification_owner_timestamp',
        'idx_pending_upload_status',
        'idx_pending_upload_created',
        'idx_personal_reactions_user',
        'idx_personal_reactions_reaction_id',
        'idx_personal_reactions_addressable_id',
        'idx_personal_reposts_user',
        'idx_personal_reposts_repost_id',
        'idx_personal_reposts_user_created',
      ];

      final schema = await verifier.schemaAt(6);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 12);

      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final present = rows.map((row) => row.read<String>('name')).toSet();
      expect(present, containsAll(consolidated));
      await db.close();
    });
  });

  group('v12 blocked-retraction repair', () {
    // A delete-for-everyone the recipient's send policy refused was left
    // soft-deleted and terminal: the sweep needs `deletion_pending`, and
    // `deleteMessageForEveryone` returns early on `is_deleted`. The repair
    // clears `is_deleted` so the message and its re-tap come back, and keeps
    // the status as the durable record of the refusal. See #8284.
    final sender = 'a' * 64;
    final peer = 'b' * 64;
    final other = 'c' * 64;
    final conversationId = 'd' * 64;
    const rumorJson = '{"kind":5,"content":""}';

    Future<void> runRepair({
      required String participantPubkeys,
      required Value<int> isGroup,
      required Value<String?> deletionPublishStatus,
      required Future<void> Function(v12.DirectMessagesData row) validate,
      Value<String?> deletionRumorJson = const Value(rumorJson),
    }) async {
      await verifier.testWithDataIntegrity(
        oldVersion: 11,
        newVersion: 12,
        createOld: v11.DatabaseAtV11.new,
        createNew: v12.DatabaseAtV12.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insert(
            oldDb.conversations,
            v11.ConversationsCompanion.insert(
              id: conversationId,
              participantPubkeys: participantPubkeys,
              isGroup: isGroup,
              createdAt: 1700000000,
              ownerPubkey: Value(sender),
            ),
          );
          batch.insert(
            oldDb.directMessages,
            v11.DirectMessagesCompanion.insert(
              id: 'e' * 64,
              conversationId: conversationId,
              senderPubkey: sender,
              content: 'a message the sender believes was retracted',
              createdAt: 1700000000,
              giftWrapId: 'f' * 64,
              isDeleted: const Value(1),
              ownerPubkey: Value(sender),
              deletionRumorJson: deletionRumorJson,
              deletionPublishStatus: deletionPublishStatus,
            ),
          );
        },
        validateItems: (newDb) async {
          await validate(await newDb.select(newDb.directMessages).getSingle());
        },
      );
    }

    test('restores a one-to-one retraction every recipient refused', () async {
      // One recipient after the sender is dropped, so `deletion_blocked` here
      // cannot be the mixed fan-out: an accepting recipient would have left no
      // failure to classify.
      await runRepair(
        participantPubkeys: '["$sender","$peer"]',
        isGroup: const Value(0),
        deletionPublishStatus: const Value('deletion_blocked'),
        validate: (row) async {
          expect(row.isDeleted, 0);
          // The refusal stays on the record: it keeps the row off the retry
          // sweep and is what marks the restored bubble.
          expect(row.deletionPublishStatus, 'deletion_blocked');
          expect(row.deletionRumorJson, rumorJson);
        },
      );
    });

    test('leaves a group retraction hidden', () async {
      // Two recipients: the row cannot say whether both refused or only one
      // did while the other dropped the message. Un-hiding would claim it is
      // still there for a thread that mostly retracted it.
      await runRepair(
        participantPubkeys: '["$sender","$peer","$other"]',
        isGroup: const Value(1),
        deletionPublishStatus: const Value('deletion_blocked'),
        validate: (row) async {
          expect(row.isDeleted, 1);
          expect(row.deletionPublishStatus, 'deletion_blocked');
        },
      );
    });

    test('leaves a retraction whose conversation is gone hidden', () async {
      // Nothing proves one-to-one when the conversation row is absent, so the
      // count comes back zero and the row is left alone rather than restored
      // on an assumption.
      await verifier.testWithDataIntegrity(
        oldVersion: 11,
        newVersion: 12,
        createOld: v11.DatabaseAtV11.new,
        createNew: v12.DatabaseAtV12.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) => batch.insert(
          oldDb.directMessages,
          v11.DirectMessagesCompanion.insert(
            id: 'e' * 64,
            conversationId: conversationId,
            senderPubkey: sender,
            content: 'a message whose conversation row is gone',
            createdAt: 1700000000,
            giftWrapId: 'f' * 64,
            isDeleted: const Value(1),
            ownerPubkey: Value(sender),
            deletionRumorJson: const Value(rumorJson),
            deletionPublishStatus: const Value('deletion_blocked'),
          ),
        ),
        validateItems: (newDb) async {
          final row = await newDb.select(newDb.directMessages).getSingle();
          expect(row.isDeleted, 1);
        },
      );
    });

    test('leaves a confirmed retraction hidden', () async {
      // `deletion_sent` means every recipient's wrap was confirmed. That
      // message really is gone for them; restoring it would resurrect it for
      // the sender alone and invite a second kind-5 for a retraction that
      // already landed. The success path nulls the rumor, so the fixture does
      // too.
      await runRepair(
        participantPubkeys: '["$sender","$peer"]',
        isGroup: const Value(0),
        deletionPublishStatus: const Value('deletion_sent'),
        deletionRumorJson: const Value(null),
        validate: (row) async {
          expect(row.isDeleted, 1);
          expect(row.deletionPublishStatus, 'deletion_sent');
        },
      );
    });

    test(
      'leaves a multi-recipient retraction hidden with no group flag',
      () async {
        // The participant count is the load-bearing guard, not `is_group`: two
        // recipients is a fan-out whose refusal the row cannot tell apart from a
        // partial one, however the conversation happens to be flagged.
        await runRepair(
          participantPubkeys: '["$sender","$peer","$other"]',
          isGroup: const Value(0),
          deletionPublishStatus: const Value('deletion_blocked'),
          validate: (row) async => expect(row.isDeleted, 1),
        );
      },
    );

    test(
      'leaves a one-participant conversation flagged as a group hidden',
      () async {
        // A legacy row inflated to a group and since collapsed to one
        // participant is not provably one-to-one, so it fails closed.
        await runRepair(
          participantPubkeys: '["$sender","$peer"]',
          isGroup: const Value(1),
          deletionPublishStatus: const Value('deletion_blocked'),
          validate: (row) async => expect(row.isDeleted, 1),
        );
      },
    );

    test('leaves a retraction still awaiting delivery hidden', () async {
      // `deletion_pending` is not a refusal — the sweep still owns it, and it
      // may yet be delivered.
      await runRepair(
        participantPubkeys: '["$sender","$peer"]',
        isGroup: const Value(0),
        deletionPublishStatus: const Value('deletion_pending'),
        validate: (row) async {
          expect(row.isDeleted, 1);
          expect(row.deletionPublishStatus, 'deletion_pending');
        },
      );
    });

    test('leaves a peer-applied deletion hidden', () async {
      // An inbound kind-5 applied locally by `markMessageDeleted` sets
      // `is_deleted` with no status. Restoring it would resurrect a message
      // its author retracted.
      await runRepair(
        participantPubkeys: '["$sender","$peer"]',
        isGroup: const Value(0),
        deletionPublishStatus: const Value(null),
        validate: (row) async {
          expect(row.isDeleted, 1);
          expect(row.deletionPublishStatus, isNull);
        },
      );
    });

    test(
      'leaves a retraction with an unreadable participant list hidden',
      () async {
        // The repair must be total over whatever is on disk: an unparseable
        // participant list cannot prove one-to-one, and must not abort the
        // upgrade either.
        await runRepair(
          participantPubkeys: 'not json',
          isGroup: const Value(0),
          deletionPublishStatus: const Value('deletion_blocked'),
          validate: (row) async => expect(row.isDeleted, 1),
        );
      },
    );
  });
}

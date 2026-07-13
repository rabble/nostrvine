// ABOUTME: Unit tests for PendingProfileSavesDao — the durable single-row
// ABOUTME: per-user profile/username save slot (#3161). Covers upsert
// ABOUTME: replace-latest, status transitions, retry, reset, clear, watch.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late PendingProfileSavesDao dao;
  late String tempDbPath;

  const userA =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const userB =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  PendingProfileSaveEntry makeEntry({
    String userPubkey = userA,
    String payloadJson = '{"display_name":"alice"}',
    bool claimConfirmed = false,
    PendingProfileSaveStatus status = PendingProfileSaveStatus.pending,
    int retryCount = 0,
    DateTime? queuedAt,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return PendingProfileSaveEntry(
      userPubkey: userPubkey,
      payloadJson: payloadJson,
      claimConfirmed: claimConfirmed,
      status: status,
      retryCount: retryCount,
      queuedAt: queuedAt ?? DateTime.utc(2026, 7, 13),
      lastAttemptAt: lastAttemptAt,
      lastError: lastError,
    );
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'pending_profile_saves_test_',
    );
    tempDbPath = '${tempDir.path}/test.db';
    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.pendingProfileSavesDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) file.deleteSync();
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group(PendingProfileSavesDao, () {
    group('upsert / get', () {
      test('inserts a pending save with all fields round-tripped', () async {
        await dao.upsert(
          makeEntry(
            claimConfirmed: true,
            retryCount: 2,
            lastAttemptAt: DateTime.utc(2026, 7, 13, 1),
            lastError: 'no relays',
          ),
        );

        final fetched = await dao.get(userA);

        expect(fetched, isNotNull);
        expect(fetched!.userPubkey, userA);
        expect(fetched.payloadJson, '{"display_name":"alice"}');
        expect(fetched.claimConfirmed, isTrue);
        expect(fetched.status, PendingProfileSaveStatus.pending);
        expect(fetched.retryCount, 2);
        // Drift's dateTime codec reads back in local time, so compare the
        // instant rather than the DateTime (whose isUtc flag would differ).
        expect(
          fetched.queuedAt.isAtSameMomentAs(DateTime.utc(2026, 7, 13)),
          isTrue,
        );
        expect(
          fetched.lastAttemptAt!.isAtSameMomentAs(DateTime.utc(2026, 7, 13, 1)),
          isTrue,
        );
        expect(fetched.lastError, 'no relays');
      });

      test('returns null when no slot exists for the pubkey', () async {
        expect(await dao.get(userA), isNull);
      });

      test('upsert replaces the existing row (latest intent wins) and '
          'resets retry/status', () async {
        await dao.upsert(
          makeEntry(
            payloadJson: '{"display_name":"old"}',
            retryCount: 4,
            status: PendingProfileSaveStatus.failed,
            lastError: 'boom',
          ),
        );

        await dao.upsert(
          makeEntry(payloadJson: '{"display_name":"new"}'),
        );

        final fetched = await dao.get(userA);
        expect(fetched!.payloadJson, '{"display_name":"new"}');
        expect(fetched.retryCount, 0);
        expect(fetched.status, PendingProfileSaveStatus.pending);
        expect(fetched.lastError, isNull);
      });

      test(
        'keeps one row per user (distinct pubkeys are independent)',
        () async {
          await dao.upsert(makeEntry(payloadJson: '{"a":1}'));
          await dao.upsert(
            makeEntry(userPubkey: userB, payloadJson: '{"b":2}'),
          );

          expect((await dao.get(userA))!.payloadJson, '{"a":1}');
          expect((await dao.get(userB))!.payloadJson, '{"b":2}');
        },
      );
    });

    group('markStatus', () {
      test('updates status + stamps lastAttemptAt', () async {
        await dao.upsert(makeEntry());
        final ok = await dao.markStatus(
          userPubkey: userA,
          status: PendingProfileSaveStatus.syncing,
        );
        expect(ok, isTrue);
        final fetched = await dao.get(userA);
        expect(fetched!.status, PendingProfileSaveStatus.syncing);
        expect(fetched.lastAttemptAt, isNotNull);
      });

      test('writes lastError when moving to failed', () async {
        await dao.upsert(makeEntry());
        await dao.markStatus(
          userPubkey: userA,
          status: PendingProfileSaveStatus.failed,
          lastError: 'gave up',
        );
        final fetched = await dao.get(userA);
        expect(fetched!.status, PendingProfileSaveStatus.failed);
        expect(fetched.lastError, 'gave up');
      });

      test('returns false when no row exists', () async {
        expect(
          await dao.markStatus(
            userPubkey: userA,
            status: PendingProfileSaveStatus.syncing,
          ),
          isFalse,
        );
      });
    });

    group('markClaimConfirmed', () {
      test('flips claim_confirmed to true', () async {
        await dao.upsert(makeEntry());
        final ok = await dao.markClaimConfirmed(userA);
        expect(ok, isTrue);
        expect((await dao.get(userA))!.claimConfirmed, isTrue);
      });
    });

    group('incrementRetry', () {
      test('increments retry count and stamps lastAttemptAt', () async {
        await dao.upsert(makeEntry(retryCount: 1));
        final ok = await dao.incrementRetry(userA);
        expect(ok, isTrue);
        final fetched = await dao.get(userA);
        expect(fetched!.retryCount, 2);
        expect(fetched.lastAttemptAt, isNotNull);
      });

      test('returns false when no row exists', () async {
        expect(await dao.incrementRetry(userA), isFalse);
      });
    });

    group('resetSyncingToPending', () {
      test(
        'moves a syncing row back to pending (cold-start recovery)',
        () async {
          await dao.upsert(
            makeEntry(status: PendingProfileSaveStatus.syncing),
          );
          final affected = await dao.resetSyncingToPending(userA);
          expect(affected, 1);
          expect(
            (await dao.get(userA))!.status,
            PendingProfileSaveStatus.pending,
          );
        },
      );

      test('leaves a failed row untouched', () async {
        await dao.upsert(makeEntry(status: PendingProfileSaveStatus.failed));
        final affected = await dao.resetSyncingToPending(userA);
        expect(affected, 0);
        expect((await dao.get(userA))!.status, PendingProfileSaveStatus.failed);
      });
    });

    group('clear', () {
      test('deletes the slot for the pubkey', () async {
        await dao.upsert(makeEntry());
        final deleted = await dao.clear(userA);
        expect(deleted, 1);
        expect(await dao.get(userA), isNull);
      });
    });

    group('generation guard', () {
      test('upsert mints and returns a fresh token; a replacement '
          'upsert returns a different one', () async {
        final genA = await dao.upsert(makeEntry());
        expect(genA, isNotEmpty);
        expect((await dao.get(userA))!.generation, genA);

        final genB = await dao.upsert(
          makeEntry(payloadJson: '{"display_name":"b"}'),
        );
        expect(genB, isNot(genA));
        expect((await dao.get(userA))!.generation, genB);
      });

      test('upsert preserves a caller-supplied non-empty generation', () async {
        final returned = await dao.upsert(
          PendingProfileSaveEntry(
            userPubkey: userA,
            payloadJson: '{"display_name":"alice"}',
            queuedAt: DateTime.utc(2026, 7, 13),
            generation: 'gen-fixed',
          ),
        );
        expect(returned, 'gen-fixed');
        expect((await dao.get(userA))!.generation, 'gen-fixed');
      });

      test('markStatus with a stale generation is a no-op', () async {
        final gen = await dao.upsert(makeEntry());
        // A newer save replaces the row (fresh generation).
        await dao.upsert(makeEntry(payloadJson: '{"display_name":"new"}'));

        final ok = await dao.markStatus(
          userPubkey: userA,
          status: PendingProfileSaveStatus.syncing,
          generation: gen,
        );

        expect(ok, isFalse);
        expect(
          (await dao.get(userA))!.status,
          PendingProfileSaveStatus.pending,
          reason: 'the newer row must keep its status',
        );
      });

      test('markStatus with the matching generation applies', () async {
        final gen = await dao.upsert(makeEntry());
        final ok = await dao.markStatus(
          userPubkey: userA,
          status: PendingProfileSaveStatus.syncing,
          generation: gen,
        );
        expect(ok, isTrue);
        expect(
          (await dao.get(userA))!.status,
          PendingProfileSaveStatus.syncing,
        );
      });

      test('clear with a stale generation keeps the (newer) row', () async {
        final gen = await dao.upsert(makeEntry());
        await dao.upsert(makeEntry(payloadJson: '{"display_name":"new"}'));

        final deleted = await dao.clear(userA, generation: gen);

        expect(deleted, 0);
        final row = await dao.get(userA);
        expect(row, isNotNull);
        expect(row!.payloadJson, '{"display_name":"new"}');
      });

      test('markClaimConfirmed and incrementRetry no-op under a stale '
          'generation', () async {
        final gen = await dao.upsert(makeEntry(retryCount: 1));
        await dao.upsert(makeEntry(payloadJson: '{"display_name":"new"}'));

        expect(await dao.markClaimConfirmed(userA, generation: gen), isFalse);
        expect(await dao.incrementRetry(userA, generation: gen), isFalse);

        final row = await dao.get(userA);
        expect(row!.claimConfirmed, isFalse);
        expect(row.retryCount, 0, reason: 'the newer row keeps its budget');
      });

      test('markStatus/incrementRetry stamp the injected attemptAt', () async {
        await dao.upsert(makeEntry());
        final at = DateTime.utc(2026, 7, 13, 9, 30);

        await dao.markStatus(
          userPubkey: userA,
          status: PendingProfileSaveStatus.syncing,
          attemptAt: at,
        );
        expect(
          (await dao.get(userA))!.lastAttemptAt!.isAtSameMomentAs(at),
          isTrue,
        );

        final at2 = DateTime.utc(2026, 7, 13, 10);
        await dao.incrementRetry(userA, attemptAt: at2);
        expect(
          (await dao.get(userA))!.lastAttemptAt!.isAtSameMomentAs(at2),
          isTrue,
        );
      });
    });

    group('watch', () {
      test('emits initial null, then the row, then null after clear', () async {
        // Drain Drift's async stream emissions with pumpEventQueue() between
        // each mutation so distinct states are observed in order (no
        // coalescing of rapid DB changes).
        final emissions = <PendingProfileSaveEntry?>[];
        final sub = dao.watch(userA).listen(emissions.add);

        await pumpEventQueue();
        await dao.upsert(makeEntry(payloadJson: '{"x":1}'));
        await pumpEventQueue();
        await dao.clear(userA);
        await pumpEventQueue();
        await sub.cancel();

        expect(emissions, [
          isNull,
          isA<PendingProfileSaveEntry>().having(
            (e) => e.payloadJson,
            'payloadJson',
            '{"x":1}',
          ),
          isNull,
        ]);
      });
    });

    group('status parsing', () {
      test(
        'throws UnknownPendingProfileSaveStatusException on a bad status',
        () async {
          await dao.upsert(makeEntry());
          // Corrupt the persisted status out-of-band.
          await database.customStatement(
            "UPDATE pending_profile_saves SET status = 'bogus' "
            "WHERE user_pubkey = '$userA'",
          );
          expect(
            () => dao.get(userA),
            throwsA(isA<UnknownPendingProfileSaveStatusException>()),
          );
        },
      );
    });
  });
}

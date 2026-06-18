// ABOUTME: Tests for DmSyncState — persistence of per-pubkey DM sync
// ABOUTME: boundaries (newestSyncedAt / oldestSyncedAt) in SharedPreferences.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(DmSyncState, () {
    late SharedPreferences prefs;
    late DmSyncState state;

    const pkA = 'npub1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const pkB = 'npub1bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      state = DmSyncState(prefs);
    });

    test(
      'returns null for newestSyncedAt and oldestSyncedAt when nothing '
      'persisted',
      () {
        expect(state.newestSyncedAt(pkA), isNull);
        expect(state.oldestSyncedAt(pkA), isNull);
      },
    );

    test(
      'recordSeen sets both newest and oldest for the first event',
      () async {
        await state.recordSeen(pkA, createdAt: 1000);

        expect(state.newestSyncedAt(pkA), equals(1000));
        expect(state.oldestSyncedAt(pkA), equals(1000));
      },
    );

    test(
      'recordSeen advances newest monotonically — lower createdAt does '
      'not overwrite',
      () async {
        await state.recordSeen(pkA, createdAt: 2000);
        await state.recordSeen(pkA, createdAt: 1500);

        expect(state.newestSyncedAt(pkA), equals(2000));
      },
    );

    test(
      'recordSeen advances oldest monotonically downward — higher '
      'createdAt does not overwrite oldest',
      () async {
        await state.recordSeen(pkA, createdAt: 1000);
        await state.recordSeen(pkA, createdAt: 2000);

        expect(state.oldestSyncedAt(pkA), equals(1000));
        expect(state.newestSyncedAt(pkA), equals(2000));
      },
    );

    test(
      "recordSeen scopes state per pubkey — one user's boundary does "
      'not bleed into another',
      () async {
        await state.recordSeen(pkA, createdAt: 1000);
        await state.recordSeen(pkA, createdAt: 2000);

        expect(state.newestSyncedAt(pkB), isNull);
        expect(state.oldestSyncedAt(pkB), isNull);

        await state.recordSeen(pkB, createdAt: 5000);

        expect(state.newestSyncedAt(pkA), equals(2000));
        expect(state.oldestSyncedAt(pkA), equals(1000));
        expect(state.newestSyncedAt(pkB), equals(5000));
        expect(state.oldestSyncedAt(pkB), equals(5000));
      },
    );

    test(
      'clear removes both newest and oldest for the given pubkey and '
      'leaves others intact',
      () async {
        await state.recordSeen(pkA, createdAt: 1000);
        await state.recordSeen(pkA, createdAt: 2000);
        await state.recordSeen(pkB, createdAt: 3000);

        await state.clear(pkA);

        expect(state.newestSyncedAt(pkA), isNull);
        expect(state.oldestSyncedAt(pkA), isNull);
        expect(state.newestSyncedAt(pkB), equals(3000));
        expect(state.oldestSyncedAt(pkB), equals(3000));
      },
    );

    test(
      'clearAll removes sync state for every pubkey and leaves '
      'non-dm keys intact',
      () async {
        await state.recordSeen(pkA, createdAt: 1000);
        await state.recordSeen(pkA, createdAt: 2000);
        await state.recordSeen(pkB, createdAt: 3000);
        await prefs.setString('unrelated_key', 'keep_me');

        await state.clearAll();

        expect(state.newestSyncedAt(pkA), isNull);
        expect(state.oldestSyncedAt(pkA), isNull);
        expect(state.newestSyncedAt(pkB), isNull);
        expect(state.oldestSyncedAt(pkB), isNull);
        expect(prefs.getString('unrelated_key'), equals('keep_me'));
      },
    );

    group('historyDrainComplete', () {
      test('defaults to false when nothing persisted', () {
        expect(state.historyDrainComplete(pkA), isFalse);
      });

      test('markHistoryDrainComplete flips the flag to true', () async {
        await state.markHistoryDrainComplete(pkA);

        expect(state.historyDrainComplete(pkA), isTrue);
      });

      test('is scoped per pubkey', () async {
        await state.markHistoryDrainComplete(pkA);

        expect(state.historyDrainComplete(pkA), isTrue);
        expect(state.historyDrainComplete(pkB), isFalse);
      });

      test('clear re-arms the drain for the given pubkey only', () async {
        await state.markHistoryDrainComplete(pkA);
        await state.markHistoryDrainComplete(pkB);

        await state.clear(pkA);

        expect(state.historyDrainComplete(pkA), isFalse);
        expect(state.historyDrainComplete(pkB), isTrue);
      });

      test('clearAll re-arms the drain for every pubkey', () async {
        await state.markHistoryDrainComplete(pkA);
        await state.markHistoryDrainComplete(pkB);

        await state.clearAll();

        expect(state.historyDrainComplete(pkA), isFalse);
        expect(state.historyDrainComplete(pkB), isFalse);
      });
    });

    group('historyDrainCursor', () {
      test('defaults to null when nothing persisted', () {
        expect(state.historyDrainCursor(pkA), isNull);
      });

      test('setHistoryDrainCursor round-trips the value', () async {
        await state.setHistoryDrainCursor(pkA, 1699000000);

        expect(state.historyDrainCursor(pkA), equals(1699000000));
      });

      test('is scoped per pubkey', () async {
        await state.setHistoryDrainCursor(pkA, 1000);

        expect(state.historyDrainCursor(pkA), equals(1000));
        expect(state.historyDrainCursor(pkB), isNull);
      });

      test('markHistoryDrainComplete clears the cursor', () async {
        await state.setHistoryDrainCursor(pkA, 1000);

        await state.markHistoryDrainComplete(pkA);

        expect(state.historyDrainCursor(pkA), isNull);
        expect(state.historyDrainComplete(pkA), isTrue);
      });

      test('clear removes the cursor for the given pubkey only', () async {
        await state.setHistoryDrainCursor(pkA, 1000);
        await state.setHistoryDrainCursor(pkB, 2000);

        await state.clear(pkA);

        expect(state.historyDrainCursor(pkA), isNull);
        expect(state.historyDrainCursor(pkB), equals(2000));
      });

      test('clearAll removes the cursor for every pubkey', () async {
        await state.setHistoryDrainCursor(pkA, 1000);
        await state.setHistoryDrainCursor(pkB, 2000);

        await state.clearAll();

        expect(state.historyDrainCursor(pkA), isNull);
        expect(state.historyDrainCursor(pkB), isNull);
      });
    });

    group('drainVersion', () {
      test('defaults to 0 when never recorded', () {
        expect(state.drainVersion(pkA), equals(0));
      });

      test('setDrainVersion persists per pubkey', () async {
        await state.setDrainVersion(pkA, 2);

        expect(state.drainVersion(pkA), equals(2));
        expect(state.drainVersion(pkB), equals(0));
      });

      test(
        'upgradeDrainVersionIfNeeded clears a stale completion flag + cursor '
        'and stamps the current version when below it',
        () async {
          // Simulate an install stranded by an older, buggy drain.
          await state.markHistoryDrainComplete(pkA);
          await state.setHistoryDrainCursor(pkA, 1234);
          expect(state.historyDrainComplete(pkA), isTrue);

          await state.upgradeDrainVersionIfNeeded(pkA);

          expect(state.historyDrainComplete(pkA), isFalse);
          expect(state.historyDrainCursor(pkA), isNull);
          expect(state.drainVersion(pkA), DmSyncState.currentDrainVersion);
        },
      );

      test(
        'upgradeDrainVersionIfNeeded is idempotent at the current version',
        () async {
          await state.upgradeDrainVersionIfNeeded(pkA);
          // A genuine completion at the current version must survive a second
          // upgrade pass (no re-drain loop on every inbox open).
          await state.markHistoryDrainComplete(pkA);

          await state.upgradeDrainVersionIfNeeded(pkA);

          expect(state.historyDrainComplete(pkA), isTrue);
          expect(state.drainVersion(pkA), DmSyncState.currentDrainVersion);
        },
      );

      test(
        'forces a one-time re-drain for installs stranded at the pre-#5304 '
        'drain version (2)',
        () async {
          // #5304 bumped the drain version so installs whose earlier drain
          // completed before the user's own messages were recovered (which
          // stranded established chats under "Message requests") get one fresh
          // recovery pass under the new recovery-aware gate + NIP-04 recovery.
          expect(
            DmSyncState.currentDrainVersion,
            greaterThanOrEqualTo(3),
            reason: 'drain version must advance past the pre-#5304 value (2)',
          );

          await state.setDrainVersion(pkA, 2);
          await state.markHistoryDrainComplete(pkA);

          await state.upgradeDrainVersionIfNeeded(pkA);

          expect(state.historyDrainComplete(pkA), isFalse);
          expect(state.drainVersion(pkA), DmSyncState.currentDrainVersion);
        },
      );

      test('clear and clearAll reset the drain version', () async {
        await state.setDrainVersion(pkA, DmSyncState.currentDrainVersion);
        await state.setDrainVersion(pkB, DmSyncState.currentDrainVersion);

        await state.clear(pkA);
        expect(state.drainVersion(pkA), equals(0));
        expect(state.drainVersion(pkB), DmSyncState.currentDrainVersion);

        await state.clearAll();
        expect(state.drainVersion(pkB), equals(0));
      });
    });
  });
}

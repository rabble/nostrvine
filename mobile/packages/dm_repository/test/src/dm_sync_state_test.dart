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
  });
}

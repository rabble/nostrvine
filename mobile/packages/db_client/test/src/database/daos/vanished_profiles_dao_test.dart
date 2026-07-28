// ABOUTME: Tests for VanishedProfilesDao, the durable NIP-62 vanish marker.
// ABOUTME: Covers marking, clearing, hydration, and the reactive watch stream.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _pubkey =
    '613cb00feb0ecd7648a62740771cf60efaead56a0d19b2ac3d7b4f3c589e6fa3';
const _otherPubkey =
    '9be8bd90d818407bcf574d11b1c57f104fd53f40fa767abc4a631ee2694b43a3';

void main() {
  group(VanishedProfilesDao, () {
    late AppDatabase database;
    late VanishedProfilesDao dao;

    setUp(() {
      database = AppDatabase.test(NativeDatabase.memory());
      dao = database.vanishedProfilesDao;
    });

    tearDown(() async {
      await database.close();
    });

    test('isVanished is false for an unknown pubkey', () async {
      expect(await dao.isVanished(_pubkey), isFalse);
    });

    test('markVanished records the pubkey', () async {
      await dao.markVanished(_pubkey);

      expect(await dao.isVanished(_pubkey), isTrue);
    });

    test('markVanished does not affect other pubkeys', () async {
      await dao.markVanished(_pubkey);

      expect(await dao.isVanished(_otherPubkey), isFalse);
    });

    test('markVanished is idempotent', () async {
      await dao.markVanished(_pubkey);
      await dao.markVanished(_pubkey);

      expect(await dao.getAllPubkeys(), equals([_pubkey]));
    });

    test('clearVanished forgets the pubkey', () async {
      // The self-heal path: a wrong `deleted: true` must be recoverable
      // rather than erasing the account from this device forever.
      await dao.markVanished(_pubkey);

      final removed = await dao.clearVanished(_pubkey);

      expect(removed, equals(1));
      expect(await dao.isVanished(_pubkey), isFalse);
    });

    test('clearVanished on an unknown pubkey is a no-op', () async {
      expect(await dao.clearVanished(_pubkey), equals(0));
    });

    test('getAllPubkeys returns every marked pubkey', () async {
      await dao.markVanished(_pubkey);
      await dao.markVanished(_otherPubkey);

      expect(
        (await dao.getAllPubkeys())..sort(),
        equals([_pubkey, _otherPubkey]..sort()),
      );
    });

    group('watchIsVanished', () {
      test('emits false then true when the pubkey is marked', () async {
        final emissions = <bool>[];
        final subscription = dao.watchIsVanished(_pubkey).listen(emissions.add);

        await pumpEventQueue();
        await dao.markVanished(_pubkey);
        await pumpEventQueue();

        await subscription.cancel();
        expect(emissions, equals([false, true]));
      });

      test('emits again when the pubkey is cleared', () async {
        await dao.markVanished(_pubkey);

        final emissions = <bool>[];
        final subscription = dao.watchIsVanished(_pubkey).listen(emissions.add);

        await pumpEventQueue();
        await dao.clearVanished(_pubkey);
        await pumpEventQueue();

        await subscription.cancel();
        expect(emissions, equals([true, false]));
      });

      test('does not re-emit for an unrelated pubkey', () async {
        final emissions = <bool>[];
        final subscription = dao.watchIsVanished(_pubkey).listen(emissions.add);

        await pumpEventQueue();
        await dao.markVanished(_otherPubkey);
        await pumpEventQueue();

        await subscription.cancel();
        expect(emissions, equals([false]));
      });
    });
  });
}

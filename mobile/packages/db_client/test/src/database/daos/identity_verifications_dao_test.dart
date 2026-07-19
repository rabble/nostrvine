// ABOUTME: Unit tests for IdentityVerificationsDao (verified-claims cache).
// ABOUTME: Tests upsert (insert + replace) and primary-key lookup.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late IdentityVerificationsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const claimsJson =
      '[{"platform":"github","identity":"alice","proof":"proof-a"}]';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('identity_verif_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.identityVerificationsDao;
  });

  tearDown(() async {
    await database.close();
    final dir = File(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group(IdentityVerificationsDao, () {
    group('upsertVerification', () {
      test('inserts a new snapshot row', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          verifiedClaimsJson: claimsJson,
          checkedAtFloor: 1784422014,
        );

        final row = await dao.getVerification(testPubkey);
        expect(row, isNotNull);
        expect(row!.pubkey, equals(testPubkey));
        expect(row.verifiedClaimsJson, equals(claimsJson));
        expect(row.checkedAtFloor, equals(1784422014));
      });

      test('replaces the existing snapshot for the same pubkey', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          verifiedClaimsJson: claimsJson,
          checkedAtFloor: 100,
        );
        await dao.upsertVerification(
          pubkey: testPubkey,
          verifiedClaimsJson: '[]',
          checkedAtFloor: 200,
        );

        final row = await dao.getVerification(testPubkey);
        expect(row!.verifiedClaimsJson, equals('[]'));
        expect(row.checkedAtFloor, equals(200));
      });
    });

    group('getVerification', () {
      test('returns null when no row exists', () async {
        expect(await dao.getVerification(testPubkey), isNull);
      });
    });

    group('deleteVerification', () {
      test('removes the snapshot and reports the deleted count', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          verifiedClaimsJson: claimsJson,
          checkedAtFloor: 100,
        );

        expect(await dao.deleteVerification(testPubkey), equals(1));
        expect(await dao.getVerification(testPubkey), isNull);
      });

      test('returns 0 when no row exists', () async {
        expect(await dao.deleteVerification(testPubkey), equals(0));
      });
    });

    group('clearAll', () {
      test('removes every verification snapshot row', () async {
        const secondPubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        await dao.upsertVerification(
          pubkey: testPubkey,
          verifiedClaimsJson: claimsJson,
          checkedAtFloor: 100,
        );
        await dao.upsertVerification(
          pubkey: secondPubkey,
          verifiedClaimsJson:
              '[{"platform":"github","identity":"bob","proof":"proof-b"}]',
          checkedAtFloor: 200,
        );

        expect(await dao.clearAll(), equals(2));
        expect(await dao.getVerification(testPubkey), isNull);
        expect(await dao.getVerification(secondPubkey), isNull);
      });

      test('returns 0 when no row exists', () async {
        expect(await dao.clearAll(), equals(0));
      });
    });
  });
}

// ABOUTME: Unit tests for Nip05VerificationsDao with TTL-based cache.
// ABOUTME: Tests upsert, getValidVerification, deleteExpired, watch.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late Nip05VerificationsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const testPubkey2 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const testNip05 = 'alice@example.com';
  const testNip05_2 = 'bob@example.com';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('nip05_dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.nip05VerificationsDao;
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

  group('Nip05VerificationsDao', () {
    group('upsertVerification', () {
      test('inserts new verification', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );

        final result = await dao.getVerification(testPubkey);
        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.nip05, equals(testNip05));
        expect(result.status, equals('verified'));
      });

      test('updates existing verification with same pubkey', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'pending',
        );

        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );

        final result = await dao.getVerification(testPubkey);
        expect(result, isNotNull);
        expect(result!.status, equals('verified'));
      });

      test('sets correct TTL for verified status', () async {
        final before = DateTime.now();
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );
        final after = DateTime.now();

        final result = await dao.getVerification(testPubkey);
        expect(result, isNotNull);

        // Verified TTL is 24 hours
        final expectedExpiry = before.add(Nip05CacheTtl.verified);
        expect(
          result!.expiresAt.isAfter(
            expectedExpiry.subtract(
              const Duration(seconds: 1),
            ),
          ),
          isTrue,
        );
        expect(
          result.expiresAt.isBefore(
            after
                .add(Nip05CacheTtl.verified)
                .add(
                  const Duration(seconds: 1),
                ),
          ),
          isTrue,
        );
      });

      test('sets correct TTL for failed status', () async {
        final before = DateTime.now();
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'failed',
        );

        final result = await dao.getVerification(testPubkey);
        expect(result, isNotNull);

        // Failed TTL is 1 hour
        final expectedExpiry = before.add(Nip05CacheTtl.failed);
        expect(
          result!.expiresAt.isAfter(
            expectedExpiry.subtract(
              const Duration(seconds: 1),
            ),
          ),
          isTrue,
        );
      });

      test('sets correct TTL for error status', () async {
        final before = DateTime.now();
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'error',
        );

        final result = await dao.getVerification(testPubkey);
        expect(result, isNotNull);

        // Error TTL is 5 minutes
        final expectedExpiry = before.add(Nip05CacheTtl.error);
        expect(
          result!.expiresAt.isAfter(
            expectedExpiry.subtract(
              const Duration(seconds: 1),
            ),
          ),
          isTrue,
        );
      });

      test('handles multiple different pubkeys', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );
        await dao.upsertVerification(
          pubkey: testPubkey2,
          nip05: testNip05_2,
          status: 'failed',
        );

        final result1 = await dao.getVerification(testPubkey);
        final result2 = await dao.getVerification(testPubkey2);

        expect(result1!.status, equals('verified'));
        expect(result2!.status, equals('failed'));
      });
    });

    group('getValidVerification', () {
      test('returns verification when not expired', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );

        final result = await dao.getValidVerification(testPubkey);
        expect(result, isNotNull);
        expect(result!.status, equals('verified'));
      });

      test('returns null for non-existent pubkey', () async {
        final result = await dao.getValidVerification(testPubkey);
        expect(result, isNull);
      });

      test('returns null and deletes expired verification', () async {
        // Insert with expired timestamp directly
        final expiredTime = DateTime.now().subtract(const Duration(hours: 1));
        await database
            .into(database.nip05Verifications)
            .insert(
              Nip05VerificationsCompanion.insert(
                pubkey: testPubkey,
                nip05: testNip05,
                status: 'verified',
                verifiedAt: expiredTime,
                expiresAt: expiredTime, // Already expired
              ),
            );

        final result = await dao.getValidVerification(testPubkey);
        expect(result, isNull);

        // Verify the entry was deleted
        final rawResult = await dao.getVerification(testPubkey);
        expect(rawResult, isNull);
      });
    });

    group('getVerifications (batch)', () {
      test('returns multiple verifications', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );
        await dao.upsertVerification(
          pubkey: testPubkey2,
          nip05: testNip05_2,
          status: 'failed',
        );

        final results = await dao.getVerifications([testPubkey, testPubkey2]);
        expect(results.length, equals(2));
      });

      test('returns empty list for empty input', () async {
        final results = await dao.getVerifications([]);
        expect(results, isEmpty);
      });

      test('returns only existing verifications', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );

        final results = await dao.getVerifications([testPubkey, testPubkey2]);
        expect(results.length, equals(1));
        expect(results.first.pubkey, equals(testPubkey));
      });
    });

    group('getValidVerifications (batch)', () {
      test('returns only non-expired verifications', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );

        // Insert expired directly
        final expiredTime = DateTime.now().subtract(const Duration(hours: 1));
        await database
            .into(database.nip05Verifications)
            .insertOnConflictUpdate(
              Nip05VerificationsCompanion.insert(
                pubkey: testPubkey2,
                nip05: testNip05_2,
                status: 'verified',
                verifiedAt: expiredTime,
                expiresAt: expiredTime,
              ),
            );

        final results = await dao.getValidVerifications([
          testPubkey,
          testPubkey2,
        ]);
        expect(results.length, equals(1));
        expect(results.first.pubkey, equals(testPubkey));
      });

      test('returns empty list for empty input', () async {
        final results = await dao.getValidVerifications([]);
        expect(results, isEmpty);
      });
    });

    group('deleteVerification', () {
      test('deletes verification for a pubkey', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );
        await dao.upsertVerification(
          pubkey: testPubkey2,
          nip05: testNip05_2,
          status: 'failed',
        );

        final deleted = await dao.deleteVerification(testPubkey);
        expect(deleted, equals(1));

        final result1 = await dao.getVerification(testPubkey);
        final result2 = await dao.getVerification(testPubkey2);

        expect(result1, isNull);
        expect(result2, isNotNull);
      });

      test('returns 0 when pubkey does not exist', () async {
        final deleted = await dao.deleteVerification(testPubkey);
        expect(deleted, equals(0));
      });
    });

    group('deleteExpired', () {
      test('deletes only expired entries', () async {
        // Insert fresh entry
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );

        // Insert expired entry directly
        final expiredTime = DateTime.now().subtract(const Duration(hours: 1));
        await database
            .into(database.nip05Verifications)
            .insertOnConflictUpdate(
              Nip05VerificationsCompanion.insert(
                pubkey: testPubkey2,
                nip05: testNip05_2,
                status: 'verified',
                verifiedAt: expiredTime,
                expiresAt: expiredTime,
              ),
            );

        final deleted = await dao.deleteExpired();
        expect(deleted, equals(1));

        final result1 = await dao.getVerification(testPubkey);
        final result2 = await dao.getVerification(testPubkey2);

        expect(result1, isNotNull);
        expect(result2, isNull);
      });
    });

    group('clearAll', () {
      test('deletes all entries', () async {
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );
        await dao.upsertVerification(
          pubkey: testPubkey2,
          nip05: testNip05_2,
          status: 'failed',
        );

        final deleted = await dao.clearAll();
        expect(deleted, equals(2));

        final result1 = await dao.getVerification(testPubkey);
        final result2 = await dao.getVerification(testPubkey2);

        expect(result1, isNull);
        expect(result2, isNull);
      });

      test('returns 0 when table is empty', () async {
        final deleted = await dao.clearAll();
        expect(deleted, equals(0));
      });
    });

    group('watchVerification', () {
      test('emits verification when added', () async {
        final stream = dao.watchVerification(testPubkey);

        // Start listening
        final future = stream.first;

        // Insert verification
        await dao.upsertVerification(
          pubkey: testPubkey,
          nip05: testNip05,
          status: 'verified',
        );

        final result = await future;
        expect(result, isNotNull);
        expect(result!.status, equals('verified'));
      });

      test('emits null for non-existent pubkey initially', () async {
        final stream = dao.watchVerification(testPubkey);
        final result = await stream.first;
        expect(result, isNull);
      });
    });
  });
}

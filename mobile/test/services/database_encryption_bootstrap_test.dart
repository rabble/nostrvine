import 'package:db_client/db_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/database_encryption_bootstrap.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('generateCipherKeyHex', () {
    test('returns 64 lower-case hex characters (a raw 32-byte key)', () {
      final key = generateCipherKeyHex();
      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('returns a different key each call (CSPRNG)', () {
      expect(generateCipherKeyHex(), isNot(equals(generateCipherKeyHex())));
    });
  });

  group('DatabaseEncryptionBootstrap.resolveCipherKey', () {
    late _MockSecureStorage storage;
    late Map<String, String> store;

    setUp(() {
      storage = _MockSecureStorage();
      store = <String, String>{};
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((inv) async => store[inv.namedArguments[#key]]);
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((inv) async {
        store[inv.namedArguments[#key] as String] =
            inv.namedArguments[#value] as String;
      });
    });

    DatabaseEncryptionBootstrap buildBootstrap({
      required CipherMigrationOutcome outcome,
      required void Function() onDelete,
      bool cipherAvailable = true,
    }) {
      return DatabaseEncryptionBootstrap(
        secureStorage: storage,
        ensureRuntime: () async {},
        isCipherAvailable: () => cipherAvailable,
        migrate: (_) async => outcome,
        deleteDatabase: () async => onDelete(),
      );
    }

    test('throws StateError when SQLCipher is not linked', () {
      final bootstrap = buildBootstrap(
        cipherAvailable: false,
        outcome: CipherMigrationOutcome.noDatabase,
        onDelete: () {},
      );

      expect(bootstrap.resolveCipherKey(), throwsStateError);
    });

    test(
      'generates and persists a key on fresh install (noDatabase)',
      () async {
        var deleted = false;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.noDatabase,
          onDelete: () => deleted = true,
        );

        final key = await bootstrap.resolveCipherKey();

        expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(store[dbCipherKeyStorageKey], equals(key));
        expect(deleted, isFalse);
      },
    );

    test('returns the key after a successful migration', () async {
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.migrated,
        onDelete: () {},
      );

      expect(await bootstrap.resolveCipherKey(), isNotNull);
    });

    test('reuses an existing key without wiping (alreadyEncrypted)', () async {
      const existing =
          '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
      store[dbCipherKeyStorageKey] = existing;
      var deleted = false;
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.alreadyEncrypted,
        onDelete: () => deleted = true,
      );

      final key = await bootstrap.resolveCipherKey();

      expect(key, equals(existing));
      expect(deleted, isFalse, reason: 'key intact => not key-loss');
    });

    test('backs up the unrecoverable DB on key loss (generated key + '
        'alreadyEncrypted)', () async {
      // Empty store => key is freshly generated, but an encrypted DB already
      // exists: the keystore was reset. The DB is unrecoverable and must be
      // backed up + recreated under the new key (#570 §6).
      var deleted = false;
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.alreadyEncrypted,
        onDelete: () => deleted = true,
      );

      final key = await bootstrap.resolveCipherKey();

      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(deleted, isTrue);
    });

    test('returns null (plaintext fallback) when migration failed', () async {
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.failed,
        onDelete: () {},
      );

      expect(await bootstrap.resolveCipherKey(), isNull);
    });

    test('regenerates a key when the stored value is malformed', () async {
      store[dbCipherKeyStorageKey] = 'not-a-valid-key';
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.migrated,
        onDelete: () {},
      );

      final key = await bootstrap.resolveCipherKey();

      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(store[dbCipherKeyStorageKey], equals(key));
    });
  });

  group('resolveStartupDatabaseCipherKey', () {
    test(
      'records bootstrap failures and lets startup continue without a key',
      () async {
        final error = StateError('secure storage unavailable');
        Object? recordedError;
        StackTrace? recordedStack;

        final key = await resolveStartupDatabaseCipherKey(
          resolveCipherKey: () async => throw error,
          recordError: (error, stack) async {
            recordedError = error;
            recordedStack = stack;
          },
        );

        expect(key, isNull);
        expect(recordedError, same(error));
        expect(recordedStack, isNotNull);
      },
    );
  });
}

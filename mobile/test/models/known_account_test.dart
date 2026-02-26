// ABOUTME: Tests for KnownAccount model
// ABOUTME: Verifies JSON serialization, equality, and copyWith behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart' show AuthenticationSource;

void main() {
  group(KnownAccount, () {
    final testAddedAt = DateTime.utc(2024, 6);
    final testLastUsedAt = DateTime.utc(2024, 6, 15);
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    KnownAccount buildAccount({
      String pubkeyHex = testPubkey,
      AuthenticationSource authSource = AuthenticationSource.automatic,
      DateTime? addedAt,
      DateTime? lastUsedAt,
    }) {
      return KnownAccount(
        pubkeyHex: pubkeyHex,
        authSource: authSource,
        addedAt: addedAt ?? testAddedAt,
        lastUsedAt: lastUsedAt ?? testLastUsedAt,
      );
    }

    group('fromJson', () {
      test('creates instance from valid JSON', () {
        final json = {
          'pubkeyHex': testPubkey,
          'authSource': 'automatic',
          'addedAt': '2024-06-01T00:00:00.000Z',
          'lastUsedAt': '2024-06-15T00:00:00.000Z',
        };

        final account = KnownAccount.fromJson(json);

        expect(account.pubkeyHex, equals(testPubkey));
        expect(account.authSource, equals(AuthenticationSource.automatic));
        expect(account.addedAt, equals(testAddedAt));
        expect(account.lastUsedAt, equals(testLastUsedAt));
      });

      test('parses each $AuthenticationSource code correctly', () {
        for (final source in AuthenticationSource.values) {
          final json = {
            'pubkeyHex': testPubkey,
            'authSource': source.code,
            'addedAt': '2024-06-01T00:00:00.000Z',
            'lastUsedAt': '2024-06-15T00:00:00.000Z',
          };

          final account = KnownAccount.fromJson(json);
          expect(account.authSource, equals(source));
        }
      });

      test('defaults to AuthenticationSource.none for unknown code', () {
        final json = {
          'pubkeyHex': testPubkey,
          'authSource': 'unknown_source',
          'addedAt': '2024-06-01T00:00:00.000Z',
          'lastUsedAt': '2024-06-15T00:00:00.000Z',
        };

        final account = KnownAccount.fromJson(json);
        expect(account.authSource, equals(AuthenticationSource.none));
      });

      test('defaults to AuthenticationSource.none for null code', () {
        final json = {
          'pubkeyHex': testPubkey,
          'authSource': null,
          'addedAt': '2024-06-01T00:00:00.000Z',
          'lastUsedAt': '2024-06-15T00:00:00.000Z',
        };

        final account = KnownAccount.fromJson(json);
        expect(account.authSource, equals(AuthenticationSource.none));
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final account = buildAccount();
        final json = account.toJson();

        expect(json['pubkeyHex'], equals(testPubkey));
        expect(json['authSource'], equals('automatic'));
        expect(json['addedAt'], equals('2024-06-01T00:00:00.000Z'));
        expect(json['lastUsedAt'], equals('2024-06-15T00:00:00.000Z'));
      });

      test('serializes each $AuthenticationSource code correctly', () {
        for (final source in AuthenticationSource.values) {
          final account = buildAccount(authSource: source);
          final json = account.toJson();
          expect(json['authSource'], equals(source.code));
        }
      });
    });

    group('JSON round-trip', () {
      test('fromJson(toJson()) preserves all fields', () {
        final original = buildAccount();
        final roundTripped = KnownAccount.fromJson(original.toJson());

        expect(roundTripped.pubkeyHex, equals(original.pubkeyHex));
        expect(roundTripped.authSource, equals(original.authSource));
        expect(roundTripped.addedAt, equals(original.addedAt));
        expect(roundTripped.lastUsedAt, equals(original.lastUsedAt));
      });

      test('round-trip works for all $AuthenticationSource values', () {
        for (final source in AuthenticationSource.values) {
          final original = buildAccount(authSource: source);
          final roundTripped = KnownAccount.fromJson(original.toJson());
          expect(roundTripped.authSource, equals(source));
        }
      });
    });

    group('equality', () {
      test('two accounts with same pubkey are equal', () {
        final a = buildAccount();
        final b = buildAccount(authSource: AuthenticationSource.divineOAuth);

        expect(a, equals(b));
      });

      test('two accounts with different pubkeys are not equal', () {
        final a = buildAccount();
        final b = buildAccount(
          pubkeyHex:
              'ff00ff00ff00ff00ff00ff00ff00ff00'
              'ff00ff00ff00ff00ff00ff00ff00ff00',
        );

        expect(a, isNot(equals(b)));
      });

      test('props contains only pubkeyHex', () {
        final account = buildAccount();
        expect(account.props, equals([testPubkey]));
      });
    });

    group('copyWith', () {
      test('preserves all fields when no arguments provided', () {
        final original = buildAccount();
        final copied = original.copyWith();

        expect(copied.pubkeyHex, equals(original.pubkeyHex));
        expect(copied.authSource, equals(original.authSource));
        expect(copied.addedAt, equals(original.addedAt));
        expect(copied.lastUsedAt, equals(original.lastUsedAt));
      });

      test('updates authSource when provided', () {
        final original = buildAccount();
        final copied = original.copyWith(
          authSource: AuthenticationSource.amber,
        );

        expect(copied.authSource, equals(AuthenticationSource.amber));
        expect(copied.pubkeyHex, equals(original.pubkeyHex));
        expect(copied.addedAt, equals(original.addedAt));
        expect(copied.lastUsedAt, equals(original.lastUsedAt));
      });

      test('updates lastUsedAt when provided', () {
        final original = buildAccount();
        final newLastUsed = DateTime.utc(2024, 12, 25);
        final copied = original.copyWith(lastUsedAt: newLastUsed);

        expect(copied.lastUsedAt, equals(newLastUsed));
        expect(copied.pubkeyHex, equals(original.pubkeyHex));
        expect(copied.authSource, equals(original.authSource));
        expect(copied.addedAt, equals(original.addedAt));
      });

      test('always preserves pubkeyHex and addedAt', () {
        final original = buildAccount();
        final copied = original.copyWith(
          authSource: AuthenticationSource.bunker,
          lastUsedAt: DateTime.utc(2025),
        );

        expect(copied.pubkeyHex, equals(testPubkey));
        expect(copied.addedAt, equals(testAddedAt));
      });
    });
  });
}

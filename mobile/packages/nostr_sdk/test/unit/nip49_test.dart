// ABOUTME: Tests for NIP-49 ncryptsec1 private key encryption/decryption
// ABOUTME: Validates against the official NIP-49 test vector and error cases

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  // Official NIP-49 test vector
  // https://github.com/nostr-protocol/nips/blob/master/49.md#decryption
  const testVector =
      'ncryptsec1qgg9947rlpvqu76pj5ecreduf9jxhselq2nae2kghhvd5g7dgjtcxfqtd67p9m0w57lspw8gsq6yphnm8623nsl8xn9j4jdzz84zm3frztj3z7s35vpzmqf6ksu8r89qk5z2zxfmu5gv8th8wclt0h4p';
  const testPassword = 'nostr';
  const testPrivateKeyHex =
      '3501454135014541350145413501453fefb02227e449e57cf4d3a3ce05378683';

  group(Nip49, () {
    group('isEncryptedKey', () {
      test('returns true for ncryptsec1 strings', () {
        expect(Nip49.isEncryptedKey(testVector), isTrue);
        expect(Nip49.isEncryptedKey('ncryptsec1abc'), isTrue);
      });

      test('returns false for nsec strings', () {
        expect(
          Nip49.isEncryptedKey(
            'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k3lvr'
            'paxge38re5qf6vm6j',
          ),
          isFalse,
        );
      });

      test('returns false for hex private keys', () {
        expect(Nip49.isEncryptedKey(testPrivateKeyHex), isFalse);
      });

      test('returns false for bunker URLs', () {
        expect(
          Nip49.isEncryptedKey('bunker://pubkey?relay=wss://r.com'),
          isFalse,
        );
      });

      test('returns false for empty string', () {
        expect(Nip49.isEncryptedKey(''), isFalse);
      });
    });

    group('decode', () {
      test('decrypts official NIP-49 test vector', () async {
        final result = await Nip49.decode(testVector, testPassword);
        expect(result, equals(testPrivateKeyHex));
      });

      test('throws Nip49Exception on wrong password', () async {
        await expectLater(
          () => Nip49.decode(testVector, 'wrongpassword'),
          throwsA(isA<Nip49Exception>()),
        );
      });

      test('throws Nip49Exception on non-ncryptsec1 input', () async {
        await expectLater(
          () => Nip49.decode('nsec1notencrypted', testPassword),
          throwsA(isA<Nip49Exception>()),
        );
      });

      test('throws Nip49Exception on malformed bech32', () async {
        await expectLater(
          () => Nip49.decode('ncryptsec1invalidbech32!!!', testPassword),
          throwsA(isA<Nip49Exception>()),
        );
      });
    });

    group('encode + decode round-trip', () {
      test('round-trip preserves private key with logN 16', () async {
        final encrypted = await Nip49.encode(
          testPrivateKeyHex,
          testPassword,
          logN: 16,
        );

        expect(Nip49.isEncryptedKey(encrypted), isTrue);
        expect(encrypted, startsWith('ncryptsec1'));

        final decrypted = await Nip49.decode(encrypted, testPassword);
        expect(decrypted, equals(testPrivateKeyHex));
      });

      test(
        'encode produces different output each time (random nonce)',
        () async {
          final encrypted1 = await Nip49.encode(
            testPrivateKeyHex,
            testPassword,
            logN: 16,
          );
          final encrypted2 = await Nip49.encode(
            testPrivateKeyHex,
            testPassword,
            logN: 16,
          );
          expect(encrypted1, isNot(equals(encrypted2)));
        },
      );

      test(
        'encode throws Nip49Exception for invalid private key length',
        () async {
          await expectLater(
            () => Nip49.encode('tooshort', testPassword),
            throwsA(isA<Nip49Exception>()),
          );
        },
      );
    });
  });
}

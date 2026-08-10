// ABOUTME: Tests for SyncCipher AES-256-GCM sealing of index payloads.
// ABOUTME: Covers round-trip, nonce uniqueness, and tamper detection.

import 'dart:convert';

import 'package:creator_sync/creator_sync.dart';
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  group(SyncCipher, () {
    late SecretKey vaultKey;
    late SyncCipher cipher;

    setUp(() async {
      vaultKey = await AesGcm.with256bits().newSecretKey();
      cipher = SyncCipher(vaultKey);
    });

    test('round-trips a payload unchanged', () async {
      const plaintext = '{"v":1,"sound":{"id":"abc"}}';

      final sealed = await cipher.seal(plaintext);

      expect(await cipher.open(sealed), equals(plaintext));
    });

    test('round-trips a payload containing multibyte characters', () async {
      const plaintext = '{"label":"ラーメン 🍜"}';

      final sealed = await cipher.seal(plaintext);

      expect(await cipher.open(sealed), equals(plaintext));
    });

    test('produces different ciphertext for identical plaintext', () async {
      const plaintext = 'same input';

      final first = await cipher.seal(plaintext);
      final second = await cipher.seal(plaintext);

      expect(first, isNot(equals(second)));
    });

    test('throws $SyncDecryptException on a tampered payload', () async {
      final sealed = await cipher.seal('honest payload');
      final bytes = base64Decode(sealed);
      bytes[bytes.length - 1] ^= 0xFF;
      final tampered = base64Encode(bytes);

      expect(
        () => cipher.open(tampered),
        throwsA(isA<SyncDecryptException>()),
      );
    });

    test('throws $SyncDecryptException under a different vault key', () async {
      final sealed = await cipher.seal('honest payload');
      final otherCipher = SyncCipher(
        await AesGcm.with256bits().newSecretKey(),
      );

      expect(
        () => otherCipher.open(sealed),
        throwsA(isA<SyncDecryptException>()),
      );
    });

    test('throws $SyncDecryptException on a truncated payload', () async {
      expect(
        () => cipher.open(base64Encode([1, 2, 3])),
        throwsA(isA<SyncDecryptException>()),
      );
    });

    test('throws $SyncDecryptException on non-base64 input', () async {
      expect(
        () => cipher.open('not base64 !!!'),
        throwsA(isA<SyncDecryptException>()),
      );
    });

    test(
      'throws $SyncDecryptException when authenticated bytes are not '
      'valid UTF-8',
      () async {
        // Bypasses seal() to encrypt raw bytes that are not valid UTF-8.
        // The payload authenticates successfully under the vault key, so
        // this exercises the utf8.decode failure path distinct from
        // tampering or a wrong key.
        final secretBox = await AesGcm.with256bits().encrypt(
          [0xFF, 0xFE, 0xFD],
          secretKey: vaultKey,
        );
        final sealed = base64Encode(secretBox.concatenation());

        expect(
          () => cipher.open(sealed),
          throwsA(isA<SyncDecryptException>()),
        );
      },
    );
  });
}

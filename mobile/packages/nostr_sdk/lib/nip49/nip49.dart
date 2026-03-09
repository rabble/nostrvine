// ABOUTME: NIP-49 private key encryption/decryption using scrypt + XChaCha20-Poly1305
// ABOUTME: Encodes/decodes ncryptsec1 bech32 strings for password-protected key storage

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bech32/bech32.dart';
import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:hex/hex.dart';
import 'package:pointycastle/export.dart';

import '../nip19/hrps.dart';
import '../nip19/nip19.dart';

/// Exception thrown when NIP-49 encryption or decryption fails.
class Nip49Exception implements Exception {
  Nip49Exception(this.message);

  final String message;

  @override
  String toString() => 'Nip49Exception: $message';
}

/// NIP-49: Private Key Encryption
///
/// Encrypts and decrypts Nostr private keys using a password, scrypt KDF,
/// and XChaCha20-Poly1305 AEAD cipher.
///
/// The output format is an `ncryptsec1` bech32-encoded string. The 91-byte
/// payload is structured as:
/// ```
/// [0]      VERSION (0x02)
/// [1]      LOG_N (scrypt cost parameter)
/// [2..17]  SALT (16 bytes)
/// [18..41] NONCE (24 bytes, XChaCha20)
/// [42]     KEY_SECURITY_BYTE (associated data)
/// [43..90] CIPHERTEXT (32 bytes encrypted key + 16 bytes Poly1305 MAC)
/// ```
///
/// See: https://github.com/nostr-protocol/nips/blob/master/49.md
class Nip49 {
  static const int _version = 0x02;
  static const int _saltLength = 16;
  static const int _nonceLength = 24;
  static const int _keyLength = 32;
  static const int _payloadLength = 91; // 1+1+16+24+1+32+16
  // Allow bech32 strings up to 200 chars (ncryptsec1 is ~163 chars,
  // exceeding the standard 90-char bech32 limit).
  static const int _maxBech32Length = 200;

  /// Returns true if [s] is an `ncryptsec1`-encoded encrypted private key.
  static bool isEncryptedKey(String s) =>
      s.startsWith('${Hrps.encryptedPrivateKey}1');

  /// Decrypts an `ncryptsec1` string using [password].
  ///
  /// Returns the decrypted private key as a 64-character hex string.
  ///
  /// Note: The NIP-49 spec requires passwords to be NFKC unicode-normalized.
  /// This implementation uses the password as-is. Pure ASCII passwords are
  /// unaffected; non-ASCII passwords may not interoperate with clients that
  /// apply normalization.
  ///
  /// Throws [Nip49Exception] if the password is incorrect or the input is
  /// malformed.
  static Future<String> decode(String ncryptsec, String password) async {
    final payload = _bech32Decode(ncryptsec);

    if (payload.length != _payloadLength) {
      throw Nip49Exception(
        'Invalid payload length: expected $_payloadLength, got ${payload.length}',
      );
    }

    if (payload[0] != _version) {
      throw Nip49Exception('Unsupported version: ${payload[0]}');
    }

    final logN = payload[1];
    final salt = Uint8List.fromList(payload.sublist(2, 18));
    final nonce = payload.sublist(18, 42);
    final keySecurityByte = payload[42];
    final ciphertextBytes = payload.sublist(43, 75);
    final mac = payload.sublist(75, 91);

    final symmetricKey = _deriveKey(
      password: utf8.encode(password),
      salt: salt,
      logN: logN,
    );

    final algorithm = cryptography.Xchacha20.poly1305Aead();
    final secretBox = cryptography.SecretBox(
      ciphertextBytes,
      nonce: nonce,
      mac: cryptography.Mac(mac),
    );

    final List<int> privateKeyBytes;
    try {
      privateKeyBytes = await algorithm.decrypt(
        secretBox,
        secretKey: cryptography.SecretKey(symmetricKey),
        aad: [keySecurityByte],
      );
    } on cryptography.SecretBoxAuthenticationError {
      throw Nip49Exception(
        'Decryption failed: incorrect password or corrupted data',
      );
    } catch (e) {
      throw Nip49Exception('Decryption failed: $e');
    }

    if (privateKeyBytes.length != _keyLength) {
      throw Nip49Exception(
        'Decrypted key has unexpected length: ${privateKeyBytes.length}',
      );
    }

    return HEX.encode(privateKeyBytes);
  }

  /// Encrypts [privateKeyHex] with [password] and returns an `ncryptsec1` string.
  ///
  /// [logN] controls the scrypt cost (default 16 = 64 MiB, ~100 ms on fast
  /// hardware). Higher values increase security at the cost of time and memory.
  ///
  /// [keySecurityByte] indicates how the key was handled:
  /// - `0x00`: known to have been handled insecurely
  /// - `0x01`: not known to have been handled insecurely
  /// - `0x02`: client does not track this (default)
  ///
  /// Note: The NIP-49 spec requires passwords to be NFKC unicode-normalized.
  static Future<String> encode(
    String privateKeyHex,
    String password, {
    int logN = 16,
    int keySecurityByte = 0x02,
  }) async {
    final List<int> decodedBytes;
    try {
      decodedBytes = HEX.decode(privateKeyHex);
    } on FormatException {
      throw Nip49Exception(
        'Private key must be a valid 64-character hex string',
      );
    }
    if (decodedBytes.length != _keyLength) {
      throw Nip49Exception('Private key must be 32 bytes (64 hex chars)');
    }
    final privateKeyBytes = Uint8List.fromList(decodedBytes);

    final random = Random.secure();
    final salt = Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final nonce = List.generate(_nonceLength, (_) => random.nextInt(256));

    final symmetricKey = _deriveKey(
      password: utf8.encode(password),
      salt: salt,
      logN: logN,
    );

    final algorithm = cryptography.Xchacha20.poly1305Aead();
    final secretBox = await algorithm.encrypt(
      privateKeyBytes,
      secretKey: cryptography.SecretKey(symmetricKey),
      nonce: nonce,
      aad: [keySecurityByte],
    );

    final payload = Uint8List(_payloadLength)
      ..[0] = _version
      ..[1] = logN
      ..setRange(2, 18, salt)
      ..setRange(18, 42, secretBox.nonce)
      ..[42] = keySecurityByte
      ..setRange(43, 75, secretBox.cipherText)
      ..setRange(75, 91, secretBox.mac.bytes);

    final bech32Data = Nip19.convertBits(payload, 8, 5, true);
    final encoder = Bech32Encoder();
    return encoder.convert(
      Bech32(Hrps.encryptedPrivateKey, bech32Data),
      _maxBech32Length,
    );
  }

  static List<int> _bech32Decode(String ncryptsec) {
    try {
      final decoder = Bech32Decoder();
      final result = decoder.convert(ncryptsec, _maxBech32Length);
      if (result.hrp != Hrps.encryptedPrivateKey) {
        throw Nip49Exception(
          'Expected hrp "${Hrps.encryptedPrivateKey}", got "${result.hrp}"',
        );
      }
      return Nip19.convertBits(result.data, 5, 8, false);
    } on Nip49Exception {
      rethrow;
    } catch (e) {
      throw Nip49Exception('Invalid bech32 encoding: $e');
    }
  }

  static Uint8List _deriveKey({
    required List<int> password,
    required Uint8List salt,
    required int logN,
  }) {
    final n = 1 << logN;
    final params = ScryptParameters(n, 8, 1, _keyLength, salt);
    final scrypt = Scrypt()..init(params);
    return scrypt.process(Uint8List.fromList(password));
  }
}

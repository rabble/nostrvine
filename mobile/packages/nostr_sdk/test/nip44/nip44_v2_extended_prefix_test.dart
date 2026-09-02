// ABOUTME: Conformance test for NIP-44's 6-byte extended length prefix, which
// ABOUTME: this implementation reads on decrypt but deliberately never writes.
//
// The vectors are the ones published inline in `nips/44.md` ("Extended length
// prefix test vectors"), not in `nip44.vectors.json` — that fixture predates
// the extended-prefix prose and still lists 65536 under
// `invalid.encrypt_msg_lengths`, so its pinned sha256 carries no coverage for
// this boundary. Checksums below are copied from 44.md.
//
// Encryption stays u16-only on purpose: a payload written with the extended
// prefix cannot be read by any u16-only peer, and that includes the Rust
// `nostr` crate behind keycast's server-side NIP-17 wrap/unwrap. See #7331.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:nostr_sdk/nip44/nip44_v2.dart';

Uint8List _hexBytes(String hex) => Uint8List.fromList(HEX.decode(hex));

const _conversationKey =
    'c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d';
const _nonce =
    '0000000000000000000000000000000000000000000000000000000000000001';

/// Builds a payload the way a spec-conformant peer would, choosing the prefix
/// form by length. This mirrors NIP-44's `pad` (44.md) rather than calling
/// [NIP44V2.pad], which is u16-only by design.
Uint8List _specPad(String plaintext) {
  final unpadded = utf8.encode(plaintext);
  final len = unpadded.length;
  final List<int> prefix;
  if (len >= NIP44V2.extendedPrefixThreshold) {
    final u32 = ByteData(4)..setUint32(0, len, Endian.big);
    prefix = [0, 0, ...u32.buffer.asUint8List()];
  } else {
    final u16 = ByteData(2)..setUint16(0, len, Endian.big);
    prefix = u16.buffer.asUint8List();
  }
  return Uint8List.fromList([
    ...prefix,
    ...unpadded,
    ...Uint8List(NIP44V2.calcPaddedLen(len) - len),
  ]);
}

Future<String> _specEncrypt(
  String plaintext,
  Uint8List convKey,
  Uint8List nonce,
) async {
  final keys = NIP44V2.getMessageKeys(convKey, nonce);
  final ciphertext = await NIP44V2.chacha20Encrypt(
    keys['chacha_key']!,
    keys['chacha_nonce']!,
    _specPad(plaintext),
  );
  final mac = NIP44V2.hmacAad(keys['hmac_key']!, ciphertext, nonce);
  return base64Encode(Uint8List.fromList([2, ...nonce, ...ciphertext, ...mac]));
}

void main() {
  final convKey = _hexBytes(_conversationKey);
  final nonce = _hexBytes(_nonce);

  group('NIP44V2 extended length prefix', () {
    group('unpad', () {
      // 44.md "Extended length prefix test vectors": plaintext is 'a' repeated.
      const vectors = <int, ({String plaintextSha, String payloadSha})>{
        65535: (
          plaintextSha:
              '6e1bebca6a8229364a162a72ef064826c4cd7457bf54f190ef782bd9deff3e42',
          payloadSha:
              '6d8c2810d1e870fbaa1f0a0937126cca837a15f9260e27060c331d70a3c0bc84',
        ),
        65536: (
          plaintextSha:
              'bf718b6f653bebc184e1479f1935b8da974d701b893afcf49e701f3e2f9f9c5a',
          payloadSha:
              'b7b4edb36ba92e267d322d56d9aebc22e7fa96ff52e3c12adc07f07a43cbc616',
        ),
        65537: (
          plaintextSha:
              '008ffc88d3c96a9f307524eb361e47c5222a887fc45fa0c1fb8d429c5c23b430',
          payloadSha:
              'eeb7c7c5373894ea2c1547cfd3ccb15d5a0b2d619da852e5c79df792dcc9e435',
        ),
      };

      for (final entry in vectors.entries) {
        final length = entry.key;
        test('decrypts the 44.md boundary vector at $length bytes', () async {
          final plaintext = 'a' * length;
          expect(
            sha256.convert(utf8.encode(plaintext)).toString(),
            equals(entry.value.plaintextSha),
            reason: 'plaintext does not match the 44.md checksum',
          );

          final payload = await _specEncrypt(plaintext, convKey, nonce);
          expect(
            sha256.convert(utf8.encode(payload)).toString(),
            equals(entry.value.payloadSha),
            reason:
                'payload does not match the 44.md checksum; the constructed '
                'payload is not what a conformant peer would send',
          );

          expect(await NIP44V2.decrypt(payload, convKey), equals(plaintext));
        });
      }

      test('rejects a 6-byte prefix declaring a sub-threshold length', () {
        // A forged payload may use the extended form for a small length. NIP-44
        // requires the declared u32 to be at or above the threshold, otherwise
        // the same plaintext has two encodings and the 6-byte form smuggles a
        // short one past a reader that only bounds the buffer. Verified by
        // mutation: deleting the threshold check makes this decode to 'hello',
        // and no other test in the suite catches it — the pinned fixture's
        // `invalid.decrypt` vector whose plaintext starts with a zero u16 is
        // rejected by the buffer-length check instead, so it does not cover
        // this (#7331).
        final padded = Uint8List.fromList([
          0, 0, // extended-format signal
          0, 0, 0, 5, // declared length 5, below the threshold
          ...utf8.encode('hello'),
          ...Uint8List(NIP44V2.calcPaddedLen(5) - 5),
        ]);
        expect(() => NIP44V2.unpad(padded), throwsA(isA<Exception>()));
      });

      test('rejects an extended prefix truncated below 6 bytes', () {
        expect(
          () => NIP44V2.unpad(Uint8List.fromList([0, 0, 0, 1])),
          throwsA(isA<Exception>()),
        );
      });

      test('still reads the 2-byte u16 prefix', () {
        final padded = Uint8List.fromList([
          0,
          5,
          ...utf8.encode('hello'),
          ...Uint8List(NIP44V2.calcPaddedLen(5) - 5),
        ]);
        expect(NIP44V2.unpad(padded), equals('hello'));
      });
    });

    group('pad', () {
      test('refuses to emit the extended prefix', () {
        // Deliberate asymmetry, not an oversight: emitting an extended-prefix
        // payload would be undecryptable by u16-only peers, converting a
        // visible send failure into a silent non-delivery (#7331).
        expect(
          () => NIP44V2.pad('a' * NIP44V2.extendedPrefixThreshold),
          throwsA(isA<Exception>()),
        );
      });

      test('still pads the largest u16 length', () {
        final padded = NIP44V2.pad('a' * 65535);
        expect(padded.length, equals(2 + NIP44V2.calcPaddedLen(65535)));
      });
    });

    group('decodePayload', () {
      test('accepts a payload carrying an extended-prefix plaintext', () async {
        final payload = await _specEncrypt('a' * 65536, convKey, nonce);
        expect(NIP44V2.decodePayload(payload), isNotEmpty);
      });

      test('a caller-supplied bound rejects before base64 decoding', () {
        // A classifier that only ever sees single-encryption payloads should
        // not pay for the 1 MiB decrypt ceiling. Passing maxU16PlaintextSize
        // restores the cheap pre-decode rejection (#7331).
        final oversizedForU16 = 'A' * 90000;

        expect(
          () => NIP44V2.decodePayload(
            oversizedForU16,
            maxPlaintextSize: NIP44V2.maxU16PlaintextSize,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test(
        'the default bound still admits an extended-prefix payload',
        () async {
          final payload = await _specEncrypt('a' * 65536, convKey, nonce);

          expect(NIP44V2.decodePayload(payload), isNotEmpty);
          expect(
            () => NIP44V2.decodePayload(
              payload,
              maxPlaintextSize: NIP44V2.maxU16PlaintextSize,
            ),
            throwsA(isA<Exception>()),
            reason: 'a u16-bounded caller must not accept an extended payload',
          );
        },
      );

      test('rejects a payload above the decrypt ceiling', () {
        final tooLong =
            'A' * (((NIP44V2.maxDecryptPlaintextSize) ~/ 3) * 4 * 2);
        expect(() => NIP44V2.decodePayload(tooLong), throwsA(isA<Exception>()));
      });
    });
  });
}

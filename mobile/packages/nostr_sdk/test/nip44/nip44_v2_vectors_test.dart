// ABOUTME: Conformance test for the NIP-44 v2 implementation against the
// ABOUTME: official cross-implementation test vectors (paulmillr/nip44).
//
// The vendored fixture `fixtures/nip44.vectors.json` is pinned by NIP-44 to
// sha256 269ed0f69e4c192512cc779e78c555090cebc7c785b609e338a62afc3ce25040.
// This is the first NIP-44 vector coverage in the repo; it asserts both the
// `valid.*` round-trips AND that `invalid.decrypt` payloads throw — a forged
// MAC, bad padding, or wrong version must never decrypt to plaintext.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hex/hex.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nip44/nip44_v2.dart';

Uint8List _hexBytes(String hex) => Uint8List.fromList(HEX.decode(hex));
String _hex(List<int> bytes) => HEX.encode(bytes);

void main() {
  group('NIP44V2 official vectors', () {
    late Map<String, dynamic> valid;
    late Map<String, dynamic> invalid;

    setUpAll(() {
      final file = File('test/nip44/fixtures/nip44.vectors.json');
      final v2 =
          (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['v2']
              as Map<String, dynamic>;
      valid = v2['valid'] as Map<String, dynamic>;
      invalid = v2['invalid'] as Map<String, dynamic>;
    });

    test('valid.calc_padded_len', () {
      final cases = valid['calc_padded_len'] as List<dynamic>;
      for (final pair in cases.cast<List<dynamic>>()) {
        final len = pair[0] as int;
        final padded = pair[1] as int;
        expect(
          NIP44V2.calcPaddedLen(len),
          equals(padded),
          reason: 'calcPaddedLen($len)',
        );
      }
    });

    test('valid.get_conversation_key', () {
      final cases = valid['get_conversation_key'] as List<dynamic>;
      for (final c in cases.cast<Map<String, dynamic>>()) {
        final sec1 = c['sec1'] as String;
        final pub2 = c['pub2'] as String;
        final expected = c['conversation_key'] as String;
        expect(
          _hex(NIP44V2.shareSecret(sec1, pub2)),
          equals(expected),
          reason: 'conversation_key for pub2=$pub2',
        );
      }
    });

    test('valid.get_message_keys', () {
      final mk = valid['get_message_keys'] as Map<String, dynamic>;
      final convKey = _hexBytes(mk['conversation_key'] as String);
      for (final k
          in (mk['keys'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final keys = NIP44V2.getMessageKeys(
          convKey,
          _hexBytes(k['nonce'] as String),
        );
        expect(_hex(keys['chacha_key']!), equals(k['chacha_key']));
        expect(_hex(keys['chacha_nonce']!), equals(k['chacha_nonce']));
        expect(_hex(keys['hmac_key']!), equals(k['hmac_key']));
      }
    });

    test(
      'valid.encrypt_decrypt round-trips to the exact vector payload',
      () async {
        final cases = valid['encrypt_decrypt'] as List<dynamic>;
        for (final c in cases.cast<Map<String, dynamic>>()) {
          final convKey = _hexBytes(c['conversation_key'] as String);
          final nonce = _hexBytes(c['nonce'] as String);
          final plaintext = c['plaintext'] as String;
          final payload = c['payload'] as String;

          // ECDH cross-check: conversation_key derives from sec1 + pub(sec2).
          final sec1 = c['sec1'] as String;
          final sec2 = c['sec2'] as String;
          expect(
            _hex(NIP44V2.shareSecret(sec1, getPublicKey(sec2))),
            equals(c['conversation_key']),
          );

          // Deterministic encrypt with the vector nonce must equal the payload.
          expect(
            await NIP44V2.encrypt(plaintext, convKey, nonce),
            equals(payload),
          );
          // Decrypt the canonical payload back to the plaintext.
          expect(await NIP44V2.decrypt(payload, convKey), equals(plaintext));
        }
      },
    );

    test(
      'invalid.decrypt payloads must throw, never yield plaintext',
      () async {
        final cases = invalid['decrypt'] as List<dynamic>;
        for (final c in cases.cast<Map<String, dynamic>>()) {
          final convKey = _hexBytes(c['conversation_key'] as String);
          final payload = c['payload'] as String;
          await expectLater(
            NIP44V2.decrypt(payload, convKey),
            throwsA(isA<Exception>()),
            reason: 'should reject: ${c['note']}',
          );
        }
      },
    );
  });
}

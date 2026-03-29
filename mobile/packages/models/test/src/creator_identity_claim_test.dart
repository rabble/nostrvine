import 'dart:convert';

import 'package:models/models.dart';
import 'package:test/test.dart';

const _alicePubkey =
    'f1d2d2f924e986ac86fdf7b36c94bcdf'
    '32beec15a78f11de5d8c93b6c43f2d1a';
const _hardBindingValue =
    'ef5d3d4f69d72df6d4d08f625f66ecfb'
    '17b3a6dd4e03f6f5a6a5f0e31ecfe8ee';

void main() {
  group('Creator identity claim metadata', () {
    test('preserves canonical creator-binding fields in native proof JSON', () {
      final creatorBindingPayload = <String, dynamic>{
        'version': 1,
        'pubkey': _alicePubkey,
        'sig_alg': 'nostr.secp256k1',
        'created_at': '2026-03-29T08:30:00Z',
        'claims': <String, dynamic>{
          'nip05': 'alice@example.com',
          'website': 'https://example.com',
          'social_handles': <Map<String, String>>[
            <String, String>{'platform': 'github', 'handle': 'alice'},
            <String, String>{'platform': 'x', 'handle': '@alice'},
          ],
        },
        'referenced_assertions': <String>[
          'c2pa.hash.data',
          'c2pa.actions.v2',
        ],
        'hard_binding': <String, String>{
          'alg': 'sha256',
          'value': _hardBindingValue,
        },
        'signature':
            '3f4f6cc4d9a262fefca56f8f5c0a7a4b6a6f4a8f5b2c0d1f7a8b9c0d1e2f3041',
      };
      final verifiedIdentityBundle = <String, dynamic>{
        'issuer': 'verifier.divine.video',
        'verified_claims': <Map<String, String>>[
          <String, String>{'type': 'nip05', 'value': 'alice@example.com'},
          <String, String>{'type': 'domain', 'value': 'example.com'},
        ],
      };

      final proof = NativeProofData(
        videoHash:
            'abc123def456789012345678901234567890123456789012345678901234',
        creatorBindingAssertionLabel: 'video.divine.nostr.creator_binding',
        cawgIdentityAssertionLabel: 'cawg.identity',
        creatorBindingPayloadJson: jsonEncode(creatorBindingPayload),
        verifiedIdentityBundleJson: jsonEncode(verifiedIdentityBundle),
      );

      final json = proof.toJson();
      final payload =
          jsonDecode(json['creatorBindingPayloadJson'] as String)
              as Map<String, dynamic>;
      final claims = payload['claims'] as Map<String, dynamic>;
      final socialHandles = claims['social_handles'] as List<dynamic>;

      expect(
        json['creatorBindingAssertionLabel'],
        equals('video.divine.nostr.creator_binding'),
      );
      expect(json['cawgIdentityAssertionLabel'], equals('cawg.identity'));
      expect(
        payload.keys,
        containsAll(<String>[
          'version',
          'pubkey',
          'sig_alg',
          'created_at',
          'claims',
          'referenced_assertions',
          'hard_binding',
          'signature',
        ]),
      );
      expect(claims['nip05'], equals('alice@example.com'));
      expect(claims['website'], equals('https://example.com'));
      expect(socialHandles, hasLength(2));
      expect(
        socialHandles.first,
        containsPair('platform', 'github'),
      );
      expect(
        socialHandles.last,
        containsPair('handle', '@alice'),
      );
    });

    test(
      'round-trips creator identity metadata through pending upload proof JSON',
      () {
        final proof = NativeProofData(
          videoHash:
              'abc123def456789012345678901234567890123456789012345678901234',
          creatorBindingAssertionLabel: 'video.divine.nostr.creator_binding',
          cawgIdentityAssertionLabel: 'cawg.identity',
          creatorBindingPayloadJson: jsonEncode(<String, dynamic>{
            'version': 1,
            'pubkey': _alicePubkey,
          }),
          verifiedIdentityBundleJson: jsonEncode(<String, dynamic>{
            'issuer': 'verifier.divine.video',
          }),
        );

        final upload = PendingUpload.create(
          localVideoPath: '/tmp/video.mp4',
          nostrPubkey: _alicePubkey,
          proofManifestJson: jsonEncode(proof.toJson()),
        );

        expect(upload.nativeProof, isNotNull);
        expect(upload.hasCreatorIdentityMetadata, isTrue);
        expect(
          upload.nativeProof!.creatorBindingAssertionLabel,
          equals('video.divine.nostr.creator_binding'),
        );
        expect(
          upload.nativeProof!.cawgIdentityAssertionLabel,
          equals('cawg.identity'),
        );
        expect(
          jsonDecode(upload.nativeProof!.verifiedIdentityBundleJson!)
              as Map<String, dynamic>,
          containsPair('issuer', 'verifier.divine.video'),
        );
      },
    );
  });
}

// ABOUTME: Tests for VideoEvent.hasProofMode, ensuring an "unverified"
// ABOUTME: verification tag is not mistaken for a genuine ProofMode signal.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  VideoEvent build({
    Map<String, String> rawTags = const {},
    ProofVerificationSummary? proofSummary,
  }) => VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: 1735689600,
    content: '',
    timestamp: DateTime.utc(2026),
    rawTags: rawTags,
    proofSummary: proofSummary,
  );

  group('VideoEvent.hasProofMode', () {
    test('returns false when there is no proof signal at all', () {
      expect(build().hasProofMode, isFalse);
    });

    test('returns false when verification tag is "unverified"', () {
      expect(
        build(rawTags: const {'verification': 'unverified'}).hasProofMode,
        isFalse,
      );
    });

    test('returns true when verification tag is a real level', () {
      expect(
        build(rawTags: const {'verification': 'verified_mobile'}).hasProofMode,
        isTrue,
      );
    });

    test(
      'returns true when verification is "unverified" but an opaque '
      '(non-JSON) proofmode manifest tag is present',
      () {
        expect(
          build(
            rawTags: const {
              'verification': 'unverified',
              'proofmode': 'manifest-blob',
            },
          ).hasProofMode,
          isTrue,
        );
      },
    );

    test(
      'returns false when an "unverified" upload carries an empty-shell '
      'proofmode manifest (only a videoHash, no proof field)',
      () {
        expect(
          build(
            rawTags: const {
              'verification': 'unverified',
              'proofmode': '{"videoHash":"abc123"}',
            },
          ).hasProofMode,
          isFalse,
        );
      },
    );

    test(
      'returns false when an "unverified" upload carries non-object JSON',
      () {
        expect(
          build(
            rawTags: const {
              'verification': 'unverified',
              'proofmode': '[]',
            },
          ).hasProofMode,
          isFalse,
        );
      },
    );

    test(
      'returns true when an "unverified" upload carries a proofmode manifest '
      'whose JSON holds a real proof field (sensorDataCsv)',
      () {
        expect(
          build(
            rawTags: const {
              'verification': 'unverified',
              'proofmode': '{"videoHash":"abc123","sensorDataCsv":"a,b,c"}',
            },
          ).hasProofMode,
          isTrue,
        );
      },
    );

    test(
      'returns true when an "unverified" upload carries a proofmode manifest '
      'whose JSON holds a pgpSignature',
      () {
        expect(
          build(
            rawTags: const {
              'verification': 'unverified',
              'proofmode': '{"videoHash":"abc123","pgpSignature":"sig"}',
            },
          ).hasProofMode,
          isTrue,
        );
      },
    );

    test(
      'returns true when verification is "unverified" but a device '
      'attestation tag is present',
      () {
        expect(
          build(
            rawTags: const {
              'verification': 'unverified',
              'device_attestation': 'attestation-blob',
            },
          ).hasProofMode,
          isTrue,
        );
      },
    );

    test(
      'returns true when verification is "unverified" but a C2PA manifest '
      'id tag is present',
      () {
        expect(
          build(
            rawTags: const {
              'verification': 'unverified',
              'c2pa_manifest_id': 'urn:c2pa:1234',
            },
          ).hasProofMode,
          isTrue,
        );
      },
    );

    test(
      'returns true when verification is "unverified" but the proof summary '
      'carries a usable proofmode signal',
      () {
        expect(
          build(
            rawTags: const {'verification': 'unverified'},
            proofSummary: const ProofVerificationSummary(
              status: 'verified',
              version: 1,
              checks: {
                'proofmode_present': true,
                'proofmode_parse_ok': true,
              },
            ),
          ).hasProofMode,
          isTrue,
        );
      },
    );

    test(
      'returns false when verification is "unverified" and the proof summary '
      'has no usable signal',
      () {
        expect(
          build(
            rawTags: const {'verification': 'unverified'},
            proofSummary: const ProofVerificationSummary(
              status: 'unknown',
              version: 1,
            ),
          ).hasProofMode,
          isFalse,
        );
      },
    );
  });
}

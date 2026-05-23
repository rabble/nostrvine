import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('ProofVerificationSummary', () {
    test('equal summaries with differently ordered checks share hashCode', () {
      const first = ProofVerificationSummary(
        status: 'present',
        level: 'basic_proof',
        version: 1,
        checks: {
          'proofmode_present': true,
          'proofmode_parse_ok': true,
          'pgp_signature_valid': null,
        },
      );
      const second = ProofVerificationSummary(
        status: 'present',
        level: 'basic_proof',
        version: 1,
        checks: {
          'pgp_signature_valid': null,
          'proofmode_parse_ok': true,
          'proofmode_present': true,
        },
      );

      expect(first, equals(second));
      expect(first.hashCode, equals(second.hashCode));
    });

    test('invalid summary with present checks does not prove a video', () {
      final video = _videoWithProofSummary(
        const ProofVerificationSummary(
          status: 'invalid',
          level: 'basic_proof',
          version: 1,
          checks: {
            'proofmode_present': true,
            'proofmode_parse_ok': true,
            'pgp_signature_present': true,
            'pgp_signature_valid': true,
            'device_attestation_present': true,
            'device_attestation_valid': true,
            'c2pa_manifest_present': true,
            'c2pa_manifest_valid': true,
          },
        ),
      );

      expect(video.proofModeManifest, isNull);
      expect(video.proofModeDeviceAttestation, isNull);
      expect(video.proofModePgpFingerprint, isNull);
      expect(video.proofModeC2paManifestId, isNull);
      expect(video.hasProofMode, isFalse);
      expect(video.hasBasicProof, isFalse);
      expect(video.isVerifiedMobile, isFalse);
      expect(video.isVerifiedWeb, isFalse);
    });

    test('explicit failed component checks suppress compact sentinels', () {
      final video = _videoWithProofSummary(
        const ProofVerificationSummary(
          status: 'present',
          level: 'basic_proof',
          version: 1,
          checks: {
            'proofmode_present': true,
            'proofmode_parse_ok': false,
            'pgp_signature_present': true,
            'pgp_signature_valid': false,
            'device_attestation_present': true,
            'device_attestation_valid': false,
            'c2pa_manifest_present': true,
            'c2pa_manifest_valid': false,
          },
        ),
      );

      expect(video.proofModeManifest, isNull);
      expect(video.proofModeDeviceAttestation, isNull);
      expect(video.proofModePgpFingerprint, isNull);
      expect(video.proofModeC2paManifestId, isNull);
      expect(video.hasProofMode, isFalse);
      expect(video.hasBasicProof, isFalse);
    });

    test('verified summary maps matching verified level', () {
      final mobileVideo = _videoWithProofSummary(
        const ProofVerificationSummary(
          status: 'verified',
          level: 'verified_mobile',
          version: 1,
          checks: {
            'proofmode_present': true,
            'proofmode_parse_ok': true,
            'device_attestation_present': true,
            'device_attestation_valid': true,
          },
        ),
      );
      final webVideo = _videoWithProofSummary(
        const ProofVerificationSummary(
          status: 'verified',
          level: 'verified_web',
          version: 1,
          checks: {
            'proofmode_present': true,
            'proofmode_parse_ok': true,
            'pgp_signature_present': true,
            'pgp_signature_valid': true,
          },
        ),
      );

      expect(mobileVideo.hasProofMode, isTrue);
      expect(mobileVideo.isVerifiedMobile, isTrue);
      expect(mobileVideo.isVerifiedWeb, isFalse);
      expect(webVideo.hasProofMode, isTrue);
      expect(webVideo.isVerifiedMobile, isFalse);
      expect(webVideo.isVerifiedWeb, isTrue);
    });

    test('present summary with usable component supports basic proof', () {
      final video = _videoWithProofSummary(
        const ProofVerificationSummary(
          status: 'present',
          level: 'basic_proof',
          version: 1,
          checks: {
            'proofmode_present': true,
            'proofmode_parse_ok': true,
          },
        ),
      );

      expect(video.hasProofMode, isTrue);
      expect(video.hasBasicProof, isTrue);
      expect(video.isVerifiedMobile, isFalse);
      expect(video.isVerifiedWeb, isFalse);
    });
  });
}

VideoEvent _videoWithProofSummary(ProofVerificationSummary proofSummary) {
  return VideoEvent(
    id: 'test-id',
    pubkey: 'test-pubkey',
    createdAt: 1700000000,
    content: 'test',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      1700000000 * 1000,
      isUtc: true,
    ),
    proofSummary: proofSummary,
  );
}

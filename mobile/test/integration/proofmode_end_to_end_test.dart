// ABOUTME: End-to-end integration test for ProofMode data flow
// ABOUTME: Verifies proof data flows from recording → draft → upload → Nostr publish

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';

void main() {
  group('ProofMode End-to-End Flow', () {
    test('Draft with ProofMode → Upload with ProofMode → Publish with tags', () {
      // Step 1: Create native proof data (simulating what native library returns)
      final nativeProof = NativeProofData(
        videoHash: 'abc123def456',
        sensorDataCsv: 'timestamp,lat,lon\n2025-01-01,40.7,-74.0',
        pgpSignature:
            '-----BEGIN PGP SIGNATURE-----\ntest\n-----END PGP SIGNATURE-----',
        publicKey:
            '-----BEGIN PGP PUBLIC KEY BLOCK-----\ntest\n-----END PGP PUBLIC KEY BLOCK-----',
        deviceAttestation: 'attestation_token_12345',
      );

      print('✅ Step 1: NativeProofData created');
      print('   videoHash: ${nativeProof.videoHash}');
      print('   verificationLevel: ${nativeProof.verificationLevel}');
      expect(nativeProof.videoHash, equals('abc123def456'));
      expect(nativeProof.verificationLevel, equals('verified_mobile'));

      // Step 2: Serialize to JSON (as done in VineRecordingProvider:173)
      final proofJson = jsonEncode(nativeProof.toJson());
      print('✅ Step 2: Serialized to JSON');
      print('   JSON length: ${proofJson.length} chars');
      expect(proofJson, contains('videoHash'));
      expect(proofJson, contains('abc123def456'));

      // Step 3: Create draft with proof data (as done in VineRecordingProvider:180-189)
      final draft = VineDraft.create(
        clips: [
          RecordingClip(
            id: 'id',
            video: EditorVideo.file('/tmp/test.mp4'),
            duration: Duration(seconds: 4),
            recordedAt: .now(),
            aspectRatio: .vertical,
          ),
        ],
        title: 'Test Video',
        description: 'Test description',
        hashtags: {'test'},
        selectedApproach: 'native',
        proofManifestJson: proofJson,
      );

      print('✅ Step 3: VineDraft created');
      print('   hasProofMode: ${draft.hasProofMode}');
      print('   nativeProof: ${draft.nativeProof}');
      expect(
        draft.hasProofMode,
        isTrue,
        reason: 'Draft MUST have ProofMode data',
      );
      expect(
        draft.nativeProof,
        isNotNull,
        reason: 'Draft MUST parse NativeProofData',
      );
      expect(draft.nativeProof!.videoHash, equals('abc123def456'));

      // Step 4: Convert draft to PendingUpload (as done in UploadManager:startUpload)
      final upload = PendingUpload.create(
        localVideoPath: draft.clips.first.video.file!.path,
        nostrPubkey: 'pubkey123',
        title: draft.title,
        description: draft.description,
        hashtags: draft.hashtags.toList(),
        proofManifestJson: draft.proofManifestJson,
      );

      print('✅ Step 4: PendingUpload created');
      print('   hasProofMode: ${upload.hasProofMode}');
      print('   nativeProof: ${upload.nativeProof}');
      expect(
        upload.hasProofMode,
        isTrue,
        reason: 'Upload MUST have ProofMode data',
      );
      expect(
        upload.nativeProof,
        isNotNull,
        reason: 'Upload MUST parse NativeProofData',
      );
      expect(upload.nativeProof!.videoHash, equals('abc123def456'));

      // Step 5: Verify tags would be generated (as done in VideoEventPublisher:392-416)
      final parsedProof = upload.nativeProof!;
      final verificationLevel = parsedProof.verificationLevel;
      final manifestTag = jsonEncode(parsedProof.toJson());
      final attestationTag = parsedProof.deviceAttestation;
      final pgpTag = parsedProof.pgpFingerprint;

      print('✅ Step 5: Nostr tags would be generated');
      print('   proof-verification-level: $verificationLevel');
      print('   proofmode tag length: ${manifestTag.length} chars');
      print(
        '   proof-device-attestation: ${attestationTag != null ? "present" : "missing"}',
      );
      print(
        '   proof-pgp-fingerprint: ${pgpTag != null ? "present" : "missing"}',
      );

      expect(verificationLevel, equals('verified_mobile'));
      expect(manifestTag, contains('videoHash'));
      expect(attestationTag, isNotNull);

      print('\n🎉 END-TO-END TEST PASSED');
      print('   ProofMode data flows correctly from draft → upload → publish');
    });

    test('Missing ProofMode data is handled gracefully', () {
      // Draft without ProofMode
      final draft = VineDraft.create(
        clips: [
          RecordingClip(
            id: 'id',
            video: EditorVideo.file('/tmp/test.mp4'),
            duration: Duration(seconds: 4),
            recordedAt: .now(),
            aspectRatio: .vertical,
          ),
        ],
        title: 'Test Video',
        description: 'Test description',
        hashtags: {'test'},
        selectedApproach: 'native',
      );

      print('✅ Draft created without ProofMode');
      expect(draft.hasProofMode, isFalse);
      expect(draft.nativeProof, isNull);

      // Upload should also not have ProofMode
      final upload = PendingUpload.create(
        localVideoPath: draft.clips.first.video.file!.path,
        nostrPubkey: 'pubkey123',
      );

      print('✅ Upload created without ProofMode');
      expect(upload.hasProofMode, isFalse);
      expect(upload.nativeProof, isNull);

      print('\n🎉 GRACEFUL HANDLING TEST PASSED');
    });
  });
}

// ABOUTME: Tests for the clip proof backfill logic used by render service
// ABOUTME: Validates the proof attestation contract for clip collections

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Replicates the _ensureClipProofs logic for testable unit verification.
///
/// In production, [NativeProofModeService.proofFile] is called for clips
/// missing proof. Here we simulate the outcome to validate the contract:
/// - Clips with existing proof are passed through unchanged.
/// - Clips without proof receive generated attestation data.
/// - Clips without a video file are passed through unchanged.
List<DivineVideoClip> ensureClipProofsSimulated(
  List<DivineVideoClip> clips, {
  required Map<String, dynamic> Function(String clipId) proofGenerator,
}) {
  final result = <DivineVideoClip>[];
  for (final clip in clips) {
    if (clip.proofManifestJson != null) {
      result.add(clip);
      continue;
    }

    final videoFile = clip.video.file;
    if (videoFile == null) {
      result.add(clip);
      continue;
    }

    final proofData = proofGenerator(clip.id);
    result.add(clip.copyWith(proofManifestJson: jsonEncode(proofData)));
  }
  return result;
}

void main() {
  group('ensureClipProofs contract', () {
    DivineVideoClip createClip({
      required String id,
      String? proofManifestJson,
      String filePath = '/path/to/video.mp4',
    }) {
      return DivineVideoClip(
        id: id,
        video: EditorVideo.file(filePath),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2025, 12, 13, 10),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        proofManifestJson: proofManifestJson,
      );
    }

    test('passes through clips that already have proof', () {
      final clips = [
        createClip(id: 'clip_1', proofManifestJson: '{"hash":"existing"}'),
        createClip(id: 'clip_2', proofManifestJson: '{"hash":"also_exists"}'),
      ];

      var generatorCalled = false;
      final result = ensureClipProofsSimulated(
        clips,
        proofGenerator: (_) {
          generatorCalled = true;
          return {'hash': 'should_not_be_used'};
        },
      );

      expect(generatorCalled, isFalse);
      expect(result.length, equals(2));
      expect(
        result[0].proofManifestJson,
        equals('{"hash":"existing"}'),
      );
      expect(
        result[1].proofManifestJson,
        equals('{"hash":"also_exists"}'),
      );
    });

    test('generates proof for clips missing attestation', () {
      final clips = [
        createClip(id: 'clip_1'),
        createClip(id: 'clip_2'),
      ];

      final generatedIds = <String>[];
      final result = ensureClipProofsSimulated(
        clips,
        proofGenerator: (clipId) {
          generatedIds.add(clipId);
          return {'hash': 'generated_$clipId'};
        },
      );

      expect(generatedIds, equals(['clip_1', 'clip_2']));
      expect(result.length, equals(2));
      expect(
        result[0].proofManifestJson,
        equals('{"hash":"generated_clip_1"}'),
      );
      expect(
        result[1].proofManifestJson,
        equals('{"hash":"generated_clip_2"}'),
      );
    });

    test('only generates proof for clips that need it', () {
      final clips = [
        createClip(id: 'clip_1', proofManifestJson: '{"hash":"existing"}'),
        createClip(id: 'clip_2'),
        createClip(id: 'clip_3', proofManifestJson: '{"hash":"also_exists"}'),
        createClip(id: 'clip_4'),
      ];

      final generatedIds = <String>[];
      final result = ensureClipProofsSimulated(
        clips,
        proofGenerator: (clipId) {
          generatedIds.add(clipId);
          return {'hash': 'backfilled_$clipId'};
        },
      );

      expect(generatedIds, equals(['clip_2', 'clip_4']));
      expect(result.length, equals(4));
      expect(
        result[0].proofManifestJson,
        equals('{"hash":"existing"}'),
      );
      expect(
        result[1].proofManifestJson,
        equals('{"hash":"backfilled_clip_2"}'),
      );
      expect(
        result[2].proofManifestJson,
        equals('{"hash":"also_exists"}'),
      );
      expect(
        result[3].proofManifestJson,
        equals('{"hash":"backfilled_clip_4"}'),
      );
    });

    test('handles empty clip list', () {
      final result = ensureClipProofsSimulated(
        [],
        proofGenerator: (_) => {'hash': 'unused'},
      );

      expect(result, isEmpty);
    });

    test('preserves clip order', () {
      final clips = [
        createClip(id: 'clip_a'),
        createClip(id: 'clip_b', proofManifestJson: '{"hash":"b"}'),
        createClip(id: 'clip_c'),
      ];

      final result = ensureClipProofsSimulated(
        clips,
        proofGenerator: (clipId) => {'hash': 'gen_$clipId'},
      );

      expect(result[0].id, equals('clip_a'));
      expect(result[1].id, equals('clip_b'));
      expect(result[2].id, equals('clip_c'));
    });

    test('preserves all clip metadata when adding proof', () {
      final clip = DivineVideoClip(
        id: 'clip_full',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2025, 12, 13, 10),
        targetAspectRatio: .square,
        originalAspectRatio: 1,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final result = ensureClipProofsSimulated(
        [clip],
        proofGenerator: (_) => {'hash': 'abc123'},
      );

      final attested = result.first;
      expect(attested.id, equals('clip_full'));
      expect(attested.duration, equals(const Duration(seconds: 5)));
      expect(attested.recordedAt, equals(DateTime(2025, 12, 13, 10)));
      expect(attested.targetAspectRatio, equals(model.AspectRatio.square));
      expect(attested.thumbnailPath, equals('/path/to/thumb.jpg'));
      expect(attested.proofManifestJson, equals('{"hash":"abc123"}'));
    });

    test('single clip list with proof is returned unchanged', () {
      final clip = createClip(
        id: 'solo',
        proofManifestJson: '{"hash":"solo_proof"}',
      );

      var called = false;
      final result = ensureClipProofsSimulated(
        [clip],
        proofGenerator: (_) {
          called = true;
          return {};
        },
      );

      expect(called, isFalse);
      expect(result.length, equals(1));
      expect(result.first.proofManifestJson, equals('{"hash":"solo_proof"}'));
    });

    test('single clip list without proof gets attested', () {
      final clip = createClip(id: 'solo');

      final result = ensureClipProofsSimulated(
        [clip],
        proofGenerator: (_) => {'hash': 'attested'},
      );

      expect(result.length, equals(1));
      expect(
        result.first.proofManifestJson,
        equals('{"hash":"attested"}'),
      );
    });

    test('generated proof JSON is valid and decodable', () {
      final clip = createClip(id: 'clip_json');

      final result = ensureClipProofsSimulated(
        [clip],
        proofGenerator: (_) => {
          'manifest': {'alg': 'sha256', 'hash': 'abc123'},
          'assertions': [
            {
              'label': 'c2pa.actions',
              'data': {
                'actions': [
                  {'action': 'c2pa.created'},
                ],
              },
            },
          ],
          'claim_generator': 'divine/1.0',
        },
      );

      final json = result.first.proofManifestJson!;
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded, containsPair('claim_generator', 'divine/1.0'));
      expect(decoded['manifest'], isA<Map<String, dynamic>>());
      expect(decoded['assertions'], isA<List<dynamic>>());
    });
  });
}

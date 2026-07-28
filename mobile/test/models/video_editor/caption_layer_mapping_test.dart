// ABOUTME: Tests for the caption layer <-> cue mapping helpers.
// ABOUTME: Covers cue-id extraction and transform preservation on re-edit.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/caption_layer_mapping.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

TextLayer _captionLayer(
  String cueId, {
  Offset offset = Offset.zero,
  double scale = 1,
  double rotation = 0,
}) => TextLayer(
  text: 'hi',
  offset: offset,
  scale: scale,
  rotation: rotation,
  meta: {
    VideoEditorConstants.captionCueMetaKey: true,
    VideoEditorConstants.captionCueIdMetaKey: cueId,
  },
);

void main() {
  group('captionCueIdOf', () {
    test('returns the cue id for a caption layer', () {
      expect(captionCueIdOf(_captionLayer('cue-7')), equals('cue-7'));
    });

    test('returns null for a non-caption layer', () {
      expect(captionCueIdOf(TextLayer(text: 'plain')), isNull);
    });
  });

  group('preserveCaptionLayerTransform', () {
    test('carries an existing layer transform onto the rebuilt one', () {
      final existing = _captionLayer(
        'cue-1',
        offset: const Offset(30, 40),
        scale: 1.5,
        rotation: 0.25,
      );
      final rebuilt = _captionLayer('cue-1');

      final result = preserveCaptionLayerTransform(rebuilt, existing);

      expect(result.offset, equals(const Offset(30, 40)));
      expect(result.scale, equals(1.5));
      expect(result.rotation, equals(0.25));
    });

    test('returns the rebuilt layer unchanged when there is no match', () {
      final rebuilt = _captionLayer('cue-1', offset: const Offset(1, 2));

      expect(
        preserveCaptionLayerTransform(rebuilt, null).offset,
        equals(const Offset(1, 2)),
      );
    });
  });
}

// ABOUTME: Tests for DivineVideoDraft.canPost getter
// ABOUTME: Validates the draft is only postable once a final render exists

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _createTestClip() => DivineVideoClip(
  id: 'clip_1',
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

DivineVideoDraft _draft({DivineVideoClip? finalRenderedClip}) =>
    DivineVideoDraft(
      id: 'draft_1',
      clips: [_createTestClip()],
      title: '',
      description: '',
      hashtags: const {},
      selectedApproach: 'camera',
      createdAt: DateTime(2025),
      lastModified: DateTime(2025),
      publishStatus: PublishStatus.draft,
      publishAttempts: 0,
      finalRenderedClip: finalRenderedClip,
    );

void main() {
  group(DivineVideoDraft, () {
    group('canPost', () {
      test('returns false when finalRenderedClip is null', () {
        expect(_draft().canPost, isFalse);
      });

      test('returns true when finalRenderedClip is present', () {
        expect(_draft(finalRenderedClip: _createTestClip()).canPost, isTrue);
      });
    });
  });
}

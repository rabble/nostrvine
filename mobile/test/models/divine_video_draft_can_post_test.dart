// ABOUTME: Tests for DivineVideoDraft.canPost getter
// ABOUTME: Validates library draft post eligibility mirrors publish behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _createTestClip([String id = 'clip_1']) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

DivineVideoDraft _draft({
  List<DivineVideoClip>? clips,
  DivineVideoClip? finalRenderedClip,
}) => DivineVideoDraft(
  id: 'draft_1',
  clips: clips ?? [_createTestClip()],
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
      test('returns false for single-clip draft without final render', () {
        expect(_draft().canPost, isFalse);
      });

      test('returns true for multi-clip draft without final render', () {
        expect(
          _draft(
            clips: [_createTestClip(), _createTestClip('clip_2')],
          ).canPost,
          isTrue,
        );
      });

      test('returns true when finalRenderedClip is present', () {
        expect(_draft(finalRenderedClip: _createTestClip()).canPost, isTrue);
      });
    });
  });
}

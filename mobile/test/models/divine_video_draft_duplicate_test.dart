// ABOUTME: Tests for DivineVideoDraft.duplicate
// ABOUTME: Validates fresh id/timestamps, reset publish state, shared content

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

DivineVideoDraft _createDraft() => DivineVideoDraft(
  id: 'draft_1',
  clips: [_createTestClip(), _createTestClip('clip_2')],
  title: 'My Project',
  description: 'A test draft',
  hashtags: const {'test', 'vine'},
  selectedApproach: 'camera',
  createdAt: DateTime(2025),
  lastModified: DateTime(2025),
  publishStatus: PublishStatus.failed,
  publishAttempts: 3,
  publishError: 'some error',
  sourceDraftId: 'draft_source',
  proofManifestJson: '{"videoHash":"abc"}',
  editorStateHistory: const {'foo': 'bar'},
  collaboratorPubkeys: const {'pubkey1'},
  finalRenderedClip: _createTestClip('rendered'),
  contentWarning: 'sensitive',
);

void main() {
  group('DivineVideoDraft.duplicate', () {
    test('assigns a fresh id distinct from the source', () {
      final draft = _createDraft();
      final copy = draft.duplicate();

      expect(copy.id, isNot(equals(draft.id)));
      expect(copy.id, startsWith('draft_'));
    });

    test('resets publish state', () {
      final copy = _createDraft().duplicate();

      expect(copy.publishStatus, equals(PublishStatus.draft));
      expect(copy.publishAttempts, equals(0));
      expect(copy.publishError, isNull);
      expect(copy.sourceDraftId, isNull);
    });

    test('refreshes createdAt and lastModified', () {
      final draft = _createDraft();
      final copy = draft.duplicate();

      expect(copy.createdAt.isAfter(draft.createdAt), isTrue);
      expect(copy.lastModified.isAfter(draft.lastModified), isTrue);
    });

    test('keeps the original title when none is provided', () {
      final copy = _createDraft().duplicate();

      expect(copy.title, equals('My Project'));
    });

    test('overrides the title when one is provided', () {
      final copy = _createDraft().duplicate(title: 'My Project (copy)');

      expect(copy.title, equals('My Project (copy)'));
    });

    test('shares clips and content with the source', () {
      final draft = _createDraft();
      final copy = draft.duplicate();

      expect(copy.clips, same(draft.clips));
      expect(copy.description, equals(draft.description));
      expect(copy.hashtags, equals(draft.hashtags));
      expect(copy.selectedApproach, equals(draft.selectedApproach));
      expect(copy.editorStateHistory, equals(draft.editorStateHistory));
      expect(copy.collaboratorPubkeys, equals(draft.collaboratorPubkeys));
      expect(copy.proofManifestJson, equals(draft.proofManifestJson));
      expect(copy.contentWarning, equals(draft.contentWarning));
      expect(copy.finalRenderedClip, equals(draft.finalRenderedClip));
    });

    test('leaves the source draft unchanged', () {
      final draft = _createDraft();
      draft.duplicate(title: 'Something else');

      expect(draft.id, equals('draft_1'));
      expect(draft.title, equals('My Project'));
      expect(draft.publishStatus, equals(PublishStatus.failed));
      expect(draft.sourceDraftId, equals('draft_source'));
    });
  });
}

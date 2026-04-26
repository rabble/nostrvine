// ABOUTME: Tests for DivineVideoDraft.hasBeenEdited getter
// ABOUTME: Validates detection of edits beyond initial recording

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent, InspiredByInfo;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _testPubkey =
    'abc123def456789012345678901234567890123456789012345678901234abcd';

DivineVideoClip _createTestClip() => DivineVideoClip(
  id: 'clip_1',
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2025),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

/// Creates a minimal draft with no edits (only clips, defaults for everything
/// else). This is the baseline: [hasBeenEdited] should be false.
DivineVideoDraft _minimalDraft({List<DivineVideoClip>? clips}) =>
    DivineVideoDraft(
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
    );

void main() {
  group(DivineVideoDraft, () {
    group('hasBeenEdited', () {
      test('returns false when draft has clips but no edits', () {
        final draft = _minimalDraft();

        expect(draft.hasBeenEdited, isFalse);
      });

      test('returns false when draft has no clips', () {
        final draft = _minimalDraft(clips: []);

        expect(draft.hasBeenEdited, isFalse);
      });

      test('returns false when draft has no clips even with metadata', () {
        final draft = DivineVideoDraft(
          id: 'draft_1',
          clips: const [],
          title: 'Has a title',
          description: 'Has a description',
          hashtags: const {'tag'},
          selectedApproach: 'camera',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        expect(draft.hasBeenEdited, isFalse);
      });

      test('returns true when draft has title', () {
        final draft = _minimalDraft().copyWith(
          title: 'My Video',
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when draft has description', () {
        final draft = _minimalDraft().copyWith(
          description: 'A great video',
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when draft has hashtags', () {
        final draft = _minimalDraft().copyWith(
          hashtags: const {'flutter'},
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when draft has editorStateHistory', () {
        final draft = _minimalDraft().copyWith(
          editorStateHistory: const {'key': 'value'},
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns false when editorStateHistory position is -1', () {
        final draft = _minimalDraft().copyWith(
          editorStateHistory: const {'position': -1},
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isFalse);
      });

      test('returns true when editorStateHistory position is not -1', () {
        final draft = _minimalDraft().copyWith(
          editorStateHistory: const {'position': 0},
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns false when draft has editorEditingParameters only', () {
        final draft = _minimalDraft().copyWith(
          editorEditingParameters: const {'param': 'value'},
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isFalse);
      });

      test('returns true when draft has finalRenderedClip', () {
        final draft = _minimalDraft().copyWith(
          finalRenderedClip: _createTestClip(),
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when draft has selectedSound', () {
        final draft = _minimalDraft().copyWith(
          selectedSound: const AudioEvent(
            id: 'sound-id-12345678901234567890123456789012345678901234567890123',
            pubkey: _testPubkey,
            createdAt: 1700000000,
            url: 'https://blossom.example/audio.aac',
            title: 'Test Sound',
          ),
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when draft has contentWarning', () {
        final draft = _minimalDraft().copyWith(
          contentWarning: 'nsfw',
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when draft has collaboratorPubkeys', () {
        final draft = _minimalDraft().copyWith(
          collaboratorPubkeys: {_testPubkey},
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when draft has inspiredByVideo', () {
        final draft = _minimalDraft().copyWith(
          inspiredByVideo: const InspiredByInfo(
            addressableId: '34236:$_testPubkey:some-dtag',
          ),
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when draft has inspiredByNpub', () {
        final draft = _minimalDraft().copyWith(
          inspiredByNpub: _testPubkey,
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when originalAudioVolume is not 1.0', () {
        final draft = _minimalDraft().copyWith(
          originalAudioVolume: 0.5,
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when customAudioVolume is not 1.0', () {
        final draft = _minimalDraft().copyWith(
          customAudioVolume: 0.8,
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns true when expireTime is set', () {
        final draft = _minimalDraft().copyWith(
          expireTime: const Duration(days: 7),
          skipUpdateLastModified: true,
        );

        expect(draft.hasBeenEdited, isTrue);
      });

      test('returns false when allowAudioReuse is true only', () {
        final draft = DivineVideoDraft(
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
          allowAudioReuse: true,
        );

        expect(draft.hasBeenEdited, isFalse);
      });

      // Guard test: uses toJson() as the source of truth for all
      // persisted fields. Every field MUST appear in toJson() (or it
      // would be lost on save), so toJson().keys is a reliable proxy
      // for the full field list.
      //
      // If this test fails, a new field was added to toJson() but not
      // registered here. Decide: should hasBeenEdited check it?
      //   YES → add to checkedFields, add a check in hasBeenEdited,
      //         and add a dedicated test above
      //   NO  → add to excludedFields with a comment explaining why
      test('covers all persisted DivineVideoDraft fields', () {
        // Build a draft with every optional field set to a non-default
        // value so toJson() emits all conditional keys.
        final fullyPopulated = DivineVideoDraft(
          id: 'guard',
          clips: [_createTestClip()],
          title: 'T',
          description: 'D',
          hashtags: const {'h'},
          selectedApproach: 'camera',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          publishStatus: PublishStatus.draft,
          publishAttempts: 1,
          publishError: 'err',
          expireTime: const Duration(days: 1),
          proofManifestJson: '{}',
          editorStateHistory: const {'k': 'v'},
          editorEditingParameters: const {'k': 'v'},
          finalRenderedClip: _createTestClip(),
          collaboratorPubkeys: const {'pk'},
          inspiredByVideo: const InspiredByInfo(
            addressableId: '34236:$_testPubkey:dtag',
          ),
          inspiredByNpub: _testPubkey,
          selectedSound: const AudioEvent(
            id:
                'snd-1234567890123456789012345678901234'
                '5678901234567890123456',
            pubkey: _testPubkey,
            createdAt: 1700000000,
            url: 'https://example.com/a.aac',
            title: 'S',
          ),
          contentWarning: 'nsfw',
          originalAudioVolume: 0.5,
          customAudioVolume: 0.5,
        );

        final actualKeys = fullyPopulated.toJson().keys.toSet();

        // Fields checked by hasBeenEdited:
        const checkedFields = {
          'clips', // guard: clips.isNotEmpty
          'title',
          'description',
          'hashtags',
          'editorStateHistory',
          'finalRenderedClip',
          'selectedSound',
          'contentWarning',
          'collaboratorPubkeys',
          'inspiredByVideo',
          'inspiredByNpub',
          'originalAudioVolume',
          'customAudioVolume',
          'expireTime',
        };

        // Fields intentionally excluded from hasBeenEdited:
        const excludedFields = {
          'id', // identity, not user content
          'selectedApproach', // always set at creation
          'createdAt', // timestamp metadata
          'lastModified', // timestamp metadata
          'publishStatus', // lifecycle status
          'publishAttempts', // lifecycle counter
          'publishError', // transient error
          'proofManifestJson', // auto-generated, not a user edit
          'editorEditingParameters', // editor internals, not user-facing edit
          'allowAudioReuse', // publishing option, not edit indicator
        };

        final knownFields = {...checkedFields, ...excludedFields};

        expect(
          actualKeys,
          equals(knownFields),
          reason:
              'toJson() keys do not match the known field sets. '
              'A field was added to or removed from DivineVideoDraft. '
              'Update checkedFields or excludedFields above '
              '(and hasBeenEdited if needed).',
        );

        // No overlap between the two sets
        expect(
          checkedFields.intersection(excludedFields),
          isEmpty,
          reason: 'A field appears in both checked and excluded sets',
        );
      });
    });
  });
}

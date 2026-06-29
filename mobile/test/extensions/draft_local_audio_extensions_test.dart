// ABOUTME: Tests for DraftLocalAudioPaths.localAudioFilePaths extraction
// ABOUTME: Validates imported audio + voice-over paths are collected for cleanup

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/draft_local_audio_extensions.dart';
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

DivineVideoDraft _draft({
  Map<String, dynamic> editorStateHistory = const {},
  AudioEvent? selectedSound,
}) => DivineVideoDraft(
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
  editorStateHistory: editorStateHistory,
  selectedSound: selectedSound,
);

AudioEvent _localImport(String id, String path) => AudioEvent.fromLocalImport(
  id: id,
  filePath: path,
  createdAt: 1700000000,
  title: 'Imported',
  mimeType: 'audio/mp4',
);

Map<String, dynamic> _historyWithAudio(List<AudioEvent> tracks) => {
  'position': 0,
  'history': [
    {
      'meta': {
        VideoEditorConstants.audioStateHistoryKey: tracks
            .map((t) => t.toJson())
            .toList(),
      },
    },
  ],
};

void main() {
  group('DraftLocalAudioPaths', () {
    test('returns empty when no audio metadata exists', () {
      expect(_draft().localAudioFilePaths, isEmpty);
    });

    test('collects imported-audio path from editor history', () {
      const path = '/docs/draft_audio_imports/draft_1/imported.m4a';
      final draft = _draft(
        editorStateHistory: _historyWithAudio([
          _localImport('local_import_1', path),
        ]),
      );

      expect(draft.localAudioFilePaths, {path});
    });

    test('collects voice-over recording path from editor history', () {
      const path = '/docs/voice_over_recordings/voice_over_1.m4a';
      final draft = _draft(
        editorStateHistory: _historyWithAudio([
          _localImport('local_import_voice_over_1', path),
        ]),
      );

      expect(draft.localAudioFilePaths, {path});
    });

    test('collects local audio held in legacy selectedSound', () {
      const path = '/docs/draft_audio_imports/draft_1/selected.m4a';
      final draft = _draft(selectedSound: _localImport('local_import_2', path));

      expect(draft.localAudioFilePaths, {path});
    });

    test('ignores non-local audio (bundled, network, original sound)', () {
      final draft = _draft(
        editorStateHistory: _historyWithAudio([
          const AudioEvent(
            id: 'bundled_chime',
            pubkey: AudioEvent.bundledMarker,
            createdAt: 0,
            url: 'asset://sounds/chime.mp3',
          ),
          const AudioEvent(
            id: 'remote-sound-id',
            pubkey: _testPubkey,
            createdAt: 1700000000,
            url: 'https://cdn.example.com/audio.mp3',
          ),
        ]),
        selectedSound: const AudioEvent(
          id: 'video_remote',
          pubkey: _testPubkey,
          createdAt: 1700000000,
          url: 'https://cdn.example.com/original.mp4',
        ),
      );

      expect(draft.localAudioFilePaths, isEmpty);
    });

    test('deduplicates a path repeated across history entries', () {
      const path = '/docs/voice_over_recordings/voice_over_1.m4a';
      final track = _localImport('local_import_voice_over_1', path);
      final draft = _draft(
        editorStateHistory: {
          'position': 1,
          'history': [
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
              },
            },
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: [track.toJson()],
              },
            },
          ],
        },
      );

      expect(draft.localAudioFilePaths, {path});
    });

    test('does not throw on malformed history shapes', () {
      final draft = _draft(
        editorStateHistory: const {
          'history': [
            'not-a-map',
            {'meta': 'not-a-map'},
            {
              'meta': {VideoEditorConstants.audioStateHistoryKey: 'not-a-list'},
            },
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: ['not-a-map'],
              },
            },
          ],
        },
      );

      expect(draft.localAudioFilePaths, isEmpty);
    });

    test('skips audio entries that parse as a map but throw in fromJson', () {
      // These clear the `raw is! Map` guard and reach AudioEvent.fromJson,
      // where the non-nullable id/pubkey/createdAt casts throw — exercising
      // the try/catch "cleanup must never throw" branch.
      final draft = _draft(
        editorStateHistory: const {
          'history': [
            {
              'meta': {
                VideoEditorConstants.audioStateHistoryKey: [
                  <String, dynamic>{},
                  {'id': 123},
                ],
              },
            },
          ],
        },
      );

      expect(draft.localAudioFilePaths, isEmpty);
    });
  });
}

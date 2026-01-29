import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('VineDraft AspectRatio', () {
    test('create() includes aspect ratio', () {
      final testFile = File('test_video.mp4');
      final draft = VineDraft.create(
        clips: [
          RecordingClip(
            id: 'test_clip',
            video: EditorVideo.file(testFile.path),
            duration: Duration(seconds: 6),
            recordedAt: DateTime.now(),
            aspectRatio: AspectRatio.vertical,
          ),
        ],
        title: '',
        description: '',
        hashtags: {},
        selectedApproach: 'test',
      );

      expect(draft.clips.first.aspectRatio, equals(AspectRatio.vertical));
    });

    test('toJson includes aspectRatio', () {
      final testFile = File('test_video.mp4');
      final draft = VineDraft.create(
        clips: [
          RecordingClip(
            id: 'test_clip',
            video: EditorVideo.file(testFile.path),
            duration: Duration(seconds: 6),
            recordedAt: DateTime.now(),
            aspectRatio: AspectRatio.vertical,
          ),
        ],
        title: '',
        description: '',
        hashtags: {},
        selectedApproach: 'test',
      );

      expect(draft.clips.first.aspectRatio, equals(AspectRatio.vertical));
    });

    test('fromJson restores aspectRatio', () {
      final json = {
        'id': 'test-id',
        'clips': [
          RecordingClip(
            id: 'id',
            video: EditorVideo.file('video.mp4'),
            duration: Duration(seconds: 5),
            recordedAt: .now(),
            aspectRatio: .vertical,
          ).toJson(),
        ],
        'title': '',
        'description': '',
        'hashtags': <String>[],
        'selectedApproach': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
        'publishStatus': 'draft',
        'publishAttempts': 0,
      };

      final draft = VineDraft.fromJson(json);
      expect(draft.clips.first.aspectRatio, equals(AspectRatio.vertical));
    });

    test('fromJson defaults to square for legacy drafts', () {
      final json = {
        'id': 'test-id',
        'videoFilePath': '/path/to/video.mp4',
        'title': '',
        'description': '',
        'hashtags': <String>[],
        'selectedApproach': 'test',
        'createdAt': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
        'publishStatus': 'draft',
        'publishAttempts': 0,
        // No aspectRatio field (legacy draft)
      };

      final draft = VineDraft.fromJson(json);
      expect(draft.clips.first.aspectRatio, equals(AspectRatio.square));
    });
  });
}

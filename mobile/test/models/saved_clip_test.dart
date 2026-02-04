// ABOUTME: Tests for SavedClip model with session grouping
// ABOUTME: Verifies JSON serialization and session ID handling

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/saved_clip.dart';

void main() {
  group('SavedClip', () {
    test('should serialize sessionId to JSON', () {
      final clip = SavedClip(
        id: 'clip_1',
        filePath: '/path/to/video.mp4',
        thumbnailPath: '/path/to/thumb.jpg',
        duration: const Duration(seconds: 2),
        createdAt: DateTime(2025, 12, 18, 14, 30),
        aspectRatio: 'square',
        sessionId: 'session_123',
      );

      final json = clip.toJson();

      expect(json['sessionId'], 'session_123');
      // toJson stores only filenames for iOS compatibility
      expect(json['filePath'], 'video.mp4');
      expect(json['thumbnailPath'], 'thumb.jpg');
    });

    test('should deserialize sessionId from JSON', () {
      final json = {
        'id': 'clip_1',
        'filePath': 'video.mp4',
        'thumbnailPath': 'thumb.jpg',
        'durationMs': 2000,
        'createdAt': '2025-12-18T14:30:00.000',
        'aspectRatio': 'square',
        'sessionId': 'session_456',
      };

      final clip = SavedClip.fromJson(json, '/path/to');

      expect(clip.sessionId, 'session_456');
    });

    test('should handle null sessionId', () {
      final json = {
        'id': 'clip_1',
        'filePath': 'video.mp4',
        'thumbnailPath': null,
        'durationMs': 2000,
        'createdAt': '2025-12-18T14:30:00.000',
        'aspectRatio': 'square',
      };

      final clip = SavedClip.fromJson(json, '/path/to');

      expect(clip.sessionId, isNull);
    });
  });
}

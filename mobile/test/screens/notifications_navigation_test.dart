// ABOUTME: Test for notifications screen navigation to videos and profiles
// ABOUTME: Ensures stats extraction used by notification-opened videos preserves view counts.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';

void main() {
  group('notification-opened video stats', () {
    test('prefers raw views tag when present', () {
      final video = VideoEvent(
        id: 'video-1',
        pubkey: 'pubkey',
        createdAt: 1,
        content: 'https://example.com/video.mp4',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        rawTags: const {'views': '37'},
      );

      expect(extractViewLikeCount(video), 37);
    });

    test('falls back to originalLoops when views tag missing', () {
      final video = VideoEvent(
        id: 'video-2',
        pubkey: 'pubkey',
        createdAt: 1,
        content: 'https://example.com/video.mp4',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        originalLoops: 12,
      );

      expect(extractViewLikeCount(video), 12);
    });
  });
}

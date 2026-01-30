// ABOUTME: TDD tests for repost header display on VideoFeedItem
// ABOUTME: Tests that reposted videos show "X reposted" header with reposter's name

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/widget_test_helper.dart';
import 'video_feed_item_repost_header_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoFeedItem Repost Header - TDD', () {
    late VideoEvent originalVideo;
    late VideoEvent repostedVideo;
    late MockSharedPreferences mockPrefs;

    setUp(() {
      final now = DateTime.now();

      // Use valid 64-character hex pubkeys for realistic testing
      const originalAuthorPubkey =
          'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      const reposterPubkey =
          'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5';

      // Create original video
      originalVideo = VideoEvent(
        id: 'original_event_123',
        pubkey: originalAuthorPubkey,
        content: 'Original video content',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        title: 'Test Video',
        duration: 15,
        hashtags: ['test'],
        isRepost: false,
      );

      // Create reposted version
      repostedVideo = VideoEvent(
        id: 'original_event_123',
        pubkey: originalAuthorPubkey,
        content: 'Original video content',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        title: 'Test Video',
        duration: 15,
        hashtags: ['test'],
        isRepost: true,
        reposterPubkey: reposterPubkey,
        reposterId: 'repost_event_999',
        repostedAt: now,
      );

      mockPrefs = MockSharedPreferences();
      createMockSharedPreferences(mockPrefs);
    });

    // RED TEST 1: Regular videos should NOT show repost header
    testWidgets('does not show repost header for original videos', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            mockPrefs: mockPrefs,
            child: VideoFeedItem(
              video: originalVideo,
              index: 0,
              disableAutoplay: true,
              forceShowOverlay: true,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should NOT find "reposted" text (specific to repost header)
        expect(
          find.textContaining('reposted'),
          findsNothing,
          reason: 'Original videos should not have repost text',
        );
      });
    });

    // RED TEST 2: Reposted videos SHOULD show repost header
    testWidgets('shows repost header for reposted videos', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            mockPrefs: mockPrefs,
            child: VideoFeedItem(
              video: repostedVideo,
              index: 0,
              disableAutoplay: true,
              forceShowOverlay: true,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // RED: Expect to find "reposted" text
        expect(
          find.textContaining('reposted'),
          findsOneWidget,
          reason: 'Reposted videos should show "reposted" text',
        );
      });
    });

    // RED TEST 3: Repost header should show reposter's truncated npub
    testWidgets('repost header shows reposter truncated npub', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          createTestApp(
            mockPrefs: mockPrefs,
            child: VideoFeedItem(
              video: repostedVideo,
              index: 0,
              disableAutoplay: true,
              forceShowOverlay: true,
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Expect to find truncated npub (e.g., "npub1abc...xyz")
        final truncatedNpub = NostrKeyUtils.truncateNpub(
          repostedVideo.reposterPubkey!,
        );
        expect(
          find.textContaining(truncatedNpub),
          findsOneWidget,
          reason: 'Repost header should show truncated npub for reposter',
        );
      });
    });
    // TODO(any): Fix test infrastructure - VideoFeedItem needs many provider
    // overrides (visibilityTracker, authService, userProfileService, etc.)
    // Test code updated to expect truncated npub format per issue #804
  }, skip: true);
}

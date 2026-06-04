// ABOUTME: Verifies RelatedVideosWidget filters blocked/muted authors out of the
// ABOUTME: anonymous Funnelcake REST hashtag lookup (no server-side filter). See #4782.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/widgets/related_videos_widget.dart';
import 'package:openvine/widgets/video_explore_tile.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

VideoStats _stat(String id, String pubkey) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    createdAt: DateTime(2026, 3, 30, 12),
    kind: 22,
    dTag: id,
    title: 'Video $id',
    thumbnail: 'https://example.com/$id.jpg',
    videoUrl: 'https://example.com/$id.mp4',
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
  );
}

void main() {
  const currentPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const blockedPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  late _MockFunnelcakeApiClient mockFunnelcake;
  late _MockContentBlocklistRepository mockBlocklist;

  final currentVideo = VideoEvent(
    id: 'current-video',
    pubkey: currentPubkey,
    createdAt: 1000,
    content: '',
    timestamp: DateTime(2026),
    title: 'Current',
    videoUrl: 'https://example.com/current.mp4',
    hashtags: const ['test'],
  );

  setUp(() {
    mockFunnelcake = _MockFunnelcakeApiClient();
    mockBlocklist = _MockContentBlocklistRepository();
    when(() => mockFunnelcake.isAvailable).thenReturn(true);
  });

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        funnelcakeApiClientProvider.overrideWithValue(mockFunnelcake),
        contentBlocklistRepositoryProvider.overrideWithValue(mockBlocklist),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: RelatedVideosWidget(
            currentVideo: currentVideo,
            onVideoTap: (_, _) {},
          ),
        ),
      ),
    );
  }

  testWidgets('filters a blocked author from related videos (#4782)', (
    tester,
  ) async {
    // Only a blocked author's video is returned; after filtering the related
    // list is empty, proving the REST lookup consults the blocklist.
    when(
      () => mockFunnelcake.getVideosByHashtag(
        hashtag: any(named: 'hashtag'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [_stat('blocked-vid', blockedPubkey)]);
    when(
      () => mockBlocklist.shouldFilterFromFeeds(blockedPubkey),
    ).thenReturn(true);

    await tester.pumpWidget(buildSubject());
    await tester.pump(); // initState _loadRelatedVideos
    await tester.pump(const Duration(milliseconds: 100)); // settle REST
    await tester.pump(); // rebuild

    verify(
      () => mockBlocklist.shouldFilterFromFeeds(blockedPubkey),
    ).called(greaterThanOrEqualTo(1));
    expect(find.byType(VideoExploreTile), findsNothing);
    expect(find.text('No related videos found'), findsOneWidget);
    // Mutation note: if the filter were deleted or inverted, the blocked
    // video would render a VideoExploreTile and this assertion would fail.
  });
}

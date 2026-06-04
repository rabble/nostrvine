// ABOUTME: Verifies the hashtag feed filters blocked/muted authors out of the
// ABOUTME: anonymous Funnelcake REST path (no server-side block filter). See #4782.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/widgets/composable_video_grid.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockHashtagService extends Mock implements HashtagService {}

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
  const blockedPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  late _MockFunnelcakeApiClient mockFunnelcake;
  late _MockHashtagService mockHashtagService;
  late _MockContentBlocklistRepository mockBlocklist;

  setUp(() {
    mockFunnelcake = _MockFunnelcakeApiClient();
    mockHashtagService = _MockHashtagService();
    mockBlocklist = _MockContentBlocklistRepository();

    when(() => mockFunnelcake.isAvailable).thenReturn(true);
    when(
      () => mockFunnelcake.getClassicVideosByHashtag(
        hashtag: any(named: 'hashtag'),
      ),
    ).thenAnswer((_) async => <VideoStats>[]);

    when(() => mockHashtagService.getVideosByHashtags(any())).thenReturn([]);
    when(() => mockHashtagService.getHashtagStats(any())).thenReturn(null);
    when(
      () => mockHashtagService.subscribeToHashtagVideos(any()),
    ).thenAnswer((_) async {});
  });

  Widget buildSubject(String hashtag) {
    return ProviderScope(
      overrides: [
        funnelcakeApiClientProvider.overrideWithValue(mockFunnelcake),
        hashtagServiceProvider.overrideWith((ref) => mockHashtagService),
        contentBlocklistRepositoryProvider.overrideWithValue(mockBlocklist),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HashtagFeedScreen(hashtag: hashtag),
      ),
    );
  }

  testWidgets(
    "removes a blocked author's video from the hashtag REST feed (#4782)",
    (tester) async {
      // REST returns only a blocked author's video; after filtering the feed
      // must be empty (no grid), proving the REST path consults the blocklist.
      when(
        () => mockFunnelcake.getVideosByHashtag(hashtag: any(named: 'hashtag')),
      ).thenAnswer((_) async => [_stat('blocked-vid', blockedPubkey)]);
      when(
        () => mockBlocklist.shouldFilterFromFeeds(blockedPubkey),
      ).thenReturn(true);

      await tester.pumpWidget(buildSubject('bts'));
      await tester.pump(); // run post-frame _loadHashtagVideos
      await tester.pump(const Duration(milliseconds: 100)); // settle REST
      await tester.pump(); // rebuild with filtered list

      verify(
        () => mockBlocklist.shouldFilterFromFeeds(blockedPubkey),
      ).called(greaterThanOrEqualTo(1));
      expect(
        find.byType(ComposableVideoGrid),
        findsNothing,
        reason: "A blocked author's only video must not render a grid",
      );
      // Mutation note: if the filter were deleted or inverted, the blocked
      // video would render the grid above and this assertion would fail.
    },
  );
}

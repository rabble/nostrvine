// ABOUTME: Widget tests for CreatorAnalyticsScreen settings-linked layout.
// ABOUTME: Verifies analytics content aligns with settings menu max width.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_analytics_providers.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockCreatorAnalyticsRepository extends Mock
    implements CreatorAnalyticsRepository {}

void main() {
  Future<void> pumpAnalyticsScreen(
    WidgetTester tester, {
    required List<VideoEvent> videos,
  }) async {
    final authService = _MockAuthService();
    final repository = _MockCreatorAnalyticsRepository();
    final now = DateTime.now();

    when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
    when(() => repository.fetchCreatorAnalytics(any())).thenAnswer(
      (_) async => CreatorAnalyticsSnapshot(
        videos: videos,
        socialCounts: SocialCounts(
          pubkey: 'a' * 64,
          followerCount: 10,
          followingCount: 2,
        ),
        diagnostics: CreatorAnalyticsDiagnostics(
          totalVideos: videos.length,
          videosWithAnyViews: videos.length,
          videosMissingViews: 0,
          videosHydratedByBulkStats: 1,
          videosHydratedByViewsEndpoint: 0,
          sourcesUsed: const {AnalyticsDataSource.bulkVideoStats},
          fetchedAt: now,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          creatorAnalyticsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const CreatorAnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  VideoEvent analyticsVideo({
    required String id,
    required int views,
    int? originalLikes,
    int? originalComments,
    int? originalReposts,
    int? nostrLikeCount,
    int? nostrCommentCount,
    int? nostrRepostCount,
  }) {
    final now = DateTime.now();
    return VideoEvent(
      id: id,
      pubkey: 'a' * 64,
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      content: 'Analytics fixture video',
      timestamp: now,
      title: 'Analytics Fixture Video',
      rawTags: {'views': '$views'},
      originalLikes: originalLikes,
      originalComments: originalComments,
      originalReposts: originalReposts,
      originalLoops: views,
      nostrLikeCount: nostrLikeCount,
      nostrCommentCount: nostrCommentCount,
      nostrRepostCount: nostrRepostCount,
    );
  }

  testWidgets(
    'CreatorAnalyticsScreen constrains content width on wide screens',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpAnalyticsScreen(
        tester,
        videos: [
          analyticsVideo(
            id: 'video-1',
            views: 120,
            nostrLikeCount: 19,
            nostrCommentCount: 7,
            nostrRepostCount: 1,
          ),
        ],
      );

      final listViewWidth = tester.getSize(find.byType(ListView).first).width;
      expect(listViewWidth, moreOrLessEquals(600));
    },
  );

  testWidgets('counts native Divine engagement in creator analytics', (
    tester,
  ) async {
    await pumpAnalyticsScreen(
      tester,
      videos: [
        analyticsVideo(
          id: 'native-video',
          views: 120,
          nostrLikeCount: 19,
          nostrCommentCount: 7,
          nostrRepostCount: 1,
        ),
      ],
    );

    expect(find.text('27'), findsWidgets);
  });

  testWidgets('adds archived and live engagement for restored Vines', (
    tester,
  ) async {
    await pumpAnalyticsScreen(
      tester,
      videos: [
        analyticsVideo(
          id: 'mixed-video',
          views: 200,
          originalLikes: 10,
          originalComments: 1,
          originalReposts: 4,
          nostrLikeCount: 2,
          nostrCommentCount: 3,
          nostrRepostCount: 5,
        ),
      ],
    );

    expect(find.text('25'), findsWidgets);
  });
}

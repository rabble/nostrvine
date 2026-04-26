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
  testWidgets(
    'CreatorAnalyticsScreen constrains content width on wide screens',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final authService = _MockAuthService();
      final repository = _MockCreatorAnalyticsRepository();

      when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
      when(
        () => repository.fetchCreatorAnalytics(any()),
      ).thenAnswer((_) async {
        final now = DateTime.now();
        return CreatorAnalyticsSnapshot(
          videos: [
            VideoEvent(
              id: 'video-1',
              pubkey: 'a' * 64,
              createdAt: now.millisecondsSinceEpoch ~/ 1000,
              content: 'Analytics fixture video',
              timestamp: now,
              title: 'Analytics Fixture Video',
              rawTags: const {'views': '120'},
              originalLikes: 12,
              originalComments: 4,
              originalReposts: 2,
              originalLoops: 120,
            ),
          ],
          socialCounts: SocialCounts(
            pubkey: 'a' * 64,
            followerCount: 10,
            followingCount: 2,
          ),
          diagnostics: CreatorAnalyticsDiagnostics(
            totalVideos: 1,
            videosWithAnyViews: 1,
            videosMissingViews: 0,
            videosHydratedByBulkStats: 1,
            videosHydratedByViewsEndpoint: 0,
            sourcesUsed: const {AnalyticsDataSource.bulkVideoStats},
            fetchedAt: now,
          ),
        );
      });

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

      final listViewWidth = tester.getSize(find.byType(ListView).first).width;
      expect(listViewWidth, moreOrLessEquals(600));
    },
  );
}

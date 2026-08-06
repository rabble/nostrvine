import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/popular_videos_tab.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(PopularVideosTab, () {
    late _MockVideosRepository videosRepository;
    late _MockVideoEventService videoEventService;
    late _MockContentBlocklistRepository blocklistRepository;

    setUpAll(() {
      registerFallbackValue(PopularVideosVariant.native);
    });

    setUp(() {
      videosRepository = _MockVideosRepository();
      videoEventService = _MockVideoEventService();
      blocklistRepository = _MockContentBlocklistRepository();

      when(() => videoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            List<VideoEvent>.from(invocation.positionalArguments.first as List),
      );
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    testWidgets(
      'keeps the loaded grid on screen while the other variant loads',
      (
        tester,
      ) async {
        final classicCompleter = Completer<PopularVideosPage>();
        when(
          () => videosRepository.getPopularVideosPage(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            cursor: any(named: 'cursor'),
            variant: any(named: 'variant'),
            skipCache: any(named: 'skipCache'),
            preferredLanguages: any(named: 'preferredLanguages'),
            viewerCountry: any(named: 'viewerCountry'),
          ),
        ).thenAnswer((invocation) {
          final variant =
              invocation.namedArguments[#variant] as PopularVideosVariant;
          if (variant == PopularVideosVariant.native) {
            return Future.value(_popularPage([_video('popular-native')]));
          }
          return classicCompleter.future;
        });

        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              appReadyProvider.overrideWithValue(true),
              videosRepositoryProvider.overrideWithValue(videosRepository),
              videoEventServiceProvider.overrideWithValue(videoEventService),
              contentBlocklistRepositoryProvider.overrideWithValue(
                blocklistRepository,
              ),
            ],
            home: const Scaffold(body: PopularVideosTab()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey(PopularVideosVariant.native)),
          findsOneWidget,
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.categoryGallerySortClassic));
        await tester.pump();

        expect(
          find.byKey(const ValueKey(PopularVideosVariant.native)),
          findsOneWidget,
          reason:
              'The loaded page must stay on screen so the newly selected '
              'variant can cross-fade in.',
        );
        expect(find.byType(BrandedLoadingIndicator), findsNothing);

        classicCompleter.complete(_popularPage([_video('popular-classic')]));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey(PopularVideosVariant.classic)),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey(PopularVideosVariant.native)),
          findsNothing,
        );
      },
    );
  });
}

PopularVideosPage _popularPage(List<VideoEvent> videos) {
  return PopularVideosPage(videos: videos, hasMore: true);
}

VideoEvent _video(String id) {
  const createdAt = 1742169600;
  return VideoEvent(
    id: id,
    pubkey: 'author-$id',
    createdAt: createdAt,
    content: 'video $id',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
  );
}

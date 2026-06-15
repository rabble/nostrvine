import 'package:blurhash_service/blurhash_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../helpers/test_provider_overrides.dart'
    show createMockMediaCacheManager;
import '../test_data/video_test_data.dart';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group('VideoThumbnailWidget', () {
    late VideoEvent videoWithThumbnail;
    late VideoEvent videoWithBlurhash;
    late VideoEvent videoWithBoth;
    late VideoEvent videoWithNeither;

    setUp(() {
      // Video with only thumbnail URL
      videoWithThumbnail = createTestVideoEvent(
        id: 'test1',
        thumbnailUrl: 'https://example.com/thumb1.jpg',
      );

      // Video with only blurhash
      videoWithBlurhash = createTestVideoEvent(
        id: 'test2',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      // Video with both thumbnail and blurhash
      videoWithBoth = createTestVideoEvent(
        id: 'test3',
        thumbnailUrl: 'https://example.com/thumb3.jpg',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      // Video with neither
      videoWithNeither = createTestVideoEvent(id: 'test4');
    });

    // Stub the image cache (#5158 seam) so VineCachedImage does no real
    // path_provider / cache-manager work that could settle after the test and
    // cascade in the merged VGV optimizer isolate (#5159).
    setUp(() => debugImageCacheOverride = createMockMediaCacheManager());
    tearDown(() => debugImageCacheOverride = null);

    testWidgets('builds widget tree correctly when thumbnail URL exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Widget should build without error
      expect(find.byType(VideoThumbnailWidget), findsOneWidget);

      // Should create a VineCachedImage widget when thumbnail URL exists.
      expect(find.byType(VineCachedImage), findsOneWidget);
    });

    testWidgets(
      'uses Image.network for Divine-hosted thumbnails to avoid cache-manager stalls',
      (tester) async {
        final divineHostedVideo = createTestVideoEvent(
          id: 'test-divine',
          thumbnailUrl:
              'https://media.divine.video/72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995.jpg',
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: divineHostedVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets('displays flat placeholder when only blurhash is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show Container with surfaceContainer color as placeholder
      // (current implementation uses flat color instead of blurhash)
      expect(find.byType(Container), findsWidgets);

      // Should not show VineCachedImage since no thumbnail URL.
      expect(find.byType(VineCachedImage), findsNothing);
    });

    testWidgets('displays thumbnail with flat background when both exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBoth,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Should show VineCachedImage for thumbnail.
      expect(find.byType(VineCachedImage), findsOneWidget);
      expect(find.byType(Stack), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'displays flat placeholder when neither thumbnail nor blurhash exists',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: videoWithNeither,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show Container with surfaceContainer color as placeholder
        expect(find.byType(Container), findsWidgets);

        // Should not show VineCachedImage since no thumbnail URL.
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets('shows play icon when requested', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
              showPlayIcon: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show play icon
      expect(_divineIcon(DivineIconName.play), findsOneWidget);
    });

    testWidgets('applies border radius when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );

      // Should have ClipRRect with border radius
      expect(find.byType(ClipRRect), findsOneWidget);
      final ClipRRect clipRRect = tester.widget(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, equals(BorderRadius.circular(16)));
    });

    testWidgets('updates when video changes', (tester) async {
      // Start with video that has thumbnail
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Initially shows VineCachedImage for thumbnail.
      expect(find.byType(VineCachedImage), findsOneWidget);

      // Update to video with only blurhash (no thumbnail)
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should now show flat placeholder (no VineCachedImage).
      expect(find.byType(VineCachedImage), findsNothing);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets(
      'updates blurhash placeholder when enrichment returns same id new instance',
      (tester) async {
        const enrichedBlurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
        final unenrichedVideo = createTestVideoEvent(
          id: 'same-id',
          hashtags: const ['dance'],
        );
        final enrichedVideo = createTestVideoEvent(
          id: 'same-id',
          blurhash: enrichedBlurhash,
          hashtags: const ['dance'],
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: unenrichedVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(
          tester.widget<BlurhashDisplay>(find.byType(BlurhashDisplay)).blurhash,
          isNull,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: enrichedVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          tester.widget<BlurhashDisplay>(find.byType(BlurhashDisplay)).blurhash,
          enrichedBlurhash,
        );
      },
    );

    testWidgets(
      'updates derived content-type placeholder when metadata changes',
      (tester) async {
        final unknownVideo = createTestVideoEvent(
          id: 'same-id',
          hashtags: const ['random'],
          title: 'plain title',
          content: 'nothing special',
        );
        final danceVideo = createTestVideoEvent(
          id: 'same-id',
          hashtags: const ['dance'],
          title: 'plain title',
          content: 'nothing special',
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: unknownVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(
          tester
              .widget<BlurhashDisplay>(find.byType(BlurhashDisplay))
              .contentType,
          isNull,
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: danceVideo,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          tester
              .widget<BlurhashDisplay>(find.byType(BlurhashDisplay))
              .contentType,
          VineContentType.dance,
        );
      },
    );

    testWidgets('does not try to generate thumbnails when URL is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show flat placeholder, not loading indicator or image
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(VineCachedImage), findsNothing);
    });

    testWidgets('handles empty thumbnail URL as null', (tester) async {
      final videoWithEmptyUrl = createTestVideoEvent(
        id: 'test5',
        thumbnailUrl: '',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithEmptyUrl,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should treat empty URL as null and show flat placeholder
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(VineCachedImage), findsNothing);
    });
  });
}

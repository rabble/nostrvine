import 'dart:ui' as ui;

import 'package:blurhash_service/blurhash_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../helpers/test_provider_overrides.dart'
    show createMockMediaCacheManager;
import '../test_data/video_test_data.dart';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

double _thumbnailAspectRatio(WidgetTester tester) =>
    tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio;

/// An [ImageProvider] that synchronously yields a pre-built [ui.Image] so a
/// widget test can drive the image stream without an async decode.
class _SyncImageProvider extends ImageProvider<_SyncImageProvider> {
  _SyncImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_SyncImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_SyncImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _SyncImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    SynchronousFuture<ImageInfo>(ImageInfo(image: image)),
  );
}

/// Creates a [ui.Image] of exactly [width] x [height] without an async decode.
ui.Image _syncImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder);
  return recorder.endRecording().toImageSync(width, height);
}

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
      'updates missing metadata aspect ratio from the displayed cached image',
      (tester) async {
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

        expect(_thumbnailAspectRatio(tester), equals(2 / 3));

        final cachedImage = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        cachedImage.onImageDimensionsResolved!(640, 360);
        await tester.pump();

        expect(_thumbnailAspectRatio(tester), equals(640 / 360));
      },
    );

    testWidgets(
      'updates partial metadata aspect ratio from the displayed cached image',
      (tester) async {
        final videoWithPartialDimensions = createTestVideoEvent(
          id: 'test-partial-dimensions',
          thumbnailUrl: 'https://example.com/thumb-partial.jpg',
          dimensions: '640x',
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: videoWithPartialDimensions,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        expect(_thumbnailAspectRatio(tester), equals(2 / 3));

        final cachedImage = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        cachedImage.onImageDimensionsResolved!(640, 360);
        await tester.pump();

        expect(_thumbnailAspectRatio(tester), equals(640 / 360));
      },
    );

    testWidgets('ignores stale image dimensions after thumbnail URL changes', (
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

      final staleCallback = tester
          .widget<VineCachedImage>(find.byType(VineCachedImage))
          .onImageDimensionsResolved!;

      final nextVideo = createTestVideoEvent(
        id: 'test-next',
        thumbnailUrl: 'https://example.com/thumb-next.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: nextVideo,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      staleCallback(640, 360);
      await tester.pump();

      expect(_thumbnailAspectRatio(tester), equals(2 / 3));
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

    testWidgets(
      'resolves aspect ratio via the Image.network path for Divine thumbnails',
      (tester) async {
        final divineHostedVideo = createTestVideoEvent(
          id: 'test-divine-dims',
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

        expect(_thumbnailAspectRatio(tester), equals(2 / 3));

        // The Image.network path has no built-in dimension callback, so it
        // wraps the image in an ImageWithDimensionsListener to recover the
        // aspect ratio from the displayed image.
        final listener = tester.widget<ImageWithDimensionsListener>(
          find.byType(ImageWithDimensionsListener),
        );
        listener.onImageDimensionsResolved!(640, 360);
        await tester.pump();

        expect(_thumbnailAspectRatio(tester), equals(640 / 360));
      },
    );

    testWidgets(
      'ImageWithDimensionsListener reports decoded image dimensions',
      (
        tester,
      ) async {
        final image = _syncImage(640, 360);
        addTearDown(image.dispose);

        int? width;
        int? height;
        await tester.pumpWidget(
          MaterialApp(
            home: ImageWithDimensionsListener(
              imageProvider: _SyncImageProvider(image),
              onImageDimensionsResolved: (w, h) {
                width = w;
                height = h;
              },
              child: const SizedBox.shrink(),
            ),
          ),
        );

        expect(width, equals(640));
        expect(height, equals(360));
      },
    );

    testWidgets(
      'ImageWithDimensionsListener defers synchronous parent state updates',
      (tester) async {
        final image = _syncImage(640, 360);
        addTearDown(image.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: _DimensionCallbackParent(
              imageProvider: _SyncImageProvider(image),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('640x360'), findsOneWidget);
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

class _DimensionCallbackParent extends StatefulWidget {
  const _DimensionCallbackParent({required this.imageProvider});

  final ImageProvider<Object> imageProvider;

  @override
  State<_DimensionCallbackParent> createState() =>
      _DimensionCallbackParentState();
}

class _DimensionCallbackParentState extends State<_DimensionCallbackParent> {
  int? _width;
  int? _height;

  @override
  Widget build(BuildContext context) {
    return ImageWithDimensionsListener(
      imageProvider: widget.imageProvider,
      onImageDimensionsResolved: (width, height) {
        setState(() {
          _width = width;
          _height = height;
        });
      },
      child: Text('${_width ?? 0}x${_height ?? 0}'),
    );
  }
}

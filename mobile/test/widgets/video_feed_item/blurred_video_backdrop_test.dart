import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

void main() {
  group(BlurredVideoBackdrop, () {
    const testUrl = 'https://example.com/poster.jpg';
    const testBlurhash = 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4';

    Widget buildWidget({String url = testUrl, String? blurhash}) {
      return WidgetsApp(
        color: const Color(0xFF000000),
        builder: (_, _) => SizedBox(
          width: 400,
          height: 800,
          child: BlurredVideoBackdrop(url: url, blurhash: blurhash),
        ),
      );
    }

    testWidgets('renders $ClipRect wrapping $ImageFiltered', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(ClipRect), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets(
      'renders $BlurhashDisplay without any blur pass when a blurhash '
      'is available',
      (tester) async {
        await tester.pumpWidget(buildWidget(blurhash: testBlurhash));

        final display = tester.widget<BlurhashDisplay>(
          find.byType(BlurhashDisplay),
        );
        expect(display.blurhash, equals(testBlurhash));
        expect(display.opacity, equals(0.5));
        // The runtime-blur fallback (and its saveLayers) must not mount.
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.byType(Opacity), findsNothing);
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets(
      'falls back to the runtime blur when blurhash is empty',
      (tester) async {
        await tester.pumpWidget(buildWidget(blurhash: ''));

        expect(find.byType(BlurhashDisplay), findsNothing);
        expect(find.byType(ImageFiltered), findsOneWidget);
      },
    );

    testWidgets(
      'renders the blurhash path without any poster url',
      (tester) async {
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFF000000),
            builder: (_, _) => const SizedBox(
              width: 400,
              height: 800,
              child: BlurredVideoBackdrop(blurhash: testBlurhash),
            ),
          ),
        );

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets(
      'renders empty when neither blurhash nor url is available',
      (tester) async {
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFF000000),
            builder: (_, _) => const SizedBox(
              width: 400,
              height: 800,
              child: BlurredVideoBackdrop(),
            ),
          ),
        );

        expect(find.byType(BlurhashDisplay), findsNothing);
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets('passes url to $VineCachedImage', (tester) async {
      await tester.pumpWidget(buildWidget());

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      expect(image.imageUrl, equals(testUrl));
    });

    testWidgets('uses $BoxFit cover with half opacity', (tester) async {
      await tester.pumpWidget(buildWidget());

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      expect(image.fit, equals(BoxFit.cover));
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, equals(0.5));
    });

    testWidgets('errorWidget renders $SizedBox shrink when image fails', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      final fallback = image.errorWidget!(
        tester.element(find.byType(VineCachedImage)),
        'https://example.com/fallback.jpg',
        Exception('load error'),
      );

      expect(fallback, isA<SizedBox>());
      final box = fallback as SizedBox;
      expect(box.width, equals(0));
      expect(box.height, equals(0));
    });
  });
}

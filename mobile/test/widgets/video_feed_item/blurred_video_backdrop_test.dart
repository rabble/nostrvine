import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

void main() {
  group(BlurredVideoBackdrop, () {
    const testUrl = 'https://example.com/poster.jpg';

    Widget buildWidget({String url = testUrl}) {
      return WidgetsApp(
        color: const Color(0xFF000000),
        builder: (_, _) => SizedBox(
          width: 400,
          height: 800,
          child: BlurredVideoBackdrop(url: url),
        ),
      );
    }

    testWidgets('renders $ClipRect wrapping $ImageFiltered', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(ClipRect), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

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

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';

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

    testWidgets('passes url to network image provider', (tester) async {
      await tester.pumpWidget(buildWidget());

      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as NetworkImage;
      expect(provider.url, equals(testUrl));
    });

    testWidgets('uses $BoxFit cover', (tester) async {
      await tester.pumpWidget(buildWidget());

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, equals(BoxFit.cover));
    });

    testWidgets('errorBuilder renders $SizedBox shrink when image fails', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final image = tester.widget<Image>(find.byType(Image));
      final fallback = image.errorBuilder!(
        tester.element(find.byType(Image)),
        Exception('load error'),
        StackTrace.current,
      );

      expect(fallback, isA<SizedBox>());
      final box = fallback as SizedBox;
      expect(box.width, equals(0));
      expect(box.height, equals(0));
    });
  });
}

// ABOUTME: Router tests for category gallery routes.
// ABOUTME: Prevents category detail URLs from falling back to the home route.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/category_gallery_screen.dart';

void main() {
  group('Category gallery routes', () {
    test('buildRoute preserves category gallery URLs', () {
      final location = CategoryGalleryScreen.locationFor('animals');

      expect(buildRoute(parseRoute(location)), location);
    });

    test('parseRoute treats category gallery as its own route type', () {
      final context = parseRoute(CategoryGalleryScreen.locationFor('animals'));

      expect(context.type, RouteType.categoryGallery);
      expect(context.categoryName, 'animals');
      expect(context.videoIndex, isNull);
    });

    test(
      'tabIndexFromLocation hides bottom nav for category gallery routes',
      () {
        expect(
          tabIndexFromLocation(CategoryGalleryScreen.locationFor('animals')),
          -1,
        );
      },
    );
  });
}

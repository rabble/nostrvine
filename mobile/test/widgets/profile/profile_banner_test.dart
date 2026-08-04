// ABOUTME: Tests for the standalone profile banner media widget
// ABOUTME: Verifies banner image fallback behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

void main() {
  group(ProfileBanner, () {
    testWidgets('image load error renders the profile color fallback', (
      tester,
    ) async {
      const profileColor = Color(0xFF33CCBF);

      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: ProfileBanner(
              bannerUrl: 'https://cdn.example.com/missing-banner.jpg',
              profileColor: profileColor,
              height: 334,
            ),
          ),
        ),
      );

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      final imageContext = tester.element(find.byType(VineCachedImage));
      final fallback = image.errorWidget!(
        imageContext,
        image.imageUrl,
        Exception('load failed'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(body: fallback),
        ),
      );

      final fallbackFinder = find.byKey(
        const ValueKey('profile_banner_fallback'),
      );
      expect(fallbackFinder, findsOneWidget);
      expect(tester.getSize(fallbackFinder).height, 334);

      final container = tester.widget<Container>(fallbackFinder);
      final decoration = container.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, equals([profileColor, profileColor]));
    });
  });
}

// ABOUTME: Widget test for AuthHeroSection text rendering
// ABOUTME: Verifies that the hero tagline text renders correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';

void main() {
  group('AuthHeroSection', () {
    testWidgets('renders hero tagline text correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AuthHeroSection())),
      );

      // Verify hero tagline text
      expect(find.text('Authentic moments.'), findsOneWidget);
      expect(find.text('Human creativity.'), findsOneWidget);
    });

    testWidgets('uses BricolageGrotesque font family', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AuthHeroSection())),
      );

      final greenText = tester.widget<Text>(find.text('Authentic moments.'));
      expect(greenText.style?.fontFamily, equals('BricolageGrotesque'));
      expect(greenText.style?.fontWeight, equals(FontWeight.w800));

      final whiteText = tester.widget<Text>(find.text('Human creativity.'));
      expect(whiteText.style?.fontFamily, equals('BricolageGrotesque'));
      expect(whiteText.style?.fontWeight, equals(FontWeight.w800));
    });
  });
}

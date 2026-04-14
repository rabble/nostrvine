// ABOUTME: Tests for AuthHeroSection widget
// ABOUTME: Verifies hero text, sticker images, and logo rendering

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';

void main() {
  group(AuthHeroSection, () {
    Widget createTestWidget() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: const Scaffold(
          body: SingleChildScrollView(child: AuthHeroSection()),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays "Authentic moments." text', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Authentic moments.'), findsOneWidget);
      });

      testWidgets('displays "Human creativity." text', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Human creativity.'), findsOneWidget);
      });

      testWidgets('uses vineGreen color for "Authentic moments."', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        final text = tester.widget<Text>(find.text('Authentic moments.'));
        expect(text.style?.color, equals(VineTheme.vineGreen));
      });

      testWidgets('uses whiteText color for "Human creativity."', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        final text = tester.widget<Text>(find.text('Human creativity.'));
        expect(text.style?.color, equals(VineTheme.whiteText));
      });

      testWidgets('displays logo and sticker SVGs', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // 4 sticker SVGs + 1 logo SVG = 5 total
        expect(find.byType(SvgPicture), findsNWidgets(5));
      });
    });
  });
}

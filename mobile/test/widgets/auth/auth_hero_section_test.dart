// ABOUTME: Tests for AuthHeroSection widget
// ABOUTME: Verifies hero text, sticker images, and the Divine wordmark logo

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/auth/auth_hero_section.dart';

/// The current Divine logotype: the geometric wordmark with the heart-shaped V.
const _logoAssetPath = 'assets/icon/logo.svg';

/// Asset paths of every [SvgPicture] currently mounted.
List<String> _svgAssetNames(WidgetTester tester) => tester
    .widgetList<SvgPicture>(find.byType(SvgPicture))
    .map((picture) => picture.bytesLoader)
    .whereType<SvgAssetLoader>()
    .map((loader) => loader.assetName)
    .toList();

void main() {
  group(AuthHeroSection, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

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
      testWidgets('displays the "authentic moments" tagline', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text(l10n.authHeroTaglineAuthentic), findsOneWidget);
      });

      testWidgets('displays the "human creativity" tagline', (tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text(l10n.authHeroTaglineHuman), findsOneWidget);
      });

      testWidgets('uses vineGreen color for the "authentic" tagline', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        final text = tester.widget<Text>(
          find.text(l10n.authHeroTaglineAuthentic),
        );
        expect(text.style?.color, equals(VineTheme.vineGreen));
      });

      testWidgets('uses whiteText color for the "creativity" tagline', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        final text = tester.widget<Text>(find.text(l10n.authHeroTaglineHuman));
        expect(text.style?.color, equals(VineTheme.whiteText));
      });

      testWidgets('displays logo and sticker SVGs', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // 4 sticker SVGs + 1 logo SVG = 5 total
        expect(find.byType(SvgPicture), findsNWidgets(5));
      });
    });

    // Divine has two logotypes that are easy to confuse: the current geometric
    // heart-V wordmark (`logo.svg`) and the retired cursive script kept in the
    // `assets/icon/` brand pack ("White on black.svg", "White cropped.png", …).
    // #6290 shipped a retired file to the download watermark because nothing
    // pinned which asset was used. This group is the equivalent guard for the
    // sign-in hero — the first brand surface a new user ever sees (#6282).
    group('brand mark', () {
      testWidgets('renders the current wordmark, not a retired brand asset', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());

        expect(_svgAssetNames(tester), contains(_logoAssetPath));
      });

      testWidgets('announces the brand name to screen readers', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(createTestWidget());

        expect(
          find.bySemanticsLabel(l10n.authHeroLogoSemanticLabel),
          findsOneWidget,
        );

        semantics.dispose();
      });
    });

    // Guards the asset itself rather than the call site, so a swap of
    // `logo.svg`'s *contents* is caught as well as a swap of the path. Mirrors
    // the invariant checks in `watermark_image_generator_test.dart`. Relative
    // paths resolve because `flutter test` runs with `mobile/` as its CWD.
    group('$_logoAssetPath asset', () {
      late String svg;

      setUpAll(() {
        svg = File(_logoAssetPath).readAsStringSync();
      });

      test('has the geometric wordmark aspect ratio', () {
        const expectedAspectRatio = 125 / 33;

        final viewBox = RegExp(
          r'viewBox="\s*[\d.-]+\s+[\d.-]+\s+([\d.]+)\s+([\d.]+)\s*"',
        ).firstMatch(svg);
        expect(viewBox, isNotNull, reason: 'logo.svg must declare a viewBox');

        final width = double.parse(viewBox!.group(1)!);
        final height = double.parse(viewBox.group(2)!);

        // The retired cursive wordmark files are ~2.02:1 — far outside this
        // tolerance — so a swap to one of them fails here.
        expect(
          width / height,
          closeTo(expectedAspectRatio, expectedAspectRatio * 0.02),
        );
      });

      test('is filled with the brand green', () {
        final rgb = VineTheme.vineGreen.toARGB32() & 0xFFFFFF;
        final brandGreen =
            '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

        final fills = RegExp(
          'fill="(#[0-9A-Fa-f]{6})"',
        ).allMatches(svg).map((match) => match.group(1)!.toUpperCase()).toSet();

        // The retired pack ships black / white / ivory variants, none of which
        // is the brand green, so a swap fails here too.
        expect(fills, equals({brandGreen}));
      });
    });
  });
}

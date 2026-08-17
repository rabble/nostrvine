import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = TextStyle(fontSize: 16);

  group('divineGreenHeart', () {
    test('is U+1F49A', () {
      expect(divineGreenHeart, '\u{1F49A}');
      expect(divineGreenHeart.runes.single, 0x1F49A);
    });
  });

  group('divineHeartSpans', () {
    test('returns a single text span when the text has no green heart', () {
      final spans = divineHeartSpans('plain text', style: style);

      expect(spans, hasLength(1));
      expect(spans.single, isA<TextSpan>());
      expect((spans.single as TextSpan).text, 'plain text');
      expect((spans.single as TextSpan).style, style);
    });

    test('returns a single text span for empty text', () {
      final spans = divineHeartSpans('', style: style);

      expect(spans, hasLength(1));
      expect((spans.single as TextSpan).text, '');
    });

    test('replaces a lone green heart with a widget span', () {
      final spans = divineHeartSpans(divineGreenHeart, style: style);

      expect(spans, hasLength(1));
      expect(spans.single, isA<WidgetSpan>());
    });

    test('keeps the surrounding text around a green heart', () {
      final spans = divineHeartSpans(
        'love $divineGreenHeart you',
        style: style,
      );

      expect(spans, hasLength(3));
      expect((spans[0] as TextSpan).text, 'love ');
      expect(spans[1], isA<WidgetSpan>());
      expect((spans[2] as TextSpan).text, ' you');
    });

    test('replaces every occurrence', () {
      final spans = divineHeartSpans(
        '$divineGreenHeart$divineGreenHeart',
        style: style,
      );

      expect(spans, hasLength(2));
      expect(spans.every((s) => s is WidgetSpan), isTrue);
    });

    test('leaves other heart emoji untouched', () {
      final spans = divineHeartSpans('❤️ and \u{1F499}', style: style);

      expect(spans, hasLength(1));
      expect(spans.single, isA<TextSpan>());
    });

    test('does not emit empty text spans at the edges', () {
      final spans = divineHeartSpans('$divineGreenHeart!', style: style);

      expect(spans, hasLength(2));
      expect(spans[0], isA<WidgetSpan>());
      expect((spans[1] as TextSpan).text, '!');
    });

    testWidgets('paints the heart in the Divine brand green', (tester) async {
      final spans = divineHeartSpans(divineGreenHeart, style: style);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Text.rich(TextSpan(children: spans))),
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.icon, DivineIconName.heartFill);
      expect(icon.color, VineTheme.vineGreen);
    });

    testWidgets('sizes the heart from the run font size', (tester) async {
      final spans = divineHeartSpans(
        divineGreenHeart,
        style: const TextStyle(fontSize: 20),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Text.rich(TextSpan(children: spans))),
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.size, 20 * kDivineHeartFontScale);
    });

    testWidgets('falls back to a default size when the style has none', (
      tester,
    ) async {
      final spans = divineHeartSpans(
        divineGreenHeart,
        style: const TextStyle(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Text.rich(TextSpan(children: spans))),
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.size, kDivineHeartFallbackFontSize * kDivineHeartFontScale);
    });

    testWidgets('grows the heart with the text scaler', (tester) async {
      // A WidgetSpan child is laid out at its intrinsic size, so the scaler
      // that doubles the surrounding run does not reach the glyph on its own.
      // Without scaling here the heart shrinks to a dot beside large text.
      final spans = divineHeartSpans(
        divineGreenHeart,
        style: const TextStyle(fontSize: 16),
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            home: Scaffold(body: Text.rich(TextSpan(children: spans))),
          ),
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.size, 16 * 2 * kDivineHeartFontScale);
    });

    testWidgets('keeps the heart readable to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final spans = divineHeartSpans(divineGreenHeart, style: style);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Text.rich(TextSpan(children: spans))),
        ),
      );

      expect(
        find.bySemanticsLabel(divineGreenHeart),
        findsOneWidget,
        reason: 'the swapped glyph must still announce as a green heart',
      );
      handle.dispose();
    });
  });
}

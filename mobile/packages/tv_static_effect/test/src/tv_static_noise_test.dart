import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tv_static_effect/tv_static_effect.dart';

class _MockCustomPainter extends Mock implements CustomPainter {}

class _FakeCustomPainter extends Fake implements CustomPainter {}

class _FakeCanvas extends Fake implements Canvas {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCustomPainter());
    registerFallbackValue(_FakeCanvas());
    registerFallbackValue(Size.zero);
  });

  group(TvStaticNoise, () {
    late _MockCustomPainter mockPainter;

    setUp(() {
      mockPainter = _MockCustomPainter();

      when(() => mockPainter.shouldRepaint(any())).thenReturn(false);
      when(() => mockPainter.paint(any(), any())).thenReturn(null);
      when(() => mockPainter.semanticsBuilder).thenReturn(null);
      when(() => mockPainter.addListener(any())).thenReturn(null);
      when(() => mockPainter.removeListener(any())).thenReturn(null);
    });

    ShaderLoader createTestLoader() {
      return () async =>
          ({required double time, required double opacity}) => mockPainter;
    }

    group('renders', () {
      testWidgets('$SizedBox before shader is loaded', (tester) async {
        final completer = Completer<PainterFactory>();

        await tester.pumpWidget(
          TvStaticNoise(shaderLoader: () => completer.future),
        );

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(CustomPaint), findsNothing);

        // Complete and remove widget to avoid pending timer issues.
        completer.complete(
          ({required double time, required double opacity}) => mockPainter,
        );
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('$CustomPaint after shader is loaded', (tester) async {
        await tester.pumpWidget(
          TvStaticNoise(shaderLoader: createTestLoader()),
        );
        await tester.pump();

        expect(find.byType(CustomPaint), findsOneWidget);
        expect(find.byType(ColoredBox), findsNothing);
      });
    });

    testWidgets('uses default opacity of 0.07', (tester) async {
      await tester.pumpWidget(
        TvStaticNoise(shaderLoader: createTestLoader()),
      );
      await tester.pump();

      final widget = tester.widget<TvStaticNoise>(
        find.byType(TvStaticNoise),
      );
      expect(widget.opacity, equals(0.07));
    });

    testWidgets('uses custom opacity', (tester) async {
      await tester.pumpWidget(
        TvStaticNoise(
          opacity: 0.5,
          shaderLoader: createTestLoader(),
        ),
      );
      await tester.pump();

      final widget = tester.widget<TvStaticNoise>(
        find.byType(TvStaticNoise),
      );
      expect(widget.opacity, equals(0.5));
    });

    testWidgets('ticker triggers rebuilds', (tester) async {
      await tester.pumpWidget(
        TvStaticNoise(shaderLoader: createTestLoader()),
      );
      await tester.pump();

      // Advance the ticker to trigger _onTick and rebuild.
      await tester.pump(const Duration(seconds: 1));

      // The widget should still render CustomPaint after ticker updates.
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets(
      'does not call setState when disposed before shader loads',
      (tester) async {
        final completer = Completer<PainterFactory>();

        await tester.pumpWidget(
          TvStaticNoise(shaderLoader: () => completer.future),
        );

        // Remove the widget before the shader loads.
        await tester.pumpWidget(const SizedBox());

        // Complete the loader after disposal.
        completer.complete(
          ({required double time, required double opacity}) => mockPainter,
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('disposes ticker on widget removal', (tester) async {
      await tester.pumpWidget(
        TvStaticNoise(shaderLoader: createTestLoader()),
      );
      await tester.pump();

      // Remove the widget — should dispose without errors.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}

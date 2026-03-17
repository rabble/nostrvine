import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(DivineSlider, () {
    Widget buildSlider({
      double value = 0.5,
      ValueChanged<double>? onChanged,
      double min = 0,
      double max = 1,
      double trackHeight = 8,
      double thumbWidth = 4,
      double thumbHeight = 32,
      Color activeColor = VineTheme.primary,
      Color inactiveColor = VineTheme.onSurfaceDisabled,
      Color thumbColor = VineTheme.onSurface,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: DivineSlider(
                value: value,
                onChanged: onChanged,
                min: min,
                max: max,
                trackHeight: trackHeight,
                thumbWidth: thumbWidth,
                thumbHeight: thumbHeight,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                thumbColor: thumbColor,
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('$DivineSlider with default properties', (tester) async {
        await tester.pumpWidget(buildSlider());

        expect(find.byType(DivineSlider), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);
      });

      testWidgets('applies active and inactive colors via $SliderTheme', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSlider(
            activeColor: Colors.red,
            inactiveColor: Colors.blue,
          ),
        );

        final sliderTheme = tester.widget<SliderTheme>(
          find.byType(SliderTheme),
        );

        expect(sliderTheme.data.activeTrackColor, equals(Colors.red));
        expect(sliderTheme.data.inactiveTrackColor, equals(Colors.blue));
      });

      testWidgets('applies thumb color via $SliderTheme', (tester) async {
        await tester.pumpWidget(
          buildSlider(thumbColor: Colors.green),
        );

        final sliderTheme = tester.widget<SliderTheme>(
          find.byType(SliderTheme),
        );

        expect(sliderTheme.data.thumbColor, equals(Colors.green));
      });

      testWidgets('at value 0 (fully left)', (tester) async {
        await tester.pumpWidget(buildSlider(value: 0));

        expect(find.byType(DivineSlider), findsOneWidget);
      });

      testWidgets('at value 1 (fully right)', (tester) async {
        await tester.pumpWidget(buildSlider(value: 1));

        expect(find.byType(DivineSlider), findsOneWidget);
      });

      testWidgets('uses $SliderTheme for styling', (tester) async {
        await tester.pumpWidget(buildSlider());

        expect(find.byType(SliderTheme), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onChanged on tap', (tester) async {
        double? changedValue;

        await tester.pumpWidget(
          buildSlider(onChanged: (v) => changedValue = v),
        );

        final sliderFinder = find.byType(Slider);
        final sliderSize = tester.getSize(sliderFinder);
        final sliderTopLeft = tester.getTopLeft(sliderFinder);

        // Tap at 75% of the slider width
        await tester.tapAt(
          Offset(
            sliderTopLeft.dx + sliderSize.width * 0.75,
            sliderTopLeft.dy + sliderSize.height / 2,
          ),
        );
        await tester.pump();

        expect(changedValue, isNotNull);
        expect(changedValue, closeTo(0.75, 0.05));
      });

      testWidgets('calls onChanged on horizontal drag', (tester) async {
        final values = <double>[];

        await tester.pumpWidget(
          buildSlider(onChanged: values.add),
        );

        await tester.drag(
          find.byType(Slider),
          const Offset(50, 0),
        );
        await tester.pump();

        expect(values, isNotEmpty);
      });

      testWidgets('does not call onChanged when disabled', (tester) async {
        var wasCalled = false;

        await tester.pumpWidget(
          buildSlider(onChanged: (_) => wasCalled = true),
        );

        // Rebuild with onChanged set to null (disabled)
        await tester.pumpWidget(buildSlider());

        await tester.tap(find.byType(Slider));
        await tester.pump();

        expect(wasCalled, isFalse);
      });
    });

    group('custom range', () {
      testWidgets('works with custom min/max', (tester) async {
        double? changedValue;

        await tester.pumpWidget(
          buildSlider(
            value: 50,
            max: 100,
            onChanged: (v) => changedValue = v,
          ),
        );

        final sliderFinder = find.byType(Slider);
        final topLeft = tester.getTopLeft(sliderFinder);
        final size = tester.getSize(sliderFinder);

        // Tap at ~75%
        await tester.tapAt(
          Offset(
            topLeft.dx + size.width * 0.75,
            topLeft.dy + size.height / 2,
          ),
        );
        await tester.pump();

        expect(changedValue, isNotNull);
        expect(changedValue, closeTo(75, 5));
      });

      testWidgets('handles min equal to max', (tester) async {
        await tester.pumpWidget(
          buildSlider(value: 5, min: 5, max: 5),
        );

        expect(find.byType(DivineSlider), findsOneWidget);
      });

      testWidgets('clamps value to valid range', (tester) async {
        await tester.pumpWidget(
          buildSlider(value: 2),
        );

        final slider = tester.widget<Slider>(find.byType(Slider));
        expect(slider.value, equals(1));
      });
    });

    group('slider theme configuration', () {
      testWidgets('uses custom track height', (tester) async {
        await tester.pumpWidget(buildSlider(trackHeight: 12));

        final sliderTheme = tester.widget<SliderTheme>(
          find.byType(SliderTheme),
        );

        expect(sliderTheme.data.trackHeight, equals(12));
      });

      testWidgets('disables overlay', (tester) async {
        await tester.pumpWidget(buildSlider());

        final sliderTheme = tester.widget<SliderTheme>(
          find.byType(SliderTheme),
        );

        expect(
          sliderTheme.data.overlayShape,
          equals(SliderComponentShape.noOverlay),
        );
      });

      testWidgets('hides value indicator', (tester) async {
        await tester.pumpWidget(buildSlider());

        final sliderTheme = tester.widget<SliderTheme>(
          find.byType(SliderTheme),
        );

        expect(
          sliderTheme.data.showValueIndicator,
          equals(ShowValueIndicator.never),
        );
      });
    });
  });
}

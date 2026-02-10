import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineSpriteCheckbox', () {
    Widget buildTestWidget({
      DivineCheckboxState state = DivineCheckboxState.unselected,
      Duration animationDuration = const Duration(milliseconds: 100),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: DivineSpriteCheckbox(
              state: state,
              animationDuration: animationDuration,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders SVG sprite', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(DivineSpriteCheckbox), findsOneWidget);
      });

      testWidgets('has correct viewport size 24x24', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // The SizedBox clips the sprite to 24x24 viewport
        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(DivineSpriteCheckbox),
            matching: find.byType(SizedBox).first,
          ),
        );

        expect(sizedBox.width, 24);
        expect(sizedBox.height, 24);
      });
    });

    group('states', () {
      testWidgets('renders unselected state', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });

      testWidgets('renders selected state', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(state: DivineCheckboxState.selected),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });

      testWidgets('renders intermediate state', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(state: DivineCheckboxState.intermediate),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });

      testWidgets('renders disabled state with reduced opacity', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(state: DivineCheckboxState.disabled),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.5);
      });
    });

    group('animation', () {
      testWidgets('uses provided animation duration', (tester) async {
        const customDuration = Duration(milliseconds: 200);
        await tester.pumpWidget(
          buildTestWidget(animationDuration: customDuration),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.duration, customDuration);
      });
    });
  });

  group('DivineCheckbox', () {
    Widget buildTestWidget({
      DivineCheckboxState state = DivineCheckboxState.unselected,
      Widget label = const Text('Test label'),
      CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
      Duration animationDuration = const Duration(milliseconds: 100),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: DivineCheckbox(
              state: state,
              label: label,
              crossAxisAlignment: crossAxisAlignment,
              animationDuration: animationDuration,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders sprite checkbox and label', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(DivineSpriteCheckbox), findsOneWidget);
        expect(find.text('Test label'), findsOneWidget);
      });

      testWidgets('renders with custom label widget', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(label: const Icon(Icons.star)),
        );

        expect(find.byType(DivineSpriteCheckbox), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
      });
    });

    group('layout', () {
      testWidgets('uses center alignment by default', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.crossAxisAlignment, CrossAxisAlignment.center);
      });

      testWidgets('uses custom crossAxisAlignment', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(crossAxisAlignment: CrossAxisAlignment.start),
        );

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.crossAxisAlignment, CrossAxisAlignment.start);
      });
    });

    group('states', () {
      testWidgets('passes state to sprite checkbox', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(state: DivineCheckboxState.selected),
        );

        final spriteCheckbox = tester.widget<DivineSpriteCheckbox>(
          find.byType(DivineSpriteCheckbox),
        );
        expect(spriteCheckbox.state, DivineCheckboxState.selected);
      });
    });

    group('animation', () {
      testWidgets('passes animation duration to sprite checkbox', (
        tester,
      ) async {
        const customDuration = Duration(milliseconds: 200);
        await tester.pumpWidget(
          buildTestWidget(animationDuration: customDuration),
        );

        final spriteCheckbox = tester.widget<DivineSpriteCheckbox>(
          find.byType(DivineSpriteCheckbox),
        );
        expect(spriteCheckbox.animationDuration, customDuration);
      });
    });
  });

  group('DivineRowCheckbox', () {
    Widget buildTestWidget({
      required ValueChanged<bool> onChanged,
      DivineCheckboxState state = DivineCheckboxState.unselected,
      Widget label = const Text('Test label'),
      CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
      Duration animationDuration = const Duration(milliseconds: 100),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: DivineRowCheckbox(
              state: state,
              onChanged: onChanged,
              label: label,
              crossAxisAlignment: crossAxisAlignment,
              animationDuration: animationDuration,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders checkbox with border', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onChanged: (_) {}),
        );

        expect(find.byType(DivineCheckbox), findsOneWidget);
        expect(find.byType(AnimatedContainer), findsOneWidget);
      });

      testWidgets('renders with label', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onChanged: (_) {}),
        );

        expect(find.text('Test label'), findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets('calls onChanged with true when tapping unselected', (
        tester,
      ) async {
        bool? newValue;
        await tester.pumpWidget(
          buildTestWidget(
            onChanged: (value) => newValue = value,
          ),
        );

        await tester.tap(find.byType(DivineRowCheckbox));
        await tester.pumpAndSettle();

        expect(newValue, isTrue);
      });

      testWidgets('calls onChanged with false when tapping selected', (
        tester,
      ) async {
        bool? newValue;
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.selected,
            onChanged: (value) => newValue = value,
          ),
        );

        await tester.tap(find.byType(DivineRowCheckbox));
        await tester.pumpAndSettle();

        expect(newValue, isFalse);
      });

      testWidgets('calls onChanged with false when tapping intermediate', (
        tester,
      ) async {
        bool? newValue;
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.intermediate,
            onChanged: (value) => newValue = value,
          ),
        );

        await tester.tap(find.byType(DivineRowCheckbox));
        await tester.pumpAndSettle();

        expect(newValue, isFalse);
      });
    });

    group('border styling', () {
      testWidgets('has muted border when unselected', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onChanged: (_) {},
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final boxDecoration = container.decoration! as BoxDecoration;
        expect(boxDecoration.border!.top.color, VineTheme.outlineMuted);
      });

      testWidgets('has primary border when selected', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.selected,
            onChanged: (_) {},
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final boxDecoration = container.decoration! as BoxDecoration;
        expect(boxDecoration.border!.top.color, VineTheme.primary);
      });

      testWidgets('has primary border when intermediate', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.intermediate,
            onChanged: (_) {},
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final boxDecoration = container.decoration! as BoxDecoration;
        expect(boxDecoration.border!.top.color, VineTheme.primary);
      });
    });

    group('layout', () {
      testWidgets('passes crossAxisAlignment to checkbox', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            crossAxisAlignment: CrossAxisAlignment.start,
            onChanged: (_) {},
          ),
        );

        final checkbox = tester.widget<DivineCheckbox>(
          find.byType(DivineCheckbox),
        );
        expect(checkbox.crossAxisAlignment, CrossAxisAlignment.start);
      });
    });

    group('animation', () {
      testWidgets('passes animation duration to checkbox', (tester) async {
        const customDuration = Duration(milliseconds: 200);
        await tester.pumpWidget(
          buildTestWidget(
            animationDuration: customDuration,
            onChanged: (_) {},
          ),
        );

        final checkbox = tester.widget<DivineCheckbox>(
          find.byType(DivineCheckbox),
        );
        expect(checkbox.animationDuration, customDuration);
      });

      testWidgets('passes animation duration to container', (tester) async {
        const customDuration = Duration(milliseconds: 200);
        await tester.pumpWidget(
          buildTestWidget(
            animationDuration: customDuration,
            onChanged: (_) {},
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(container.duration, customDuration);
      });
    });
  });
}

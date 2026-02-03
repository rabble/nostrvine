import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiVineAppBarIconButton', () {
    Widget buildTestWidget({
      required IconSource icon,
      VoidCallback? onPressed,
      String? tooltip,
      String? semanticLabel,
      Color? backgroundColor,
      Color? iconColor,
      double size = 48,
      double iconSize = 32,
      double borderRadius = 20,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: DiVineAppBarIconButton(
              icon: icon,
              onPressed: onPressed,
              tooltip: tooltip,
              semanticLabel: semanticLabel,
              backgroundColor: backgroundColor,
              iconColor: iconColor,
              size: size,
              iconSize: iconSize,
              borderRadius: borderRadius,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders with Material icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
          ),
        );

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('renders with SVG icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const SvgIconSource('assets/icon/CaretLeft.svg'),
          ),
        );

        expect(find.byType(SvgPicture), findsOneWidget);
      });

      testWidgets('renders container with correct size', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            size: 56,
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final constraints = container.constraints;

        expect(constraints?.maxWidth, 56);
        expect(constraints?.maxHeight, 56);
      });

      testWidgets('renders icon with correct size', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            iconSize: 40,
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, 40);
      });
    });

    group('styling', () {
      testWidgets('uses default background color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration?;

        expect(decoration?.color, VineTheme.iconButtonBackground);
      });

      testWidgets('uses custom background color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            backgroundColor: Colors.red,
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration?;

        expect(decoration?.color, Colors.red);
      });

      testWidgets('uses default icon color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, Colors.white);
      });

      testWidgets('uses custom icon color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            iconColor: Colors.blue,
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, Colors.blue);
      });

      testWidgets('applies border radius', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            borderRadius: 16,
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration?;

        expect(
          decoration?.borderRadius,
          BorderRadius.circular(16),
        );
      });
    });

    group('interaction', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            onPressed: () => pressed = true,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        expect(pressed, isTrue);
      });

      testWidgets('does not throw when onPressed is null and tapped', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
          ),
        );

        await tester.tap(find.byType(GestureDetector));

        expect(tester.takeException(), isNull);
      });
    });

    group('tooltip', () {
      testWidgets('renders tooltip when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            tooltip: 'Go back',
          ),
        );

        expect(find.byType(Tooltip), findsOneWidget);
      });

      testWidgets('does not render tooltip when not provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
          ),
        );

        expect(find.byType(Tooltip), findsNothing);
      });

      testWidgets('tooltip has correct message', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            tooltip: 'Custom tooltip',
          ),
        );

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, 'Custom tooltip');
      });
    });

    group('accessibility', () {
      Finder findButtonSemantics() {
        return find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.button ?? false),
        );
      }

      testWidgets('has Semantics wrapper with button property', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            semanticLabel: 'Back button',
          ),
        );

        expect(findButtonSemantics(), findsOneWidget);
      });

      testWidgets('Semantics enabled when onPressed is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            onPressed: () {},
          ),
        );

        final semantics = tester.widget<Semantics>(findButtonSemantics());
        expect(semantics.properties.enabled, isTrue);
      });

      testWidgets('Semantics disabled when onPressed is null', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
          ),
        );

        final semantics = tester.widget<Semantics>(findButtonSemantics());
        expect(semantics.properties.enabled, isFalse);
      });

      testWidgets('Semantics has correct label', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            semanticLabel: 'Custom label',
          ),
        );

        final semantics = tester.widget<Semantics>(findButtonSemantics());
        expect(semantics.properties.label, 'Custom label');
      });
    });

    group('SVG icon rendering', () {
      testWidgets('SVG icon uses correct color filter', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const SvgIconSource('assets/icon/CaretLeft.svg'),
            iconColor: Colors.red,
          ),
        );

        final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(
          svgPicture.colorFilter,
          const ColorFilter.mode(Colors.red, BlendMode.srcIn),
        );
      });

      testWidgets('SVG icon is wrapped in SizedBox with correct size', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const SvgIconSource('assets/icon/CaretLeft.svg'),
            iconSize: 24,
          ),
        );

        final sizedBoxes = tester
            .widgetList<SizedBox>(find.byType(SizedBox))
            .toList();
        final iconSizedBox = sizedBoxes.firstWhere(
          (box) => box.width == 24 && box.height == 24,
          orElse: () => throw StateError('No SizedBox with size 24 found'),
        );

        expect(iconSizedBox.width, 24);
        expect(iconSizedBox.height, 24);
      });
    });
  });
}

// ABOUTME: Tests for VineBottomSheetHeader and VineBottomSheetBadge
// ABOUTME: Verifies header rendering and structure

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VineBottomSheetHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(title: Text('Test Title')),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('renders with trailing widget', (tester) async {
      const trailingWidget = Icon(Icons.settings, key: Key('trailing'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              trailing: trailingWidget,
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });

    testWidgets('uses default padding when none is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(title: Text('Test Title')),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(VineBottomSheetHeader),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        padding.padding,
        const EdgeInsetsDirectional.only(start: 16, end: 16, top: 8),
      );
    });

    testWidgets('applies custom padding when provided', (tester) async {
      const customPadding = EdgeInsetsDirectional.only(
        start: 12,
        end: 12,
        top: 4,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              padding: customPadding,
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(VineBottomSheetHeader),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(padding.padding, customPadding);
    });
    testWidgets('renders with leading widget', (tester) async {
      const leadingWidget = Icon(Icons.close, key: Key('leading'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              leading: leadingWidget,
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byKey(const Key('leading')), findsOneWidget);
    });

    testWidgets('renders leading action with a trailing placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: const Text('Test Title'),
              leadingAction: DivineIconButton(
                key: const Key('leading_action'),
                icon: DivineIconName.x,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('leading_action')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(VineBottomSheetHeader),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox && widget.width == 40 && widget.height == 40,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(VineBottomSheetHeader),
          matching: find.byWidgetPredicate(
            (widget) => widget is IgnorePointer || widget is Opacity,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('renders trailing action with a leading placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: const Text('Test Title'),
              trailingAction: DivineIconButton(
                key: const Key('trailing_action'),
                icon: DivineIconName.check,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('trailing_action')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(VineBottomSheetHeader),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox && widget.width == 40 && widget.height == 40,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(VineBottomSheetHeader),
          matching: find.byWidgetPredicate(
            (widget) => widget is IgnorePointer || widget is Opacity,
          ),
        ),
        findsNothing,
      );
    });
  });
}

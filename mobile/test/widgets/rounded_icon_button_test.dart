// ABOUTME: Tests for RoundedIconButton widget
// ABOUTME: Verifies icon rendering, tap callback, and null onPressed

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';

void main() {
  group(RoundedIconButton, () {
    Widget createTestWidget({
      VoidCallback? onPressed,
      Widget icon = const Icon(Icons.chevron_left),
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: RoundedIconButton(onPressed: onPressed, icon: icon),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays the icon', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            onPressed: () {},
            icon: const Icon(Icons.info_outline),
          ),
        );

        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('renders $GestureDetector', (tester) async {
        await tester.pumpWidget(createTestWidget(onPressed: () {}));

        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('renders a 48x48 container', (tester) async {
        await tester.pumpWidget(createTestWidget(onPressed: () {}));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, equals(48));
        expect(container.constraints?.maxHeight, equals(48));
      });
    });

    group('interactions', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          createTestWidget(onPressed: () => tapped = true),
        );

        await tester.tap(find.byType(GestureDetector));
        expect(tapped, isTrue);
      });

      testWidgets('does not throw when onPressed is null', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Should not throw when tapped with null onPressed
        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
      });
    });
  });
}

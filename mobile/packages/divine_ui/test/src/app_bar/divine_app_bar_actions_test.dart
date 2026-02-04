import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiVineAppBarAction', () {
    test('creates with required parameters', () {
      final action = DiVineAppBarAction(
        icon: const MaterialIconSource(Icons.search),
        onPressed: () {},
      );

      expect(action.icon, isA<MaterialIconSource>());
      expect(action.onPressed, isNotNull);
      expect(action.tooltip, isNull);
      expect(action.semanticLabel, isNull);
      expect(action.backgroundColor, isNull);
      expect(action.iconColor, isNull);
    });

    test('creates with all parameters', () {
      final action = DiVineAppBarAction(
        icon: const MaterialIconSource(Icons.search),
        onPressed: () {},
        tooltip: 'Search',
        semanticLabel: 'Search button',
        backgroundColor: Colors.red,
        iconColor: Colors.blue,
      );

      expect(action.tooltip, 'Search');
      expect(action.semanticLabel, 'Search button');
      expect(action.backgroundColor, Colors.red);
      expect(action.iconColor, Colors.blue);
    });
  });

  group('DiVineAppBarActions', () {
    Widget buildTestWidget({
      required List<DiVineAppBarAction> actions,
      DiVineAppBarStyle style = DiVineAppBarStyle.defaultStyle,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: DiVineAppBarActions(
            actions: actions,
            style: style,
          ),
        ),
      );
    }

    testWidgets('renders nothing when actions list is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget(actions: []));

      expect(find.byType(DiVineAppBarIconButton), findsNothing);
    });

    testWidgets('renders action buttons', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          actions: [
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.search),
              onPressed: () {},
            ),
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.settings),
              onPressed: () {},
            ),
          ],
        ),
      );

      expect(find.byType(DiVineAppBarIconButton), findsNWidgets(2));
    });

    testWidgets('calls onPressed when action is tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestWidget(
          actions: [
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.search),
              onPressed: () => tapped = true,
            ),
          ],
        ),
      );

      await tester.tap(find.byType(DiVineAppBarIconButton));
      expect(tapped, isTrue);
    });

    testWidgets('uses style for spacing', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          actions: [
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.search),
              onPressed: () {},
            ),
            DiVineAppBarAction(
              icon: const MaterialIconSource(Icons.settings),
              onPressed: () {},
            ),
          ],
          style: const DiVineAppBarStyle(actionButtonSpacing: 16),
        ),
      );

      // Find the SizedBox used for spacing between buttons
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final spacer = sizedBoxes.firstWhere(
        (box) => box.width == 16,
        orElse: () => throw StateError('Spacer not found'),
      );
      expect(spacer.width, 16);
    });
  });
}

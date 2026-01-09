// ABOUTME: Tests for VineBottomSheet component
// ABOUTME: Verifies structure and behavior of the bottom sheet

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet_header.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  group('VineBottomSheet', () {
    testWidgets('renders with required props', (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: 'Test Sheet',
              scrollController: scrollController,
              children: const [Text('Content 1'), Text('Content 2')],
            ),
          ),
        ),
      );

      // Verify header with title (which includes the drag handle)
      expect(find.byType(VineBottomSheetHeader), findsOneWidget);
      expect(find.text('Test Sheet'), findsOneWidget);

      // Verify content is rendered
      expect(find.text('Content 1'), findsOneWidget);
      expect(find.text('Content 2'), findsOneWidget);
    });

    testWidgets('renders with trailing widget', (tester) async {
      final scrollController = ScrollController();
      const trailingWidget = Icon(Icons.settings, key: Key('trailing'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: 'Test Sheet',
              scrollController: scrollController,
              trailing: trailingWidget,
              children: const [Text('Content')],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });

    testWidgets('renders with bottom input', (tester) async {
      final scrollController = ScrollController();
      const inputWidget = TextField(
        key: Key('input'),
        decoration: InputDecoration(hintText: 'Add comment...'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: 'Test Sheet',
              scrollController: scrollController,
              bottomInput: inputWidget,
              children: const [Text('Content')],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('input')), findsOneWidget);
    });

    testWidgets('content is scrollable', (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: 'Test Sheet',
              scrollController: scrollController,
              children: List.generate(
                50,
                (index) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Item $index'),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify first item is visible
      expect(find.text('Item 0'), findsOneWidget);

      // Last item should not be visible initially
      expect(find.text('Item 49'), findsNothing);

      // Scroll to bottom
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      // Now last item should be visible
      expect(find.text('Item 49'), findsOneWidget);
    });

    group('VineBottomSheet.show', () {
      testWidgets('shows modal bottom sheet', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    VineBottomSheet.show(
                      context: context,
                      title: 'Modal Sheet',
                      children: const [Text('Modal Content')],
                    );
                  },
                  child: const Text('Show Sheet'),
                ),
              ),
            ),
          ),
        );

        // Tap to show sheet
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        // Verify sheet is shown
        expect(find.text('Modal Sheet'), findsOneWidget);
        expect(find.text('Modal Content'), findsOneWidget);
      });
    });
  });
}

// ABOUTME: Tests for VineBottomSheet component
// ABOUTME: Verifies structure and behavior of the bottom sheet

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VineBottomSheet', () {
    testWidgets('renders with required props', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              body: Column(
                children: [Text('Content 1'), Text('Content 2')],
              ),
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
      const trailingWidget = Icon(Icons.settings, key: Key('trailing'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              trailing: trailingWidget,
              body: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });

    testWidgets('renders with bottom input', (tester) async {
      const inputWidget = TextField(
        key: Key('input'),
        decoration: InputDecoration(hintText: 'Add comment...'),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              bottomInput: inputWidget,
              body: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('input')), findsOneWidget);
    });

    testWidgets('content is scrollable when expanded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: const Text('Test Sheet'),
              body: ListView(
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

    testWidgets('wraps content when expanded is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              title: Text('Test Sheet'),
              expanded: false,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Item 1'), Text('Item 2')],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('renders fixed mode with scrollable false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              title: Text('Fixed Sheet'),
              children: [Text('Fixed Content')],
            ),
          ),
        ),
      );

      expect(find.text('Fixed Sheet'), findsOneWidget);
      expect(find.text('Fixed Content'), findsOneWidget);
    });

    testWidgets('renders contentTitle in fixed mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              contentTitle: 'Content Title',
              children: [Text('Content')],
            ),
          ),
        ),
      );

      expect(find.text('Content Title'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('renders contentTitle in scrollable mode', (tester) async {
      final scrollController = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              contentTitle: 'Scrollable Title',
              scrollController: scrollController,
              children: const [Text('Scrollable Content')],
            ),
          ),
        ),
      );

      expect(find.text('Scrollable Title'), findsOneWidget);
      expect(find.text('Scrollable Content'), findsOneWidget);
    });

    testWidgets('renders bottomInput in fixed mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheet(
              scrollable: false,
              bottomInput: TextField(key: Key('fixed-input')),
              children: [Text('Content')],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('fixed-input')), findsOneWidget);
    });

    group('VineBottomSheet.show', () {
      testWidgets('shows modal bottom sheet', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Modal Sheet'),
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

      testWidgets('shows fixed mode sheet with scrollable false', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      title: const Text('Fixed Modal'),
                      children: const [Text('Fixed Modal Content')],
                    );
                  },
                  child: const Text('Show Fixed Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Fixed Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Fixed Modal'), findsOneWidget);
        expect(find.text('Fixed Modal Content'), findsOneWidget);
      });

      testWidgets('calls onShow callback when showing sheet', (tester) async {
        var onShowCalled = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      title: const Text('Callback Sheet'),
                      onShow: () => onShowCalled = true,
                      children: const [Text('Content')],
                    );
                  },
                  child: const Text('Show Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(onShowCalled, isTrue);
      });

      testWidgets('shows sheet with body parameter', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await VineBottomSheet.show<void>(
                      context: context,
                      scrollable: false,
                      body: const Text('Body Content'),
                    );
                  },
                  child: const Text('Show Body Sheet'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Body Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Body Content'), findsOneWidget);
      });
    });
  });
}

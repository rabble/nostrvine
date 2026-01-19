// ABOUTME: Tests for VineBottomSheetSelectionMenu component
// ABOUTME: Verifies modal behavior and selection return values

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VineBottomSheetSelectionMenu', () {
    const testOptions = [
      VineBottomSheetSelectionOptionData(label: 'New', value: 'latest'),
      VineBottomSheetSelectionOptionData(label: 'Popular', value: 'popular'),
      VineBottomSheetSelectionOptionData(label: 'Following', value: 'home'),
    ];

    testWidgets('renders all options without title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetSelectionMenu(
              options: testOptions,
            ),
          ),
        ),
      );

      expect(find.text('New'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('renders title when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetSelectionMenu(
              title: Text('Feed Mode'),
              options: testOptions,
            ),
          ),
        ),
      );

      expect(find.text('Feed Mode'), findsOneWidget);
    });

    testWidgets('shows checkmark for selected option', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetSelectionMenu(
              options: testOptions,
              selectedValue: 'popular',
            ),
          ),
        ),
      );

      // Should show one checkmark for the selected option
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows no checkmark when nothing selected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetSelectionMenu(
              options: testOptions,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsNothing);
    });

    group('VineBottomSheetSelectionMenu.show', () {
      testWidgets('shows modal and returns selected value', (tester) async {
        String? selectedValue;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    selectedValue = await VineBottomSheetSelectionMenu.show(
                      context: context,
                      options: testOptions,
                      selectedValue: 'latest',
                    );
                  },
                  child: const Text('Show Menu'),
                ),
              ),
            ),
          ),
        );

        // Open the menu
        await tester.tap(find.text('Show Menu'));
        await tester.pumpAndSettle();

        // Verify menu is shown
        expect(find.text('New'), findsOneWidget);

        // Tap an option
        await tester.tap(find.text('Popular'));
        await tester.pumpAndSettle();

        // Verify the selected value is returned
        expect(selectedValue, 'popular');
      });

      testWidgets('returns null when dismissed', (tester) async {
        String? selectedValue = 'initial';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    selectedValue = await VineBottomSheetSelectionMenu.show(
                      context: context,
                      options: testOptions,
                    );
                  },
                  child: const Text('Show Menu'),
                ),
              ),
            ),
          ),
        );

        // Open the menu
        await tester.tap(find.text('Show Menu'));
        await tester.pumpAndSettle();

        // Dismiss by tapping outside (the barrier)
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Verify null is returned
        expect(selectedValue, isNull);
      });
    });
  });

  group('VineBottomSheetSelectionOptionData', () {
    test('creates with required parameters', () {
      const data = VineBottomSheetSelectionOptionData(
        label: 'Test',
        value: 'test_value',
      );

      expect(data.label, 'Test');
      expect(data.value, 'test_value');
    });
  });
}

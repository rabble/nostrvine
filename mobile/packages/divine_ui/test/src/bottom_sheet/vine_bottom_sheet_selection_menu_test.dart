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

    testWidgets('shows all options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetSelectionMenu.show(
                  context: context,
                  options: testOptions,
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.text('New'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('shows title when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetSelectionMenu.show(
                  context: context,
                  options: testOptions,
                  title: const Text('Feed Mode'),
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Feed Mode'), findsOneWidget);
    });

    testWidgets('shows checkmark for selected option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetSelectionMenu.show(
                  context: context,
                  options: testOptions,
                  selectedValue: 'popular',
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows no checkmark when nothing selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetSelectionMenu.show(
                  context: context,
                  options: testOptions,
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('returns selected value when option tapped', (tester) async {
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

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Popular'));
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      // Dismiss by tapping outside (the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(selectedValue, isNull);
    });
  });

  group('VineBottomSheetSelectionOptionData', () {
    test('creates with required parameters', () {
      // Use non-const to ensure constructor coverage instrumentation.
      // ignore: prefer_const_constructors
      final data = VineBottomSheetSelectionOptionData(
        label: 'Test',
        value: 'test_value',
      );

      expect(data.label, 'Test');
      expect(data.value, 'test_value');
    });
  });
}

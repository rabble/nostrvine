// ABOUTME: Test file for CharacterCounterWidget UI and visual feedback
// ABOUTME: Verifies character counting display and color-coded warnings

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/widgets/character_counter_widget.dart';

void main() {
  group('CharacterCounterWidget', () {
    testWidgets('displays basic counter correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterCounterWidget(
              current: 0,
              max: 100,
            ),
          ),
        ),
      );

      expect(find.text('0/100'), findsOneWidget);
    });

    testWidgets('shows grey color when under threshold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterCounterWidget(
              current: 50,
              max: 100,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('50/100'));
      expect(textWidget.style?.color, equals(Colors.grey));
    });

    testWidgets('shows orange color and warning icon when near limit', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterCounterWidget(
              current: 85,
              max: 100,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('85/100'));
      expect(textWidget.style?.color, equals(Colors.orange));
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('shows red color and error icon when over limit', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterCounterWidget(
              current: 110,
              max: 100,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('110/100'));
      expect(textWidget.style?.color, equals(Colors.red));
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('respects custom warning threshold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterCounterWidget(
              current: 60,
              max: 100,
              warningThreshold: 50,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('60/100'));
      expect(textWidget.style?.color, equals(Colors.orange));
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('applies custom text style', (WidgetTester tester) async {
      const customStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
      
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterCounterWidget(
              current: 50,
              max: 100,
              style: customStyle,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('50/100'));
      expect(textWidget.style?.fontSize, equals(16));
      expect(textWidget.style?.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('shows no icon when under warning threshold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterCounterWidget(
              current: 50,
              max: 100,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.warning), findsNothing);
      expect(find.byIcon(Icons.error), findsNothing);
    });

    testWidgets('handles zero values correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterCounterWidget(
              current: 0,
              max: 10, // Non-zero max to avoid threshold issues
            ),
          ),
        ),
      );

      expect(find.text('0/10'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text('0/10'));
      expect(textWidget.style?.color, equals(Colors.grey));
    });
  });
}
// ABOUTME: Tests for VineBottomSheetHeader and VineBottomSheetBadge
// ABOUTME: Verifies header layout, typography, and badge appearance

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet_header.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  group('VineBottomSheetHeader', () {
    testWidgets('renders title with correct style', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VineBottomSheetHeader(title: 'Test Title')),
        ),
      );

      final titleText = tester.widget<Text>(find.text('Test Title'));
      expect(titleText.style?.fontSize, 24);
      expect(titleText.style?.fontWeight, FontWeight.w700);
      expect(titleText.style?.color, VineTheme.onSurface);
    });

    testWidgets('renders without trailing widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VineBottomSheetHeader(title: 'Test Title')),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      // Should only have title, no trailing widget
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('renders with trailing widget', (tester) async {
      const trailingWidget = Icon(Icons.star, key: Key('trailing'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: 'Test Title',
              trailing: trailingWidget,
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byKey(const Key('trailing')), findsOneWidget);
    });

    testWidgets('has correct padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VineBottomSheetHeader(title: 'Test Title')),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      );
    });

    testWidgets('trailing widget has fixed width', (tester) async {
      const trailingWidget = Icon(Icons.star, key: Key('trailing'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: 'Test Title',
              trailing: trailingWidget,
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byKey(const Key('trailing')),
          matching: find.byType(SizedBox),
        ),
      );

      expect(sizedBox.width, 62);
    });

    testWidgets('uses space between for layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: 'Test Title',
              trailing: Icon(Icons.star),
            ),
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.mainAxisAlignment, MainAxisAlignment.spaceBetween);
    });
  });

  group('VineBottomSheetBadge', () {
    testWidgets('renders text correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VineBottomSheetBadge(text: '3 new')),
        ),
      );

      expect(find.text('3 new'), findsOneWidget);
    });

    testWidgets('has correct background color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VineBottomSheetBadge(text: '3 new')),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, VineTheme.tabIndicatorGreen);
    });

    testWidgets('has correct border radius', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VineBottomSheetBadge(text: '3 new')),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('has correct height and padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VineBottomSheetBadge(text: '3 new')),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxHeight, 26);
      expect(container.padding, const EdgeInsets.symmetric(horizontal: 10));
    });

    testWidgets('text has correct style', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VineBottomSheetBadge(text: '3 new')),
        ),
      );

      final text = tester.widget<Text>(find.text('3 new'));
      expect(text.style?.fontSize, 14);
      expect(text.style?.fontWeight, FontWeight.w800);
      expect(text.style?.color, Colors.white);
    });
  });
}

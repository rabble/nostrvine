// ABOUTME: Tests for VineBottomSheetDragHandle component
// ABOUTME: Verifies appearance and dimensions match Figma specs

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet_drag_handle.dart';

void main() {
  group('VineBottomSheetDragHandle', () {
    testWidgets('renders with correct dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VineBottomSheetDragHandle())),
      );

      // Find the inner container (the actual handle)
      final handleContainer = tester.widget<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color ==
                  VineTheme.onSurfaceMuted,
        ),
      );

      // Verify dimensions match Figma specs (48px wide, 5px height)
      expect(handleContainer.constraints?.maxWidth, 48);
      final size = tester.getSize(find.byWidget(handleContainer));
      expect(size.width, 48);
      expect(size.height, 5);
    });

    testWidgets('has correct color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VineBottomSheetDragHandle())),
      );

      final handleContainer = tester.widget<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color ==
                  VineTheme.onSurfaceMuted,
        ),
      );

      final decoration = handleContainer.decoration! as BoxDecoration;
      expect(decoration.color, VineTheme.onSurfaceMuted);
    });

    testWidgets('has correct border radius', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VineBottomSheetDragHandle())),
      );

      final handleContainer = tester.widget<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color ==
                  VineTheme.onSurfaceMuted,
        ),
      );

      final decoration = handleContainer.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(100));
    });

    testWidgets('is centered horizontally', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VineBottomSheetDragHandle())),
      );

      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('has correct padding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VineBottomSheetDragHandle())),
      );

      final outerContainer = tester.widget<Container>(
        find.byType(Container).first,
      );

      expect(outerContainer.padding, const EdgeInsets.only(top: 8, bottom: 12));
    });
  });
}

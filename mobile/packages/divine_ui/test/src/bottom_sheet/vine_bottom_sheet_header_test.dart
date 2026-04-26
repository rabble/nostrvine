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
        const EdgeInsetsDirectional.only(start: 24, end: 24, top: 8),
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
  });
}

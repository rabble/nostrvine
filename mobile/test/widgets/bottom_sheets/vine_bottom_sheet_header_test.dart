// ABOUTME: Tests for VineBottomSheetHeader and VineBottomSheetBadge
// ABOUTME: Verifies header rendering and structure

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet_header.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

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
  });
}

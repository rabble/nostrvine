// ABOUTME: Tests for VineBottomSheetDragHandle component
// ABOUTME: Verifies the drag handle renders and is centered

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet_drag_handle.dart';

void main() {
  group('VineBottomSheetDragHandle', () {
    testWidgets('renders and is centered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VineBottomSheetDragHandle())),
      );

      // Verify it renders
      expect(find.byType(VineBottomSheetDragHandle), findsOneWidget);

      // Verify it's centered
      expect(find.byType(Center), findsOneWidget);

      // Verify the structure (Center contains Container)
      final center = tester.widget<Center>(find.byType(Center));
      expect(center.child, isA<Container>());
    });
  });
}

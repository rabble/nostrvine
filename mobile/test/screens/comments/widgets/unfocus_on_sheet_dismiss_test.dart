// ABOUTME: Verifies UnfocusOnSheetDismiss drops the keyboard when the sheet
// ABOUTME: starts closing, so iOS does not strand an orphaned keyboard (#5604).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/comments/widgets/unfocus_on_sheet_dismiss.dart';

void main() {
  group(UnfocusOnSheetDismiss, () {
    testWidgets(
      'unfocuses the active field when the enclosing sheet starts dismissing',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => UnfocusOnSheetDismiss(
                        child: TextField(focusNode: focusNode, autofocus: true),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // The comment field is focused and the keyboard connection is open.
        expect(focusNode.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        // Dismiss the sheet. The route's transition reverses immediately —
        // the signal UnfocusOnSheetDismiss reacts to — while the field is
        // still mounted and focused.
        Navigator.of(tester.element(find.byType(UnfocusOnSheetDismiss))).pop();
        await tester.pump();

        // Unfocus fired at dismiss-initiation (before teardown), so the
        // text-input connection is closed rather than left orphaned (#5604).
        expect(focusNode.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);

        await tester.pumpAndSettle();
      },
    );

    testWidgets('renders its child unchanged', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UnfocusOnSheetDismiss(child: Text('hello'))),
      );

      expect(find.text('hello'), findsOneWidget);
    });
  });
}

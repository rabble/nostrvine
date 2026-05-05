// ABOUTME: Tests for the delete account confirmation dialog
// ABOUTME: Verifies that the DELETE confirmation is case-insensitive and trims whitespace

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';

/// Minimal router wrapper so [context.pop()] works inside the dialog.
Widget _wrapWithRouter(Widget child) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, state) => child)],
  );
  return MaterialApp.router(routerConfig: router);
}

Future<void> _showDialog(WidgetTester tester, {VoidCallback? onConfirm}) async {
  await tester.pumpWidget(
    _wrapWithRouter(
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const Key('open'),
            onPressed: () => showDeleteAllContentWarningDialog(
              context: context,
              onConfirm: onConfirm ?? () {},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  group('showDeleteAllContentWarningDialog – confirmation input', () {
    testWidgets('empty string keeps Delete button disabled', (tester) async {
      await _showDialog(tester);

      // Button should be disabled (onPressed == null → tapping does nothing)
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('wrong word keeps Delete button disabled', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'confirm');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('exact uppercase DELETE enables the button', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('lowercase delete enables the button', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('mixed case Delete enables the button', (tester) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'Delete');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('DELETE with trailing whitespace enables the button', (
      tester,
    ) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), 'DELETE ');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('delete with leading whitespace enables the button', (
      tester,
    ) async {
      await _showDialog(tester);

      await tester.enterText(find.byType(TextField), ' delete');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('tapping enabled button calls onConfirm', (tester) async {
      var called = false;
      await _showDialog(tester, onConfirm: () => called = true);

      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pump();

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Delete All Content'),
      );
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });
  });
}

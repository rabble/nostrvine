// Testing deprecated DivineTextField wrapper.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(DivineTextField, () {
    testWidgets('delegates to $DivineAuthTextField', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineTextField(label: 'Email'),
          ),
        ),
      );

      expect(
        find.byType(DivineAuthTextField),
        findsOneWidget,
      );
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('forwards all properties to $DivineAuthTextField', (
      tester,
    ) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            body: DivineTextField(
              label: 'Password',
              controller: controller,
              focusNode: focusNode,
              obscureText: true,
              enabled: false,
            ),
          ),
        ),
      );

      final authField = tester.widget<DivineAuthTextField>(
        find.byType(DivineAuthTextField),
      );
      expect(authField.label, equals('Password'));
      expect(authField.controller, equals(controller));
      expect(authField.focusNode, equals(focusNode));
      expect(authField.obscureText, isTrue);
      expect(authField.enabled, isFalse);

      focusNode.dispose();
      controller.dispose();
    });
  });
}

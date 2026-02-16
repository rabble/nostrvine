import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineTextField', () {
    Widget buildTestWidget({
      String label = 'Test Label',
      TextEditingController? controller,
      FocusNode? focusNode,
      bool readOnly = false,
      bool obscureText = false,
      bool enabled = true,
      TextInputType? keyboardType,
      TextInputAction? textInputAction,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmitted,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: DivineTextField(
            label: label,
            controller: controller,
            focusNode: focusNode,
            readOnly: readOnly,
            obscureText: obscureText,
            enabled: enabled,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('renders with label text', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Username'));

      expect(find.text('Username'), findsOneWidget);
    });

    testWidgets('renders with container styling', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Find the container with the surfaceContainer background
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, equals(VineTheme.surfaceContainer));
      expect(decoration?.borderRadius, equals(BorderRadius.circular(24)));
    });

    testWidgets('accepts text input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildTestWidget(controller: controller));

      await tester.enterText(find.byType(TextField), 'Hello World');
      expect(controller.text, equals('Hello World'));
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      String? changedValue;
      await tester.pumpWidget(
        buildTestWidget(onChanged: (value) => changedValue = value),
      );

      await tester.enterText(find.byType(TextField), 'Test');
      expect(changedValue, equals('Test'));
    });

    testWidgets('calls onSubmitted when submitted', (tester) async {
      String? submittedValue;
      await tester.pumpWidget(
        buildTestWidget(onSubmitted: (value) => submittedValue = value),
      );

      await tester.enterText(find.byType(TextField), 'Submit Test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submittedValue, equals('Submit Test'));
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTestWidget(onTap: () => tapped = true));

      await tester.tap(find.byType(TextField));
      expect(tapped, isTrue);
    });

    testWidgets('respects readOnly property', (tester) async {
      final controller = TextEditingController(text: 'Initial');
      await tester.pumpWidget(
        buildTestWidget(controller: controller, readOnly: true),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.readOnly, isTrue);
    });

    testWidgets('respects enabled property', (tester) async {
      await tester.pumpWidget(buildTestWidget(enabled: false));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('respects obscureText for passwords', (tester) async {
      await tester.pumpWidget(buildTestWidget(obscureText: true));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('shows visibility toggle when obscureText is true', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(obscureText: true));

      // Should find an eye icon
      expect(find.byType(DivineIcon), findsOneWidget);
    });

    testWidgets('toggles password visibility when eye icon tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(obscureText: true));

      // Initially obscured
      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);

      // Tap the eye icon
      await tester.tap(find.byType(DivineIcon));
      await tester.pump();

      // Now should be visible
      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isFalse);
    });

    testWidgets('does not show visibility toggle when obscureText is false', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('respects keyboardType property', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(keyboardType: TextInputType.emailAddress),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, equals(TextInputType.emailAddress));
    });

    testWidgets('respects textInputAction property', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(textInputAction: TextInputAction.search),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textInputAction, equals(TextInputAction.search));
    });

    testWidgets('uses focus node when provided', (tester) async {
      final focusNode = FocusNode();
      await tester.pumpWidget(buildTestWidget(focusNode: focusNode));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode, equals(focusNode));

      focusNode.dispose();
    });

    testWidgets('uses controller when provided', (tester) async {
      final controller = TextEditingController(text: 'Initial Value');
      await tester.pumpWidget(buildTestWidget(controller: controller));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller, equals(controller));
      expect(controller.text, equals('Initial Value'));

      controller.dispose();
    });

    testWidgets('uses asterisk as obscuring character', (tester) async {
      await tester.pumpWidget(buildTestWidget(obscureText: true));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscuringCharacter, equals('✱'));
    });

    group('didUpdateWidget', () {
      testWidgets('updates when focusNode changes', (tester) async {
        final focusNode1 = FocusNode();
        final focusNode2 = FocusNode();

        await tester.pumpWidget(buildTestWidget(focusNode: focusNode1));

        var textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.focusNode, equals(focusNode1));

        await tester.pumpWidget(buildTestWidget(focusNode: focusNode2));
        await tester.pump();

        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.focusNode, equals(focusNode2));

        focusNode1.dispose();
        focusNode2.dispose();
      });

      testWidgets('updates when controller changes', (tester) async {
        final controller1 = TextEditingController(text: 'First');
        final controller2 = TextEditingController(text: 'Second');

        await tester.pumpWidget(buildTestWidget(controller: controller1));

        var textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller, equals(controller1));

        await tester.pumpWidget(buildTestWidget(controller: controller2));
        await tester.pump();

        textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller, equals(controller2));

        controller1.dispose();
        controller2.dispose();
      });
    });

    testWidgets('label floats when text is entered', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildTestWidget(controller: controller));

      // Enter text
      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();

      // Label should now be floating (visible in different position/style)
      expect(find.text('Test Label'), findsOneWidget);
    });
  });
}

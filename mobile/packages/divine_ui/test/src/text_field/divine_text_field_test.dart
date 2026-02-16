import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(DivineTextField, () {
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

    group('renders', () {
      testWidgets('renders with label text', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(label: 'Username'),
        );

        expect(find.text('Username'), findsOneWidget);
      });

      testWidgets('renders with container styling', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());

        final container = tester.widget<Container>(
          find.ancestor(
            of: find.byType(TextField),
            matching: find.byType(Container),
          ),
        );
        final decoration = container.decoration as BoxDecoration?;
        expect(
          decoration?.color,
          equals(VineTheme.surfaceContainer),
        );
        expect(
          decoration?.borderRadius,
          equals(BorderRadius.circular(24)),
        );
      });

      testWidgets(
        'renders visibility toggle when obscureText is true',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(obscureText: true),
          );

          expect(find.byType(DivineIcon), findsOneWidget);
        },
      );

      testWidgets(
        'does not render visibility toggle '
        'when obscureText is false',
        (tester) async {
          await tester.pumpWidget(buildTestWidget());

          expect(find.byType(DivineIcon), findsNothing);
        },
      );

      testWidgets('uses asterisk as obscuring character', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(obscureText: true),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(
          textField.obscuringCharacter,
          equals('✱'),
        );
      });

      testWidgets('label floats when text is entered', (
        tester,
      ) async {
        final controller = TextEditingController();
        await tester.pumpWidget(
          buildTestWidget(controller: controller),
        );

        await tester.enterText(
          find.byType(TextField),
          'Test',
        );
        await tester.pump();

        expect(find.text('Test Label'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('accepts text input', (tester) async {
        final controller = TextEditingController();
        await tester.pumpWidget(
          buildTestWidget(controller: controller),
        );

        await tester.enterText(
          find.byType(TextField),
          'Hello World',
        );
        expect(controller.text, equals('Hello World'));
      });

      testWidgets('calls onChanged when text changes', (
        tester,
      ) async {
        String? changedValue;
        await tester.pumpWidget(
          buildTestWidget(
            onChanged: (value) => changedValue = value,
          ),
        );

        await tester.enterText(
          find.byType(TextField),
          'Test',
        );
        expect(changedValue, equals('Test'));
      });

      testWidgets('calls onSubmitted when submitted', (
        tester,
      ) async {
        String? submittedValue;
        await tester.pumpWidget(
          buildTestWidget(
            onSubmitted: (value) => submittedValue = value,
          ),
        );

        await tester.enterText(
          find.byType(TextField),
          'Submit Test',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(submittedValue, equals('Submit Test'));
      });

      testWidgets('calls onTap when tapped', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          buildTestWidget(onTap: () => tapped = true),
        );

        await tester.tap(find.byType(DivineTextField));
        await tester.pump();
        expect(tapped, isTrue);
      });

      testWidgets(
        'focuses field when container area is tapped',
        (tester) async {
          final focusNode = FocusNode();
          await tester.pumpWidget(
            buildTestWidget(focusNode: focusNode),
          );

          expect(focusNode.hasFocus, isFalse);

          // Tap the top of the Container (padding area above
          // the TextField) to trigger _handleContainerTap and
          // exercise the requestFocus path.
          final containerFinder = find.byType(Container).first;
          final topLeft = tester.getTopLeft(containerFinder);
          await tester.tapAt(topLeft + const Offset(30, 5));
          await tester.pump();

          expect(focusNode.hasFocus, isTrue);

          focusNode.dispose();
        },
      );

      testWidgets('does not focus when disabled', (
        tester,
      ) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          buildTestWidget(
            focusNode: focusNode,
            enabled: false,
          ),
        );

        await tester.tap(find.byType(DivineTextField));
        await tester.pump();

        expect(focusNode.hasFocus, isFalse);

        focusNode.dispose();
      });

      testWidgets(
        'toggles password visibility when eye icon tapped',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(obscureText: true),
          );

          var textField = tester.widget<TextField>(
            find.byType(TextField),
          );
          expect(textField.obscureText, isTrue);

          await tester.tap(
            find
                .ancestor(
                  of: find.byType(DivineIcon),
                  matching: find.byType(GestureDetector),
                )
                .first,
          );
          await tester.pump();

          textField = tester.widget<TextField>(
            find.byType(TextField),
          );
          expect(textField.obscureText, isFalse);
        },
      );
    });

    group('properties', () {
      testWidgets('respects readOnly property', (
        tester,
      ) async {
        final controller = TextEditingController(text: 'Initial');
        await tester.pumpWidget(
          buildTestWidget(
            controller: controller,
            readOnly: true,
          ),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.readOnly, isTrue);
      });

      testWidgets('respects enabled property', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(enabled: false),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.enabled, isFalse);
      });

      testWidgets('respects obscureText for passwords', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(obscureText: true),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.obscureText, isTrue);
      });

      testWidgets('respects keyboardType property', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            keyboardType: TextInputType.emailAddress,
          ),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(
          textField.keyboardType,
          equals(TextInputType.emailAddress),
        );
      });

      testWidgets('respects textInputAction property', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            textInputAction: TextInputAction.search,
          ),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(
          textField.textInputAction,
          equals(TextInputAction.search),
        );
      });

      testWidgets('uses focus node when provided', (
        tester,
      ) async {
        final focusNode = FocusNode();
        await tester.pumpWidget(
          buildTestWidget(focusNode: focusNode),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.focusNode, equals(focusNode));

        focusNode.dispose();
      });

      testWidgets('uses controller when provided', (
        tester,
      ) async {
        final controller = TextEditingController(text: 'Initial Value');
        await tester.pumpWidget(
          buildTestWidget(controller: controller),
        );

        final textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.controller, equals(controller));
        expect(controller.text, equals('Initial Value'));

        controller.dispose();
      });
    });

    group('accessibility', () {
      testWidgets(
        'visibility toggle has semantic label for obscured',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(obscureText: true),
          );

          expect(
            find.bySemanticsLabel('Show password'),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'visibility toggle has semantic label for visible',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(obscureText: true),
          );

          await tester.tap(
            find
                .ancestor(
                  of: find.byType(DivineIcon),
                  matching: find.byType(GestureDetector),
                )
                .first,
          );
          await tester.pump();

          expect(
            find.bySemanticsLabel('Hide password'),
            findsOneWidget,
          );
        },
      );
    });

    group('didUpdateWidget', () {
      testWidgets('updates when focusNode changes', (
        tester,
      ) async {
        final focusNode1 = FocusNode();
        final focusNode2 = FocusNode();

        await tester.pumpWidget(
          buildTestWidget(focusNode: focusNode1),
        );

        var textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.focusNode, equals(focusNode1));

        await tester.pumpWidget(
          buildTestWidget(focusNode: focusNode2),
        );
        await tester.pump();

        textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.focusNode, equals(focusNode2));

        focusNode1.dispose();
        focusNode2.dispose();
      });

      testWidgets('updates when controller changes', (
        tester,
      ) async {
        final controller1 = TextEditingController(text: 'First');
        final controller2 = TextEditingController(text: 'Second');

        await tester.pumpWidget(
          buildTestWidget(controller: controller1),
        );

        var textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.controller, equals(controller1));

        await tester.pumpWidget(
          buildTestWidget(controller: controller2),
        );
        await tester.pump();

        textField = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(textField.controller, equals(controller2));

        controller1.dispose();
        controller2.dispose();
      });
    });
  });
}

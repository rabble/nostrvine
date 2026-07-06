import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineTextField', () {
    Widget buildTestWidget({
      String? labelText,
      TextEditingController? controller,
      FocusNode? focusNode,
      bool readOnly = false,
      bool obscureText = false,
      bool enabled = true,
      int? maxLength,
      int? minLines,
      int? maxLines,
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
            labelText: labelText,
            controller: controller,
            focusNode: focusNode,
            readOnly: readOnly,
            obscureText: obscureText,
            enabled: enabled,
            maxLength: maxLength,
            minLines: minLines,
            maxLines: maxLines,
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
      await tester.pumpWidget(buildTestWidget(labelText: 'Username'));

      expect(find.text('Username'), findsOneWidget);
    });

    testWidgets('renders without label text', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('accepts text input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(buildTestWidget(controller: controller));

      await tester.enterText(find.byType(TextField), 'Hello World');
      expect(controller.text, 'Hello World');
    });

    testWidgets('calls onChanged when text changes', (tester) async {
      String? changedValue;
      await tester.pumpWidget(
        buildTestWidget(onChanged: (value) => changedValue = value),
      );

      await tester.enterText(find.byType(TextField), 'Test');
      expect(changedValue, 'Test');
    });

    testWidgets('calls onSubmitted when submitted', (tester) async {
      String? submittedValue;
      await tester.pumpWidget(
        buildTestWidget(onSubmitted: (value) => submittedValue = value),
      );

      await tester.enterText(find.byType(TextField), 'Submit Test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submittedValue, 'Submit Test');
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
      await tester.pumpWidget(buildTestWidget(obscureText: true, maxLines: 1));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);
    });

    testWidgets('respects maxLength property', (tester) async {
      await tester.pumpWidget(buildTestWidget(maxLength: 10));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, 10);
    });

    testWidgets('respects minLines and maxLines', (tester) async {
      await tester.pumpWidget(buildTestWidget(minLines: 2, maxLines: 5));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 2);
      expect(textField.maxLines, 5);
    });

    testWidgets('respects keyboardType property', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(keyboardType: TextInputType.emailAddress),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('respects textInputAction property', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(textInputAction: TextInputAction.search),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textInputAction, TextInputAction.search);
    });

    testWidgets('uses focus node when provided', (tester) async {
      final focusNode = FocusNode();
      await tester.pumpWidget(buildTestWidget(focusNode: focusNode));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode, focusNode);

      focusNode.dispose();
    });

    testWidgets('uses controller when provided', (tester) async {
      final controller = TextEditingController(text: 'Initial Value');
      await tester.pumpWidget(buildTestWidget(controller: controller));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller, controller);
      expect(controller.text, 'Initial Value');

      controller.dispose();
    });

    testWidgets('is not filled', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration!.filled, isFalse);
    });

    testWidgets('floating label changes color when focused', (tester) async {
      final focusNode = FocusNode();
      await tester.pumpWidget(
        buildTestWidget(
          labelText: 'Test Label',
          focusNode: focusNode,
        ),
      );

      // Get the floating label style and resolve it for unfocused state
      final textField = tester.widget<TextField>(find.byType(TextField));
      final floatingStyle = textField.decoration!.floatingLabelStyle;
      expect(floatingStyle, isA<WidgetStateTextStyle>());

      final unfocusedStyle = (floatingStyle! as WidgetStateTextStyle).resolve(
        <WidgetState>{},
      );
      expect(unfocusedStyle.color, VineTheme.onSurfaceVariant);

      // Resolve for focused state
      final focusedStyle = (floatingStyle as WidgetStateTextStyle).resolve(
        <WidgetState>{WidgetState.focused},
      );
      expect(focusedStyle.color, VineTheme.primary);

      focusNode.dispose();
    });

    group('primaryWhenFilled', () {
      Widget buildField({
        required TextEditingController controller,
        required bool primaryWhenFilled,
      }) {
        return MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            body: DivineTextField(
              labelText: 'Test Label',
              controller: controller,
              primaryWhenFilled: primaryWhenFilled,
            ),
          ),
        );
      }

      testWidgets(
        'unfocused floating label uses primary color when filled',
        (tester) async {
          final controller = TextEditingController(text: 'has content');
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            buildField(controller: controller, primaryWhenFilled: true),
          );

          final textField = tester.widget<TextField>(find.byType(TextField));
          final floatingStyle =
              textField.decoration!.floatingLabelStyle! as WidgetStateTextStyle;
          final unfocusedStyle = floatingStyle.resolve(<WidgetState>{});

          expect(unfocusedStyle.color, VineTheme.primary);
        },
      );

      testWidgets(
        'unfocused floating label uses variant color when empty',
        (tester) async {
          final controller = TextEditingController();
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            buildField(controller: controller, primaryWhenFilled: true),
          );

          final textField = tester.widget<TextField>(find.byType(TextField));
          final floatingStyle =
              textField.decoration!.floatingLabelStyle! as WidgetStateTextStyle;
          final unfocusedStyle = floatingStyle.resolve(<WidgetState>{});

          expect(unfocusedStyle.color, VineTheme.onSurfaceVariant);
        },
      );

      testWidgets(
        'unfocused floating label uses variant color when filled but '
        'primaryWhenFilled is false',
        (tester) async {
          final controller = TextEditingController(text: 'has content');
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            buildField(controller: controller, primaryWhenFilled: false),
          );

          final textField = tester.widget<TextField>(find.byType(TextField));
          final floatingStyle =
              textField.decoration!.floatingLabelStyle! as WidgetStateTextStyle;
          final unfocusedStyle = floatingStyle.resolve(<WidgetState>{});

          expect(unfocusedStyle.color, VineTheme.onSurfaceVariant);
        },
      );

      testWidgets(
        'defaults to false (no primary color when filled)',
        (tester) async {
          final controller = TextEditingController(text: 'has content');
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              theme: VineTheme.theme,
              home: Scaffold(
                body: DivineTextField(
                  labelText: 'Test Label',
                  controller: controller,
                ),
              ),
            ),
          );

          final textField = tester.widget<TextField>(find.byType(TextField));
          final floatingStyle =
              textField.decoration!.floatingLabelStyle! as WidgetStateTextStyle;
          final unfocusedStyle = floatingStyle.resolve(<WidgetState>{});

          expect(unfocusedStyle.color, VineTheme.onSurfaceVariant);
        },
      );
    });

    group('spellCheckConfiguration', () {
      test('default config is enabled and carries a spell check service', () {
        final config = DivineTextField.defaultSpellCheckConfiguration;

        expect(config, isNot(const SpellCheckConfiguration.disabled()));
        expect(config.spellCheckService, isNotNull);
      });

      testWidgets('enables spell check by default', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: DivineTextField()),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.spellCheckConfiguration,
          DivineTextField.defaultSpellCheckConfiguration,
        );
      });

      testWidgets('passes a provided config through unchanged', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DivineTextField(
                spellCheckConfiguration: SpellCheckConfiguration.disabled(),
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.spellCheckConfiguration,
          const SpellCheckConfiguration.disabled(),
        );
      });
    });

    group('defaultContentPadding', () {
      test('exposes a 16px-all default for overlay alignment', () {
        expect(
          DivineTextField.defaultContentPadding,
          const EdgeInsets.all(16),
        );
      });
    });
  });
}

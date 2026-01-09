// ABOUTME: Tests for VideoEditorMetaInput widget
// ABOUTME: Validates meta input form field behavior and styling

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/meta/video_editor_meta_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorMetaInput Widget Tests', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildTestWidget({
      String label = 'Test Label',
      String placeholder = 'Test Placeholder',
      TextInputType? keyboardType,
      TextInputAction? textInputAction,
      TextCapitalization textCapitalization = TextCapitalization.none,
      int? minLines,
      int? maxLines,
      ValueChanged<String>? onSubmitted,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: VideoEditorMetaInput(
            label: label,
            placeholder: placeholder,
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            minLines: minLines,
            maxLines: maxLines,
            onSubmitted: onSubmitted,
          ),
        ),
      );
    }

    testWidgets('accepts text input', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), 'Test content');
      expect(controller.text, 'Test content');
    });

    testWidgets('clears text when controller is cleared', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextField), 'Test content');
      expect(controller.text, 'Test content');

      controller.clear();
      await tester.pump();
      expect(controller.text, '');
    });

    testWidgets('applies custom keyboard type', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(keyboardType: TextInputType.emailAddress),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('applies custom text input action', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(textInputAction: TextInputAction.done),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textInputAction, TextInputAction.done);
    });

    testWidgets('applies text capitalization', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(textCapitalization: TextCapitalization.words),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textCapitalization, TextCapitalization.words);
    });

    testWidgets('calls onSubmitted when submitted', (tester) async {
      String? submittedText;

      await tester.pumpWidget(
        buildTestWidget(onSubmitted: (text) => submittedText = text),
      );

      await tester.enterText(find.byType(TextField), 'Submitted text');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submittedText, 'Submitted text');
    });

    testWidgets('applies minLines when provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(minLines: 3));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.minLines, 3);
    });

    testWidgets('applies maxLines when provided', (tester) async {
      await tester.pumpWidget(buildTestWidget(maxLines: 5));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, 5);
    });
  });
}

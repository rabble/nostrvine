// ABOUTME: Tests for VideoTextEditorScope InheritedWidget.
// ABOUTME: Validates scope lookup and update notification behavior.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class MockTextEditorState extends Mock implements TextEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'MockTextEditorState';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoTextEditorScope', () {
    late MockTextEditorState mockEditor;

    setUp(() {
      mockEditor = MockTextEditorState();
    });

    Widget buildWidget({
      required TextEditorState editor,
      required Widget child,
    }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: VideoTextEditorScope(editor: editor, child: child),
      );
    }

    group('of', () {
      testWidgets('returns the nearest scope', (tester) async {
        VideoTextEditorScope? foundScope;

        await tester.pumpWidget(
          buildWidget(
            editor: mockEditor,
            child: Builder(
              builder: (context) {
                foundScope = VideoTextEditorScope.of(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(foundScope, isNotNull);
        expect(foundScope!.editor, mockEditor);
      });

      testWidgets('throws assertion when no scope found', (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                // This should throw an assertion error
                expect(
                  () => VideoTextEditorScope.of(context),
                  throwsA(isA<AssertionError>()),
                );
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('maybeOf', () {
      testWidgets('returns the nearest scope when present', (tester) async {
        VideoTextEditorScope? foundScope;

        await tester.pumpWidget(
          buildWidget(
            editor: mockEditor,
            child: Builder(
              builder: (context) {
                foundScope = VideoTextEditorScope.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(foundScope, isNotNull);
        expect(foundScope!.editor, mockEditor);
      });

      testWidgets('returns null when no scope found', (tester) async {
        VideoTextEditorScope? foundScope;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                foundScope = VideoTextEditorScope.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(foundScope, isNull);
      });
    });

    group('updateShouldNotify', () {
      testWidgets('returns true when editor changes', (tester) async {
        final oldEditor = MockTextEditorState();
        final newEditor = MockTextEditorState();

        int buildCount = 0;

        await tester.pumpWidget(
          buildWidget(
            editor: oldEditor,
            child: Builder(
              builder: (context) {
                VideoTextEditorScope.of(context);
                buildCount++;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Update with a new editor
        await tester.pumpWidget(
          buildWidget(
            editor: newEditor,
            child: Builder(
              builder: (context) {
                VideoTextEditorScope.of(context);
                buildCount++;
                return const SizedBox();
              },
            ),
          ),
        );

        // Should rebuild because editor changed
        expect(buildCount, 2);
      });
    });

    group('nested scopes', () {
      testWidgets('inner scope overrides outer scope', (tester) async {
        final outerEditor = MockTextEditorState();
        final innerEditor = MockTextEditorState();

        VideoTextEditorScope? foundScope;

        await tester.pumpWidget(
          buildWidget(
            editor: outerEditor,
            child: VideoTextEditorScope(
              editor: innerEditor,
              child: Builder(
                builder: (context) {
                  foundScope = VideoTextEditorScope.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        expect(foundScope, isNotNull);
        expect(foundScope!.editor, innerEditor);
        expect(foundScope!.editor, isNot(outerEditor));
      });
    });
  });
}

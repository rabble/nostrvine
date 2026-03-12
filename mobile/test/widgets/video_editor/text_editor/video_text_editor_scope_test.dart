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

class MockTextEditorKey extends Mock implements GlobalKey<TextEditorState> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoTextEditorScope', () {
    late MockTextEditorKey mockKey;
    late MockTextEditorState mockEditor;

    setUp(() {
      mockKey = MockTextEditorKey();
      mockEditor = MockTextEditorState();
      when(() => mockKey.currentState).thenReturn(mockEditor);
    });

    Widget buildWidget({
      required GlobalKey<TextEditorState> editorKey,
      required Widget child,
    }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: VideoTextEditorScope(editorKey: editorKey, child: child),
      );
    }

    group('of', () {
      testWidgets('returns the nearest scope', (tester) async {
        VideoTextEditorScope? foundScope;

        await tester.pumpWidget(
          buildWidget(
            editorKey: mockKey,
            child: Builder(
              builder: (context) {
                foundScope = VideoTextEditorScope.of(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(foundScope, isNotNull);
        expect(foundScope!.editorKey, mockKey);
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
            editorKey: mockKey,
            child: Builder(
              builder: (context) {
                foundScope = VideoTextEditorScope.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(foundScope, isNotNull);
        expect(foundScope!.editorKey, mockKey);
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
      testWidgets('returns true when editorKey changes', (tester) async {
        final oldKey = MockTextEditorKey();
        final newKey = MockTextEditorKey();

        int buildCount = 0;

        await tester.pumpWidget(
          buildWidget(
            editorKey: oldKey,
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

        // Update with a new key
        await tester.pumpWidget(
          buildWidget(
            editorKey: newKey,
            child: Builder(
              builder: (context) {
                VideoTextEditorScope.of(context);
                buildCount++;
                return const SizedBox();
              },
            ),
          ),
        );

        // Should rebuild because editorKey changed
        expect(buildCount, 2);
      });
    });

    group('nested scopes', () {
      testWidgets('inner scope overrides outer scope', (tester) async {
        final outerKey = MockTextEditorKey();
        final innerKey = MockTextEditorKey();

        VideoTextEditorScope? foundScope;

        await tester.pumpWidget(
          buildWidget(
            editorKey: outerKey,
            child: VideoTextEditorScope(
              editorKey: innerKey,
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
        expect(foundScope!.editorKey, innerKey);
        expect(foundScope!.editorKey, isNot(outerKey));
      });
    });
  });
}

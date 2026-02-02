// ABOUTME: Tests for VideoEditorDrawOverlayControls widget.
// ABOUTME: Validates top bar buttons (Close, Undo, Redo, Done) and their state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

class MockVideoEditorDrawBloc
    extends MockBloc<VideoEditorDrawEvent, VideoEditorDrawState>
    implements VideoEditorDrawBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorDrawOverlayControls', () {
    late MockVideoEditorDrawBloc mockBloc;

    setUp(() {
      mockBloc = MockVideoEditorDrawBloc();

      when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    Widget buildWidget() {
      return MaterialApp(
        home: Scaffold(
          body: VideoEditorScope(
            editorKey: GlobalKey(),
            onAddStickers: () {},
            child: BlocProvider<VideoEditorDrawBloc>.value(
              value: mockBloc,
              child: const SizedBox(
                width: 400,
                height: 600,
                child: VideoEditorDrawOverlayControls(),
              ),
            ),
          ),
        ),
      );
    }

    group('Close button', () {
      testWidgets('renders with correct semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Close',
          ),
          findsOneWidget,
        );
      });
    });

    group('Undo button', () {
      testWidgets('renders with correct semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
          findsOneWidget,
        );
      });

      testWidgets('is disabled when canUndo is false', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canUndo: false));

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
        );
        expect(semantics.properties.enabled, isFalse);
      });

      testWidgets('is enabled when canUndo is true', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canUndo: true));

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
        );
        expect(semantics.properties.enabled, isTrue);
      });
    });

    group('Redo button', () {
      testWidgets('renders with correct semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
          findsOneWidget,
        );
      });

      testWidgets('is disabled when canRedo is false', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canRedo: false));

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
        );
        expect(semantics.properties.enabled, isFalse);
      });

      testWidgets('is enabled when canRedo is true', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canRedo: true));

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
        );
        expect(semantics.properties.enabled, isTrue);
      });
    });

    group('Done button', () {
      testWidgets('renders with correct semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Done',
          ),
          findsOneWidget,
        );
      });

      testWidgets('is marked as a button', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Done',
          ),
        );
        expect(semantics.properties.button, isTrue);
      });
    });

    group('State updates', () {
      testWidgets('updates when canUndo changes', (tester) async {
        final controller = StreamController<VideoEditorDrawState>.broadcast();

        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canUndo: false));
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Initial state - undo disabled
        var semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
        );
        expect(semantics.properties.enabled, isFalse);

        // Update state
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canUndo: true));
        controller.add(const VideoEditorDrawState(canUndo: true));
        await tester.pumpAndSettle();

        semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Undo',
          ),
        );
        expect(semantics.properties.enabled, isTrue);

        await controller.close();
      });

      testWidgets('updates when canRedo changes', (tester) async {
        final controller = StreamController<VideoEditorDrawState>.broadcast();

        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canRedo: false));
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Initial state - redo disabled
        var semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
        );
        expect(semantics.properties.enabled, isFalse);

        // Update state
        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorDrawState(canRedo: true));
        controller.add(const VideoEditorDrawState(canRedo: true));
        await tester.pumpAndSettle();

        semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Redo',
          ),
        );
        expect(semantics.properties.enabled, isTrue);

        await controller.close();
      });
    });
  });
}

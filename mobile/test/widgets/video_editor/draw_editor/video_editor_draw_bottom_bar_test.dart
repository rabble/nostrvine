// ABOUTME: Tests for VideoEditorDrawBottomBar widget.
// ABOUTME: Validates tool selection, color picker button, and tool interactions.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_arrow.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_eraser.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_marker.dart';
import 'package:openvine/widgets/video_editor/draw_editor/tools/video_editor_draw_tool_pencil.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_indicator.dart';

class MockVideoEditorDrawBloc
    extends MockBloc<VideoEditorDrawEvent, VideoEditorDrawState>
    implements VideoEditorDrawBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const VideoEditorDrawToolSelected(DrawToolType.pencil),
    );
    registerFallbackValue(const VideoEditorDrawColorSelected(Colors.red));
  });

  group('VideoEditorDrawBottomBar', () {
    late MockVideoEditorDrawBloc mockBloc;

    setUp(() {
      mockBloc = MockVideoEditorDrawBloc();

      when(() => mockBloc.state).thenReturn(const VideoEditorDrawState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    Widget buildWidget() {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<VideoEditorDrawBloc>.value(
            value: mockBloc,
            child: const SizedBox(
              width: 400,
              height: 600,
              child: VideoEditorDrawBottomBar(),
            ),
          ),
        ),
      );
    }

    group('Tool buttons', () {
      testWidgets('renders all four tool buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(DrawToolPencil), findsOneWidget);
        expect(find.byType(DrawToolMarker), findsOneWidget);
        expect(find.byType(DrawToolArrow), findsOneWidget);
        expect(find.byType(DrawToolEraser), findsOneWidget);
      });

      testWidgets('pencil is selected by default', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final pencil = tester.widget<DrawToolPencil>(
          find.byType(DrawToolPencil),
        );
        expect(pencil.isSelected, isTrue);

        final marker = tester.widget<DrawToolMarker>(
          find.byType(DrawToolMarker),
        );
        expect(marker.isSelected, isFalse);
      });

      testWidgets('tapping pencil dispatches ToolSelected event', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(find.byType(DrawToolPencil));
        await tester.pump();

        verify(
          () => mockBloc.add(
            const VideoEditorDrawToolSelected(DrawToolType.pencil),
          ),
        ).called(1);
      });

      testWidgets('tapping marker dispatches ToolSelected event', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(find.byType(DrawToolMarker));
        await tester.pump();

        verify(
          () => mockBloc.add(
            const VideoEditorDrawToolSelected(DrawToolType.marker),
          ),
        ).called(1);
      });

      testWidgets('tapping arrow dispatches ToolSelected event', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(find.byType(DrawToolArrow));
        await tester.pump();

        verify(
          () => mockBloc.add(
            const VideoEditorDrawToolSelected(DrawToolType.arrow),
          ),
        ).called(1);
      });

      testWidgets('tapping eraser dispatches ToolSelected event', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(find.byType(DrawToolEraser));
        await tester.pump();

        verify(
          () => mockBloc.add(
            const VideoEditorDrawToolSelected(DrawToolType.eraser),
          ),
        ).called(1);
      });

      testWidgets('shows correct tool as selected based on state', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(selectedTool: DrawToolType.marker),
        );

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final pencil = tester.widget<DrawToolPencil>(
          find.byType(DrawToolPencil),
        );
        expect(pencil.isSelected, isFalse);

        final marker = tester.widget<DrawToolMarker>(
          find.byType(DrawToolMarker),
        );
        expect(marker.isSelected, isTrue);

        final arrow = tester.widget<DrawToolArrow>(find.byType(DrawToolArrow));
        expect(arrow.isSelected, isFalse);

        final eraser = tester.widget<DrawToolEraser>(
          find.byType(DrawToolEraser),
        );
        expect(eraser.isSelected, isFalse);
      });
    });

    group('Tool indicator', () {
      testWidgets('renders indicator widget', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(VideoEditorDrawItemIndicator), findsOneWidget);
      });
    });

    group('Color picker button', () {
      testWidgets('renders color picker button with semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Color picker',
          ),
          findsOneWidget,
        );
      });

      testWidgets('tapping color picker opens bottom sheet', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Color picker',
          ),
        );
        await tester.pumpAndSettle();

        // Bottom sheet should be shown
        expect(find.byType(BottomSheet), findsOneWidget);
      });
    });

    group('State updates', () {
      testWidgets('updates tool selection when state changes', (tester) async {
        final controller = StreamController<VideoEditorDrawState>.broadcast();

        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(selectedTool: DrawToolType.pencil),
        );
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Initial state - pencil selected
        var pencil = tester.widget<DrawToolPencil>(find.byType(DrawToolPencil));
        expect(pencil.isSelected, isTrue);

        // Update state
        when(() => mockBloc.state).thenReturn(
          const VideoEditorDrawState(selectedTool: DrawToolType.eraser),
        );
        controller.add(
          const VideoEditorDrawState(selectedTool: DrawToolType.eraser),
        );
        await tester.pumpAndSettle();

        pencil = tester.widget<DrawToolPencil>(find.byType(DrawToolPencil));
        expect(pencil.isSelected, isFalse);

        final eraser = tester.widget<DrawToolEraser>(
          find.byType(DrawToolEraser),
        );
        expect(eraser.isSelected, isTrue);

        await controller.close();
      });
    });
  });
}

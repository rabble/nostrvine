// ABOUTME: Tests for VideoEditorFilterOverlayControls widget.
// ABOUTME: Validates opacity slider visibility, top bar buttons, and animations.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class MockVideoEditorFilterBloc
    extends MockBloc<VideoEditorFilterEvent, VideoEditorFilterState>
    implements VideoEditorFilterBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(VideoEditorFilterSelected(presetFiltersList.first));
    registerFallbackValue(const VideoEditorFilterCancelled());
  });

  group('VideoEditorFilterOverlayControls', () {
    late MockVideoEditorFilterBloc mockBloc;
    late GlobalKey<ProImageEditorState> editorKey;

    setUp(() {
      mockBloc = MockVideoEditorFilterBloc();
      editorKey = GlobalKey<ProImageEditorState>();

      // Default state - no filter selected
      when(() => mockBloc.state).thenReturn(
        VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: null,
          opacity: 1.0,
        ),
      );
      when(() => mockBloc.stream).thenAnswer((_) => Stream.empty());
    });

    Widget buildWidget() {
      return MaterialApp(
        home: Scaffold(
          body: VideoEditorScope(
            editorKey: editorKey,
            onAddStickers: () {},
            onAddEditTextLayer: ([layer]) async => null,
            child: BlocProvider<VideoEditorFilterBloc>.value(
              value: mockBloc,
              child: const SizedBox(
                width: 400,
                height: 600,
                child: VideoEditorFilterOverlayControls(),
              ),
            ),
          ),
        ),
      );
    }

    group('Opacity Slider', () {
      testWidgets('is hidden when no filter is selected', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoEditorVerticalSlider), findsNothing);
      });

      testWidgets('is visible when a filter is selected', (tester) async {
        when(() => mockBloc.state).thenReturn(
          VideoEditorFilterState(
            filters: presetFiltersList,
            selectedFilter: presetFiltersList[1], // Non-None filter
            opacity: 0.8,
          ),
        );

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoEditorVerticalSlider), findsOneWidget);
      });

      testWidgets('passes current opacity value to slider', (tester) async {
        const testOpacity = 0.65;
        when(() => mockBloc.state).thenReturn(
          VideoEditorFilterState(
            filters: presetFiltersList,
            selectedFilter: presetFiltersList[1],
            opacity: testOpacity,
          ),
        );

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final slider = tester.widget<VideoEditorVerticalSlider>(
          find.byType(VideoEditorVerticalSlider),
        );
        expect(slider.value, testOpacity);
      });

      testWidgets('shows slider during animation', (tester) async {
        // Start with a filter selected
        when(() => mockBloc.state).thenReturn(
          VideoEditorFilterState(
            filters: presetFiltersList,
            selectedFilter: presetFiltersList[1],
            opacity: 1.0,
          ),
        );

        await tester.pumpWidget(buildWidget());
        // Pump some frames of animation
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(VideoEditorVerticalSlider), findsOneWidget);
      });
    });

    group('Top Bar', () {
      testWidgets('renders Close and Done buttons', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Close button has Semantics label 'Close'
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Close',
          ),
          findsOneWidget,
        );

        // Done button has Semantics label 'Done'
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Done',
          ),
          findsOneWidget,
        );
      });

      testWidgets('tapping Close dispatches Cancelled event', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Close',
          ),
        );
        await tester.pump();

        verify(
          () => mockBloc.add(const VideoEditorFilterCancelled()),
        ).called(1);
      });
    });
  });
}

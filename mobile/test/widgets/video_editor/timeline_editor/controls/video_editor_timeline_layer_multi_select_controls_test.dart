// ABOUTME: Widget tests for TimelineLayerMultiSelectControls.
// ABOUTME: Verifies the count label, combine gating, combine wiring and done.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_layer_multi_select_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

PaintLayer _paintLayer(String id) => PaintLayer(
  id: id,
  rawSize: const Size(10, 10),
  opacity: 1,
  item: PaintedModel(
    mode: PaintMode.freeStyle,
    offsets: const [Offset.zero, Offset(10, 10)],
    erasedOffsets: const [],
    color: const Color(0xFFFF0000),
    strokeWidth: 6,
    opacity: 1,
  ),
);

void main() {
  group(TimelineLayerMultiSelectControls, () {
    late _MockTimelineOverlayBloc overlayBloc;
    late _MockProImageEditorState editor;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      overlayBloc = _MockTimelineOverlayBloc();
      editor = _MockProImageEditorState();
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
    });

    Widget build() {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<TimelineOverlayBloc>.value(
              value: overlayBloc,
              child: VideoEditorScope(
                editorKey: GlobalKey(),
                removeAreaKey: GlobalKey(),
                originalClipAspectRatio: 9 / 16,
                bodySizeNotifier: ValueNotifier(const Size(400, 600)),
                zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
                fromLibrary: false,
                onOpenCamera: () {},
                onOpenClipsEditor: () {},
                onAddStickers: () {},
                onAddEditTextLayer: ([layer]) async => null,
                onOpenMusicLibrary: () {},
                onOpenVoiceOver: () {},
                editorOverride: editor,
                child: const TimelineLayerMultiSelectControls(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the selection count and the combine/done actions', (
      tester,
    ) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(
          isLayerMultiSelectMode: true,
          multiSelectedLayerIds: {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      expect(
        find.text(l10n.videoEditorLayerMultiSelectCountLabel(2)),
        findsOneWidget,
      );
      expect(find.text(l10n.videoEditorCombineLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
    });

    testWidgets('combine is disabled with fewer than two selected drawings', (
      tester,
    ) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(
          isLayerMultiSelectMode: true,
          multiSelectedLayerIds: {'a'},
        ),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorCombineDrawLayersSemanticLabel),
      );
      await tester.pump();

      verifyNever(() => editor.mergeSelectedLayers());
    });

    testWidgets(
      'combine selects the ids, merges, exits mode and selects the result',
      (tester) async {
        when(() => overlayBloc.state).thenReturn(
          const TimelineOverlayState(
            isLayerMultiSelectMode: true,
            multiSelectedLayerIds: {'a', 'b'},
          ),
        );
        when(() => editor.unselectAllLayers()).thenAnswer((_) {});
        when(() => editor.clearLayerSelection()).thenAnswer((_) {});
        when(
          () => editor.selectLayerById(
            any(),
            enableMultiSelect: any(named: 'enableMultiSelect'),
          ),
        ).thenReturn(null);
        when(
          () => editor.mergeSelectedLayers(),
        ).thenReturn(_paintLayer('merged'));

        await tester.pumpWidget(build());

        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorCombineDrawLayersSemanticLabel),
        );
        await tester.pump();

        verify(
          () => editor.selectLayerById('a', enableMultiSelect: true),
        ).called(1);
        verify(
          () => editor.selectLayerById('b', enableMultiSelect: true),
        ).called(1);
        verify(() => editor.mergeSelectedLayers()).called(1);
        verify(
          () => overlayBloc.add(
            const TimelineOverlayLayerMultiSelectCancelled(),
          ),
        ).called(1);
        verify(
          () => overlayBloc.add(const TimelineOverlayItemSelected('merged')),
        ).called(1);
      },
    );

    testWidgets('clear empties the selection without leaving the mode', (
      tester,
    ) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(
          isLayerMultiSelectMode: true,
          multiSelectedLayerIds: {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoEditorLayerMultiSelectClearSemanticLabel,
        ),
      );
      await tester.pump();

      verify(
        () => overlayBloc.add(const TimelineOverlayLayerSelectionCleared()),
      ).called(1);
    });

    testWidgets('clear is disabled when nothing is selected', (tester) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(isLayerMultiSelectMode: true),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoEditorLayerMultiSelectClearSemanticLabel,
        ),
      );
      await tester.pump();

      verifyNever(
        () => overlayBloc.add(const TimelineOverlayLayerSelectionCleared()),
      );
    });

    testWidgets('done exits multi-select mode', (tester) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(
          isLayerMultiSelectMode: true,
          multiSelectedLayerIds: {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoEditorLayerMultiSelectDoneSemanticLabel,
        ),
      );
      await tester.pump();

      verify(
        () => overlayBloc.add(const TimelineOverlayLayerMultiSelectCancelled()),
      ).called(1);
    });
  });
}

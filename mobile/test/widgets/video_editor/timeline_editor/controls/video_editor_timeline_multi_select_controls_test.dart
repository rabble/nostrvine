// ABOUTME: Widget tests for the clip and stop-motion-frame multi-select bars.
// ABOUTME: Verifies the count label, action gating, and event dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_multi_select_controls.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

DivineVideoClip _stopMotionClip(String id, int frameCount) {
  return DivineVideoClip(
    id: id,
    duration: Duration(milliseconds: 500 * frameCount),
    recordedAt: DateTime(2025),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    stopMotionFrames: [
      for (var i = 0; i < frameCount; i++)
        StopMotionClipFrame(
          path: '/tmp/$id-$i.png',
          duration: const Duration(milliseconds: 500),
        ),
    ],
  );
}

DivineVideoClip _clip(String id) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/$id.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2025),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  group(TimelineMultiSelectControls, () {
    late _MockClipEditorBloc bloc;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      bloc = _MockClipEditorBloc();
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
    });

    Widget build() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<ClipEditorBloc>.value(
            value: bloc,
            child: const TimelineMultiSelectControls(),
          ),
        ),
      );
    }

    DivineIconButton buttonWithLabel(WidgetTester tester, String label) {
      return tester
          .widgetList<DivineIconButton>(find.byType(DivineIconButton))
          .firstWhere((b) => b.semanticLabel == label);
    }

    testWidgets('renders the selection count and Merge/Delete/Done', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b'), _clip('c')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      expect(
        find.text(l10n.videoEditorMultiSelectCountLabel(2)),
        findsOneWidget,
      );
      expect(find.text(l10n.videoEditorMergeLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDeleteLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDoneLabel), findsOneWidget);
    });

    testWidgets('Merge is disabled with fewer than two clips selected', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a'},
        ),
      );

      await tester.pumpWidget(build());

      final merge = buttonWithLabel(
        tester,
        l10n.videoEditorMergeSelectedClipsSemanticLabel,
      );
      expect(merge.onPressed, isNull);
    });

    testWidgets('Merge dispatches a merge request when enabled', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b'), _clip('c')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorMergeSelectedClipsSemanticLabel),
      );
      await tester.pump();

      verify(
        () => bloc.add(const ClipEditorSelectedClipsMergeRequested()),
      ).called(1);
    });

    testWidgets('Delete is disabled when every clip is selected', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      final delete = buttonWithLabel(
        tester,
        l10n.videoEditorDeleteSelectedClipsSemanticLabel,
      );
      expect(delete.onPressed, isNull);
    });

    testWidgets('Merge and Delete are disabled while merging', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b'), _clip('c')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
          isMerging: true,
        ),
      );

      await tester.pumpWidget(build());

      expect(
        buttonWithLabel(
          tester,
          l10n.videoEditorMergeSelectedClipsSemanticLabel,
        ).onPressed,
        isNull,
      );
      expect(
        buttonWithLabel(
          tester,
          l10n.videoEditorDeleteSelectedClipsSemanticLabel,
        ).onPressed,
        isNull,
      );
    });

    testWidgets('Done dispatches a cancel event', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a'},
        ),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorMultiSelectDoneSemanticLabel),
      );
      await tester.pump();

      verify(
        () => bloc.add(const ClipEditorMultiSelectCancelled()),
      ).called(1);
    });

    testWidgets('Delete dispatches a remove event when enabled', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_clip('a'), _clip('b'), _clip('c')],
          isMultiSelectMode: true,
          selectedClipIds: const {'a', 'b'},
        ),
      );

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorDeleteSelectedClipsSemanticLabel),
      );
      await tester.pump();

      verify(
        () => bloc.add(const ClipEditorSelectedClipsRemoved()),
      ).called(1);
    });
  });

  group(TimelineFrameMultiSelectControls, () {
    late _MockClipEditorBloc bloc;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      bloc = _MockClipEditorBloc();
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
    });

    Widget build() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<ClipEditorBloc>.value(
            value: bloc,
            child: const TimelineFrameMultiSelectControls(),
          ),
        ),
      );
    }

    DivineIconButton buttonWithLabel(WidgetTester tester, String label) {
      return tester
          .widgetList<DivineIconButton>(find.byType(DivineIconButton))
          .firstWhere((b) => b.semanticLabel == label);
    }

    testWidgets('offers Duplicate on the selected stills', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_stopMotionClip('a', 4)],
          isMultiSelectMode: true,
          selectedFrameIndexes: const {1, 2},
        ),
      );

      await tester.pumpWidget(build());

      expect(
        buttonWithLabel(
          tester,
          l10n.videoEditorDuplicateSelectedFramesSemanticLabel,
        ).onPressed,
        isNotNull,
      );
    });

    testWidgets('disables Duplicate with nothing selected', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [_stopMotionClip('a', 4)],
          isMultiSelectMode: true,
        ),
      );

      await tester.pumpWidget(build());

      expect(
        buttonWithLabel(
          tester,
          l10n.videoEditorDuplicateSelectedFramesSemanticLabel,
        ).onPressed,
        isNull,
      );
    });
  });
}

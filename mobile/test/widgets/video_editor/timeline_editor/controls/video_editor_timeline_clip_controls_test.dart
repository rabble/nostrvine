// ABOUTME: Widget tests for TimelineClipControls.
// ABOUTME: Verifies visible actions and done-event dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

void main() {
  group(TimelineClipControls, () {
    late _MockClipEditorBloc bloc;

    setUp(() {
      bloc = _MockClipEditorBloc();
      when(() => bloc.state).thenReturn(const ClipEditorState());
      when(
        () => bloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());
    });

    Widget build() {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<ClipEditorBloc>.value(
              value: bloc,
              child: TimelineClipControls(
                playheadPosition: ValueNotifier(Duration.zero),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders expected labels for single-clip state', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Split'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('dispatches ClipEditorEditingStopped when done pressed', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      await tester.tap(find.byType(DivineIconButton).last);
      await tester.pump();

      verify(() => bloc.add(const ClipEditorEditingStopped())).called(1);
    });

    testWidgets(
      'dispatches ClipEditorClipReverseRequested when reverse pressed',
      (
        tester,
      ) async {
        final state = ClipEditorState(
          clips: [
            DivineVideoClip(
              id: 'clip-1',
              video: EditorVideo.file('/tmp/clip-1.mp4'),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime(2025),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
        );
        final l10n = lookupAppLocalizations(const Locale('en'));
        when(() => bloc.state).thenReturn(state);

        await tester.pumpWidget(build());

        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorReverseClipSemanticLabel),
        );
        await tester.pump();

        verify(
          () =>
              bloc.add(const ClipEditorClipReverseRequested(clipId: 'clip-1')),
        ).called(1);
      },
    );

    // Regression test for Fix 2: Done button is disabled while audio
    // extraction is running so the user cannot dismiss the busy state
    // mid-flight. The result side effect itself lives on
    // VideoEditorScaffold and survives even after this widget unmounts.
    testWidgets(
      'Done button passes null onDone to controls while isExtractingAudio',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const ClipEditorState(isExtractingAudio: true));
        await tester.pumpWidget(build());

        final controls = tester.widget<VideoEditorTimelineControls>(
          find.byType(VideoEditorTimelineControls),
        );
        expect(
          controls.onDone,
          isNull,
          reason:
              'onDone must be null while extracting so Done cannot be tapped',
        );
      },
    );

    testWidgets(
      'Speed button is hidden while isExtractingAudio',
      (tester) async {
        when(
          () => bloc.state,
        ).thenReturn(const ClipEditorState(isExtractingAudio: true));
        await tester.pumpWidget(build());

        final controls = tester.widget<VideoEditorTimelineControls>(
          find.byType(VideoEditorTimelineControls),
        );
        expect(controls.onSpeed, isNull);
      },
    );

    testWidgets('Select button is hidden for a single clip', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [
            DivineVideoClip(
              id: 'clip-1',
              video: EditorVideo.file('/tmp/clip-1.mp4'),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime(2025),
              targetAspectRatio: model.AspectRatio.vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onMultiSelect, isNull);
    });

    testWidgets('Select button starts multi-select with multiple clips', (
      tester,
    ) async {
      DivineVideoClip clip(String id) => DivineVideoClip(
        id: id,
        video: EditorVideo.file('/tmp/$id.mp4'),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime(2025),
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );
      when(() => bloc.state).thenReturn(
        ClipEditorState(clips: [clip('clip-1'), clip('clip-2')]),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(build());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorMultiSelectSemanticLabel),
      );
      await tester.pump();

      verify(
        () => bloc.add(const ClipEditorMultiSelectStarted('clip-1')),
      ).called(1);
    });
  });
}

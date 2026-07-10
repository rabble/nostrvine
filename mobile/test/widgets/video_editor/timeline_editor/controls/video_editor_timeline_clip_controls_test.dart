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
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show ProImageEditorState;
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  group(TimelineClipControls, () {
    late _MockClipEditorBloc bloc;

    setUpAll(() {
      registerFallbackValue(const ClipEditorEditingStopped());
    });

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

    DivineVideoClip clip(String id) => DivineVideoClip(
      id: id,
      video: EditorVideo.file('/tmp/$id.mp4'),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2025),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    );

    Future<VideoEditorTimelineControls> pumpWithMissingEditorScope(
      WidgetTester tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ClipEditorState(clips: [clip('clip-1'), clip('clip-2')]));
      final overlayBloc = _MockTimelineOverlayBloc();
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              // An unattached editorKey => VideoEditorScope.editor is null,
              // reproducing a gesture that resolves after the editor route
              // was popped.
              body: VideoEditorScope(
                editorKey: GlobalKey<ProImageEditorState>(),
                removeAreaKey: GlobalKey(),
                originalClipAspectRatio: 9 / 16,
                bodySizeNotifier: ValueNotifier(const Size(400, 600)),
                zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
                fromLibrary: false,
                onOpenCamera: () {},
                onOpenClipsEditor: () {},
                onAddStickers: () {},
                onOpenMusicLibrary: () {},
                onOpenVoiceOver: () {},
                onAddEditTextLayer: ([layer]) async => null,
                child: MultiBlocProvider(
                  providers: [
                    BlocProvider<ClipEditorBloc>.value(value: bloc),
                    BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
                  ],
                  child: TimelineClipControls(
                    playheadPosition: ValueNotifier(Duration.zero),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      return tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
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
      (tester) async {
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

    // Done stays tappable during a render — leaving edit mode is safe because
    // the extraction result is committed by an editor-session-level listener
    // (VideoEditorScaffold) that survives these controls unmounting.
    testWidgets('Done stays enabled and dispatches stop while extracting', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1')],
          isExtractingAudio: true,
          extractingAudioClipId: 'clip-1',
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onDone, isNotNull);

      await tester.tap(find.byType(DivineIconButton).last);
      await tester.pump();

      verify(() => bloc.add(const ClipEditorEditingStopped())).called(1);
    });

    // Regression: the Speed action must stay mounted (disabled), not vanish,
    // while the *current* clip's audio is extracting — the disappearing
    // control confused users.
    testWidgets(
      "Speed stays mounted and is disabled while the current clip's audio "
      'extracts',
      (tester) async {
        when(() => bloc.state).thenReturn(
          ClipEditorState(
            clips: [clip('clip-1'), clip('clip-2')],
            isExtractingAudio: true,
            extractingAudioClipId: 'clip-1',
          ),
        );
        await tester.pumpWidget(build());

        final controls = tester.widget<VideoEditorTimelineControls>(
          find.byType(VideoEditorTimelineControls),
        );
        // Action stays wired; the child renders it disabled via
        // isExtractingAudio.
        expect(controls.onSpeed, isNotNull);
        expect(controls.isExtractingAudio, isTrue);
      },
    );

    // A render on a *different* clip must not block the current clip's Speed.
    testWidgets(
      "Speed stays enabled while a different clip's audio extracts",
      (tester) async {
        when(() => bloc.state).thenReturn(
          ClipEditorState(
            clips: [clip('clip-1'), clip('clip-2')],
            currentClipIndex: 1,
            isExtractingAudio: true,
            extractingAudioClipId: 'clip-1',
          ),
        );
        await tester.pumpWidget(build());

        final controls = tester.widget<VideoEditorTimelineControls>(
          find.byType(VideoEditorTimelineControls),
        );
        expect(controls.onSpeed, isNotNull);
        expect(controls.isExtractingAudio, isFalse);
      },
    );

    testWidgets('Split stays mounted and is disabled while splitting the '
        'current clip', (tester) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1'), clip('clip-2')],
          isSplitting: true,
          splittingClipId: 'clip-1',
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onSplit, isNotNull);
      expect(controls.isSplitting, isTrue);
    });

    testWidgets('Split stays enabled while a different clip splits', (
      tester,
    ) async {
      when(() => bloc.state).thenReturn(
        ClipEditorState(
          clips: [clip('clip-1'), clip('clip-2')],
          currentClipIndex: 1,
          isSplitting: true,
          splittingClipId: 'clip-1',
        ),
      );
      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      expect(controls.onSplit, isNotNull);
      expect(controls.isSplitting, isFalse);
    });

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

    final staleEditorActions =
        <
          ({
            String actionLabel,
            VoidCallback? Function(VideoEditorTimelineControls controls)
            callback,
          })
        >[
          (actionLabel: 'delete', callback: (controls) => controls.onDelete),
          (
            actionLabel: 'duplicate',
            callback: (controls) => controls.onDuplicated,
          ),
          (
            actionLabel: 'speed change',
            callback: (controls) => controls.onSpeed,
          ),
        ];

    for (final action in staleEditorActions) {
      testWidgets(
        '${action.actionLabel} is a no-op when the editor scope is gone',
        (tester) async {
          final controls = await pumpWithMissingEditorScope(tester);

          final callback = action.callback(controls);
          expect(callback, isNotNull);
          callback!.call();
          await tester.pump();

          expect(tester.takeException(), isNull);
          verifyNever(() => bloc.add(any()));
        },
      );
    }

    testWidgets('Select button starts multi-select with multiple clips', (
      tester,
    ) async {
      when(
        () => bloc.state,
      ).thenReturn(ClipEditorState(clips: [clip('clip-1'), clip('clip-2')]));

      await tester.pumpWidget(build());

      final controls = tester.widget<VideoEditorTimelineControls>(
        find.byType(VideoEditorTimelineControls),
      );
      controls.onMultiSelect?.call();
      await tester.pump();

      verify(
        () => bloc.add(const ClipEditorMultiSelectStarted('clip-1')),
      ).called(1);
    });
  });
}

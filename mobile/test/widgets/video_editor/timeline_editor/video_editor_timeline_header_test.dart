// ABOUTME: Widget tests for VideoEditorTimelineHeader.
// ABOUTME: Validates play/pause, mute, undo/redo buttons and time display.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_header.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoEditorTimelineHeader, () {
    late _MockVideoEditorMainBloc mockMainBloc;
    late _MockClipEditorBloc mockClipBloc;
    late ValueNotifier<Duration> playheadPosition;

    setUp(() {
      mockMainBloc = _MockVideoEditorMainBloc();
      mockClipBloc = _MockClipEditorBloc();
      playheadPosition = ValueNotifier(Duration.zero);

      when(() => mockMainBloc.state).thenReturn(
        const VideoEditorMainState(),
      );
      when(() => mockMainBloc.stream).thenAnswer(
        (_) => const Stream<VideoEditorMainState>.empty(),
      );
      when(() => mockClipBloc.state).thenReturn(
        const ClipEditorState(),
      );
      when(() => mockClipBloc.stream).thenAnswer(
        (_) => const Stream<ClipEditorState>.empty(),
      );
    });

    tearDown(() {
      playheadPosition.dispose();
    });

    Widget buildWidget({
      VideoEditorMainState? mainState,
      ClipEditorState? clipState,
      Duration? position,
    }) {
      if (mainState != null) {
        when(() => mockMainBloc.state).thenReturn(mainState);
      }
      if (clipState != null) {
        when(() => mockClipBloc.state).thenReturn(clipState);
      }
      if (position != null) {
        playheadPosition.value = position;
      }

      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoEditorScope(
            editorKey: GlobalKey<ProImageEditorState>(),
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            fromLibrary: false,
            onOpenClipsEditor: () {},
            onAddStickers: () {},
            onAdjustVolume: () {},
            onOpenMusicLibrary: () {},
            onAddEditTextLayer: ([layer]) async => null,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<VideoEditorMainBloc>.value(value: mockMainBloc),
                BlocProvider<ClipEditorBloc>.value(value: mockClipBloc),
              ],
              child: VideoEditorTimelineHeader(
                playheadPosition: playheadPosition,
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoEditorTimelineHeader', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.byType(VideoEditorTimelineHeader),
          findsOneWidget,
        );
      });

      testWidgets('renders play/pause button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Play'), findsOneWidget);
      });

      testWidgets('renders mute button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Mute audio'), findsOneWidget);
      });

      testWidgets('renders undo button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Undo'), findsOneWidget);
      });

      testWidgets('renders redo button', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.bySemanticsLabel('Redo'), findsOneWidget);
      });
    });

    group('play/pause', () {
      testWidgets('shows play label when not playing', (tester) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState()),
        );

        expect(find.bySemanticsLabel('Play'), findsOneWidget);
      });

      testWidgets('shows pause label when playing', (tester) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState(isPlaying: true)),
        );

        expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      });

      testWidgets('dispatches toggle event on tap', (tester) async {
        await tester.pumpWidget(buildWidget());

        await tester.tap(find.bySemanticsLabel('Play'));
        await tester.pump();

        verify(
          () => mockMainBloc.add(
            const VideoEditorPlaybackToggleRequested(),
          ),
        ).called(1);
      });
    });

    group('mute', () {
      testWidgets('shows mute label when not muted', (tester) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState()),
        );

        expect(find.bySemanticsLabel('Mute audio'), findsOneWidget);
      });

      testWidgets('shows unmute label when muted', (tester) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState(isMuted: true)),
        );

        expect(find.bySemanticsLabel('Unmute audio'), findsOneWidget);
      });

      testWidgets('dispatches mute toggle event on tap', (tester) async {
        await tester.pumpWidget(buildWidget());

        await tester.tap(find.bySemanticsLabel('Mute audio'));
        await tester.pump();

        verify(
          () => mockMainBloc.add(const VideoEditorMuteToggled()),
        ).called(1);
      });
    });

    group('undo/redo', () {
      testWidgets('undo button is disabled when canUndo is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState()),
        );

        final undoButtons = tester.widgetList<DivineIconButton>(
          find.byType(DivineIconButton),
        );
        // Undo is the 3rd button (play, mute, undo, redo)
        final undoButton = undoButtons.elementAt(2);
        expect(undoButton.onPressed, isNull);
      });

      testWidgets('undo button is enabled when canUndo is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState(canUndo: true)),
        );

        final undoButtons = tester.widgetList<DivineIconButton>(
          find.byType(DivineIconButton),
        );
        final undoButton = undoButtons.elementAt(2);
        expect(undoButton.onPressed, isNotNull);
      });

      testWidgets('redo button is disabled when canRedo is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState()),
        );

        final redoButtons = tester.widgetList<DivineIconButton>(
          find.byType(DivineIconButton),
        );
        final redoButton = redoButtons.elementAt(3);
        expect(redoButton.onPressed, isNull);
      });

      testWidgets('redo button is enabled when canRedo is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(mainState: const VideoEditorMainState(canRedo: true)),
        );

        final redoButtons = tester.widgetList<DivineIconButton>(
          find.byType(DivineIconButton),
        );
        final redoButton = redoButtons.elementAt(3);
        expect(redoButton.onPressed, isNotNull);
      });
    });

    group('time display', () {
      testWidgets('displays time from playhead position', (tester) async {
        await tester.pumpWidget(
          buildWidget(position: const Duration(seconds: 5)),
        );

        // formatCompactDuration(5s) = "05:00"
        expect(find.textContaining('05:00'), findsOneWidget);
      });

      testWidgets('updates time when playhead position changes', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        // Initial: 0s = "00:00"
        expect(find.textContaining('00:00'), findsOneWidget);

        playheadPosition.value = const Duration(seconds: 3, milliseconds: 500);
        await tester.pump();

        // 3.5s = "03:50"
        expect(find.textContaining('03:50'), findsOneWidget);
      });

      testWidgets('shows total duration from ClipEditorBloc', (tester) async {
        final clips = [
          _createTestClip(id: 'a', seconds: 5),
          _createTestClip(id: 'b', seconds: 3),
        ];

        await tester.pumpWidget(
          buildWidget(
            clipState: ClipEditorState(clips: clips),
            position: const Duration(seconds: 2),
          ),
        );

        // totalDuration = 8s → "08:00"
        expect(find.textContaining('08:00'), findsOneWidget);
      });
    });
  });
}

DivineVideoClip _createTestClip({
  required String id,
  int seconds = 2,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/test_$id.mp4'),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
  );
}

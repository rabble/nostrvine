// ABOUTME: Widget tests for VideoEditorMainActionsSheet.
// ABOUTME: Verifies action rendering and callback behavior.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_actions_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorMainActionsSheet, () {
    late _MockVideoEditorMainBloc mainBloc;
    late _MockClipEditorBloc clipBloc;
    late _MockTimelineOverlayBloc timelineOverlayBloc;

    setUp(() {
      mainBloc = _MockVideoEditorMainBloc();
      clipBloc = _MockClipEditorBloc();
      timelineOverlayBloc = _MockTimelineOverlayBloc();

      when(() => mainBloc.state).thenReturn(const VideoEditorMainState());
      when(() => clipBloc.state).thenReturn(const ClipEditorState());
      when(
        () => timelineOverlayBloc.state,
      ).thenReturn(const TimelineOverlayState());
    });

    testWidgets('renders all action labels', (tester) async {
      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
        ),
      );

      expect(find.text(l10n.videoEditorCameraLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorLibraryLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorAudioLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorTextLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDrawLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorFilterLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorStickers), findsOneWidget);
    });

    testWidgets('tap on Clips triggers onOpenClipsEditor', (tester) async {
      var openedClips = false;

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
          onOpenClipsEditor: () => openedClips = true,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenLibrarySemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(openedClips, isTrue);
    });

    testWidgets('tap on Audio triggers onOpenMusicLibrary', (tester) async {
      var openedMusic = false;

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
          onOpenMusicLibrary: () => openedMusic = true,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenAudioSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(openedMusic, isTrue);
    });

    testWidgets('tap on Stickers triggers onAddStickers', (tester) async {
      var addedStickers = false;

      await tester.pumpWidget(
        _buildWidget(
          mainBloc: mainBloc,
          clipBloc: clipBloc,
          timelineOverlayBloc: timelineOverlayBloc,
          onAddStickers: () => addedStickers = true,
        ),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenStickerSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(addedStickers, isTrue);
    });
  });
}

Widget _buildWidget({
  required _MockVideoEditorMainBloc mainBloc,
  required _MockClipEditorBloc clipBloc,
  required _MockTimelineOverlayBloc timelineOverlayBloc,
  VoidCallback? onOpenClipsEditor,
  VoidCallback? onOpenMusicLibrary,
  VoidCallback? onAddStickers,
}) {
  final editorKey = GlobalKey<ProImageEditorState>();
  final removeAreaKey = GlobalKey();

  final scope = VideoEditorScope(
    editorKey: editorKey,
    removeAreaKey: removeAreaKey,
    onOpenCamera: () {},
    onAddStickers: onAddStickers ?? () {},
    onOpenClipsEditor: onOpenClipsEditor ?? () {},
    onAddEditTextLayer: ([layer]) async => null,
    onOpenMusicLibrary: onOpenMusicLibrary ?? () {},
    originalClipAspectRatio: 9 / 16,
    bodySizeNotifier: ValueNotifier(const Size(400, 800)),
    zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
    fromLibrary: false,
  );

  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return MultiBlocProvider(
            providers: [
              BlocProvider<VideoEditorMainBloc>.value(value: mainBloc),
              BlocProvider<ClipEditorBloc>.value(value: clipBloc),
              BlocProvider<TimelineOverlayBloc>.value(
                value: timelineOverlayBloc,
              ),
            ],
            child: VideoEditorScope(
              editorKey: scope.editorKey,
              removeAreaKey: scope.removeAreaKey,
              onOpenCamera: () {},
              onAddStickers: scope.onAddStickers,
              onOpenClipsEditor: scope.onOpenClipsEditor,
              onAddEditTextLayer: scope.onAddEditTextLayer,
              onOpenMusicLibrary: scope.onOpenMusicLibrary,
              originalClipAspectRatio: scope.originalClipAspectRatio,
              bodySizeNotifier: scope.bodySizeNotifier,
              zoomMatrixNotifier: scope.zoomMatrixNotifier,
              fromLibrary: scope.fromLibrary,
              child: VideoEditorMainActionsSheet(scope: scope),
            ),
          );
        },
      ),
    ),
  );
}

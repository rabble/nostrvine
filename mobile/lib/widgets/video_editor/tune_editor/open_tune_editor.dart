// ABOUTME: Helper to open the tune sub-editor and sync the main editor state.
// ABOUTME: Works around pro_image_editor not reporting the tune sub-editor.

import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Opens the tune sub-editor and flips [VideoEditorMainBloc] into the tune
/// sub-editor state.
///
/// Pass [editSetId] to edit an existing timeline set (the session seeds from
/// and replaces that set); omit it to create a new set. The session kind is
/// recorded on [VideoEditorTuneBloc] up front so the canvas's `onInit` /
/// `onAfterViewInit` seed the bottom bar and preview accordingly.
///
/// pro_image_editor's `openTuneEditor` wraps the editor in a `HeroMode`, so
/// `openPage`'s `page is TuneEditor` check fails and it reports the opened
/// sub-editor as `SubEditor.unknown` instead of `SubEditor.tune`. The canvas's
/// `onOpenSubEditor` therefore never dispatches [VideoEditorMainOpenSubEditor]
/// for tune, and the custom overlay / bottom bar never appear. Dispatching the
/// open event here keeps the app UI in sync. (Closing is unaffected — the
/// canvas's `onStartCloseSubEditor` ignores the editor type.)
void openTuneEditor(
  VideoEditorMainBloc mainBloc,
  VideoEditorTuneBloc tuneBloc,
  VideoEditorScope scope, {
  String? editSetId,
}) {
  tuneBloc.add(VideoEditorTuneSessionStarted(setId: editSetId));
  mainBloc.add(const VideoEditorMainOpenSubEditor(SubEditorType.tune));
  scope.editor?.openTuneEditor();
}

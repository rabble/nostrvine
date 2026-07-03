// ABOUTME: Tests for the openTuneEditor helper.
// ABOUTME: Verifies it flips the main bloc into the tune sub-editor state.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/tune_editor/open_tune_editor.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('openTuneEditor dispatches the tune sub-editor open event', () async {
    final bloc = VideoEditorMainBloc();
    addTearDown(bloc.close);
    final bodySize = ValueNotifier(Size.zero);
    addTearDown(bodySize.dispose);
    final zoom = ValueNotifier(Matrix4.identity());
    addTearDown(zoom.dispose);

    // A scope with no mounted editor: `scope.editor` is null, so the
    // pro_image_editor call is a no-op and only the bloc dispatch is exercised.
    final scope = VideoEditorScope(
      editorKey: GlobalKey<ProImageEditorState>(),
      removeAreaKey: GlobalKey(),
      onAddStickers: () {},
      onOpenCamera: () {},
      onOpenClipsEditor: () {},
      onAddEditTextLayer: ([_]) async => null,
      onOpenMusicLibrary: () {},
      onOpenVoiceOver: () {},
      originalClipAspectRatio: 9 / 16,
      bodySizeNotifier: bodySize,
      zoomMatrixNotifier: zoom,
      fromLibrary: false,
    );

    expect(bloc.state.openSubEditor, isNull);

    openTuneEditor(bloc, scope);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.openSubEditor, SubEditorType.tune);
    expect(bloc.state.isSubEditorOpen, isTrue);
  });
}

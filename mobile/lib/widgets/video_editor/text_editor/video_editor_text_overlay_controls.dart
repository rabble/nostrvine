// ABOUTME: Top overlay controls for the text editor screen.
// ABOUTME: Displays close/done buttons and vertical font size slider.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';

/// Top overlay controls for the text editor screen.
///
/// Displays close and done buttons at the top, plus style controls
/// (color, alignment, background) at the bottom.
/// Includes a vertical slider for font size on the right side.
///
/// Note: Font selector and color picker panels are rendered outside
/// the editor in the parent screen to maintain correct editor sizing.
class VideoEditorTextOverlayControls extends StatelessWidget {
  const VideoEditorTextOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        // Close/Done buttons at the top
        Align(alignment: .topCenter, child: _TopBar()),

        // Vertical slider for font size on the right side
        Align(
          alignment: .centerRight,
          child: Padding(
            padding: .fromLTRB(0, 96, 10, 16),
            child: _FontSizeSlider(),
          ),
        ),
      ],
    );
  }
}

/// Vertical slider for adjusting font size.
///
/// Syncs the font scale with both the BLoC and the TextEditorState.
class _FontSizeSlider extends StatelessWidget {
  const _FontSizeSlider();

  @override
  Widget build(BuildContext context) {
    final fontSize = context.select<VideoEditorTextBloc, double>(
      (bloc) => bloc.state.fontSize,
    );

    return VideoEditorVerticalSlider(
      value: fontSize,
      onChanged: (normalizedValue) {
        final textEditor = VideoTextEditorScope.of(context).editor;
        final textEditorConfigs = textEditor.configs.textEditor;

        // Convert normalized value (0-1) to font scale range
        final fontScaleRange =
            textEditorConfigs.maxFontScale - textEditorConfigs.minFontScale;
        final fontScale =
            textEditorConfigs.minFontScale + (normalizedValue * fontScaleRange);

        // Sync with TextEditor
        textEditor.fontScale = fontScale;

        // Update BLoC state
        context.read<VideoEditorTextBloc>().add(
          VideoEditorTextFontSizeChanged(normalizedValue),
        );
      },
    );
  }
}

/// Top bar with close and done buttons.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return VideoEditorToolbar(
      onClose: () => VideoTextEditorScope.of(context).editor.close(),
      onDone: () => VideoTextEditorScope.of(context).editor.done(),
    );
  }
}

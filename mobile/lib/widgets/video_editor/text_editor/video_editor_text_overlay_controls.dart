// ABOUTME: Top overlay controls for the text editor screen.
// ABOUTME: Displays close button, done button, style buttons, and vertical slider.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_style_bar.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
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
    return Stack(
      children: [
        // Close/Done buttons at the top
        Align(alignment: .topCenter, child: _TopBar()),

        // Style controls (color, alignment, background, font) at the bottom
        Align(alignment: .bottomCenter, child: VideoEditorTextStyleBar()),

        // Vertical slider for font size on the right side
        Align(
          alignment: .centerRight,
          child: Padding(
            padding: const .fromLTRB(0, 96, 16, 96),
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
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: .fromLTRB(12, 12, 12, 0),
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            DivineIconButton(
              icon: .x,
              onPressed: () => VideoTextEditorScope.of(context).editor.close(),
              size: .small,
              type: .ghostSecondary,
              semanticLabel: 'Close',
            ),
            DivineIconButton(
              icon: .check,
              onPressed: () => VideoTextEditorScope.of(context).editor.done(),
              size: .small,
              type: .tertiary,
              semanticLabel: 'Done',
            ),
          ],
        ),
      ),
    );
  }
}

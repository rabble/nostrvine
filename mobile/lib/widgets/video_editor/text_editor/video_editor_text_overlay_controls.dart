// ABOUTME: Top overlay controls for the text editor screen.
// ABOUTME: Displays close button, done button, style buttons, and vertical slider.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
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
    return const SafeArea(
      bottom: false,
      child: Padding(
        padding: .fromLTRB(12, 12, 12, 0),
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [_CloseButton(), _DoneButton()],
        ),
      ),
    );
  }
}

// TODO(@hm21): Once the design decision has been made regarding what the
// buttons will look like, create them in the divine_ui package and reuse them.

/// Close button with dark scrim background.
class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Close',
      button: true,
      child: GestureDetector(
        onTap: () => VideoTextEditorScope.of(context).editor.close(),
        child: Container(
          margin: const .all(4),
          padding: const .all(8),
          decoration: BoxDecoration(
            color: VineTheme.scrim65,
            borderRadius: .circular(16),
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: SvgPicture.asset(
              'assets/icon/close.svg',
              width: 24,
              height: 24,
              colorFilter: const .mode(Colors.white, .srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

/// Done button with white background and check icon.
class _DoneButton extends StatelessWidget {
  const _DoneButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Done',
      button: true,
      child: GestureDetector(
        onTap: () => VideoTextEditorScope.of(context).editor.done(),
        child: Container(
          margin: const .all(4),
          padding: const .all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: .circular(16),
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: SvgPicture.asset(
              'assets/icon/Check.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                VineTheme.navGreen,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

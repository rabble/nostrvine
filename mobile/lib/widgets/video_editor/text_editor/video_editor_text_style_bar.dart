// ABOUTME: Style controls bar for text editor with color, alignment, background and font buttons.
// ABOUTME: Directly accesses VideoEditorTextBloc for state management.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Style controls bar for text editor.
///
/// Displays buttons for color, alignment, background style, and font selection.
/// Directly accesses [VideoEditorTextBloc] for state management and syncs
/// changes with the [TextEditorState] via [VideoTextEditorScope].
class VideoEditorTextStyleBar extends StatelessWidget {
  const VideoEditorTextStyleBar({super.key});

  void _toggleFontSelector(BuildContext context, VideoEditorTextState state) {
    _togglePanel(
      context: context,
      isOpen: state.showFontSelector,
      event: const VideoEditorTextFontSelectorToggled(),
    );
  }

  void _toggleColorPicker(BuildContext context, VideoEditorTextState state) {
    _togglePanel(
      context: context,
      isOpen: state.showColorPicker,
      event: const VideoEditorTextColorPickerToggled(),
    );
  }

  /// Toggles a panel (font selector or color picker) and manages
  /// keyboard focus.
  void _togglePanel({
    required BuildContext context,
    required bool isOpen,
    required VideoEditorTextEvent event,
  }) {
    final textEditor = VideoTextEditorScope.of(context).editor;

    if (isOpen) {
      // Closing panel - show keyboard again
      textEditor.focusNode.requestFocus();
    } else {
      // Opening panel - hide keyboard
      if (textEditor.focusNode.hasFocus) {
        textEditor.focusNode.unfocus();
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    }

    context.read<VideoEditorTextBloc>().add(event);
  }

  @override
  Widget build(BuildContext context) {
    final textEditor = VideoTextEditorScope.of(context).editor;

    return BlocBuilder<VideoEditorTextBloc, VideoEditorTextState>(
      buildWhen: (previous, current) =>
          previous.selectedFontIndex != current.selectedFontIndex ||
          previous.showFontSelector != current.showFontSelector ||
          previous.showColorPicker != current.showColorPicker ||
          previous.backgroundStyle != current.backgroundStyle ||
          previous.alignment != current.alignment ||
          previous.color != current.color,
      builder: (context, state) {
        return Padding(
          padding: const .fromLTRB(16, 0, 16, 16),
          child: Row(
            spacing: 16,
            mainAxisAlignment: .spaceBetween,
            children: [
              Row(
                spacing: 8,
                children: [
                  _ColorSwatchButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    semanticsLabel: 'Text color',
                    color: state.color,
                    onTap: () => _toggleColorPicker(context, state),
                  ),
                  _StyleIconButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    semanticsLabel: 'Text alignment',
                    semanticsValue: state.alignment.accessibilityName,
                    iconPath: state.alignment.icon,
                    onTap: textEditor.toggleTextAlign,
                  ),
                  _StyleIconButton(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    semanticsLabel: 'Text background',
                    semanticsValue: state.backgroundStyle.accessibilityName,
                    iconPath: state.backgroundStyle.icon,
                    onTap: textEditor.toggleBackgroundMode,
                  ),
                ],
              ),
              // Font selector button
              Flexible(
                child: _FontSelectorButton(
                  fontName: state.selectedFontName,
                  onTap: () => _toggleFontSelector(context, state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Color swatch button showing the current text color.
class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.semanticsLabel,
    required this.color,
    this.onTap,
  });

  final String semanticsLabel;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const .all(14),
          decoration: BoxDecoration(
            color: VineTheme.scrim65,
            borderRadius: .circular(20),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: .circle,
              border: .all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// A styled icon button for text styling controls.
class _StyleIconButton extends StatelessWidget {
  const _StyleIconButton({
    required this.semanticsLabel,
    required this.semanticsValue,
    required this.iconPath,
    this.onTap,
  });

  final String semanticsLabel;
  final String semanticsValue;
  final String iconPath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      value: semanticsValue,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const .all(12),
          decoration: BoxDecoration(
            color: const Color(0xA6000000),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
            colorFilter: const .mode(Colors.white, .srcIn),
          ),
        ),
      ),
    );
  }
}

/// Font selector button showing current font name with dropdown arrow.
class _FontSelectorButton extends StatelessWidget {
  const _FontSelectorButton({required this.fontName, this.onTap});

  final String fontName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Select font',
      value: fontName,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const .symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: VineTheme.scrim65,
            borderRadius: .circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0.4, 0.4),
                blurRadius: 0.6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: .min,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  fontName,
                  overflow: .ellipsis,
                  style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: SvgPicture.asset(
                  'assets/icon/CaretDown.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const .mode(VineTheme.onSurface, .srcIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

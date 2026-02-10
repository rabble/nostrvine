// ABOUTME: Inline font selector that replaces the keyboard.
// ABOUTME: Displays font options in a scrollable list matching keyboard height.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:openvine/widgets/video_editor/video_editor_blurred_panel.dart';

/// Inline font selector that replaces the keyboard.
///
/// Displays font options in a scrollable list, designed to match
/// the keyboard height for a smooth transition when toggling.
class VideoEditorTextFontSelector extends StatelessWidget {
  const VideoEditorTextFontSelector({super.key, this.onFontSelected});

  /// Callback when a font is selected. Receives the font's TextStyle.
  final ValueChanged<TextStyle>? onFontSelected;

  @override
  Widget build(BuildContext context) {
    final selectedFontIndex = context.select<VideoEditorTextBloc, int>(
      (bloc) => bloc.state.selectedFontIndex,
    );

    return VideoEditorBlurredPanel(
      child: ListView.builder(
        padding: const .symmetric(vertical: 16),
        itemCount: VideoEditorConstants.textFonts.length,
        itemBuilder: (context, index) {
          final font = VideoEditorConstants.textFonts[index];
          final isSelected = index == selectedFontIndex;
          return _FontListItem(
            font: font,
            isSelected: isSelected,
            onTap: () {
              // Apply font via callback
              onFontSelected?.call(font());

              // Update BLoC state
              context.read<VideoEditorTextBloc>().add(
                VideoEditorTextFontSelected(index),
              );
            },
          );
        },
      ),
    );
  }
}

/// Individual font list item.
class _FontListItem extends StatelessWidget {
  const _FontListItem({
    required this.font,
    required this.isSelected,
    required this.onTap,
  });

  final TextFont font;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Font',
      value: font.displayName,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const .symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  font.displayName,
                  overflow: .ellipsis,
                  style: font(
                    fontSize: 24,
                    color: isSelected ? Colors.white : const Color(0xB3FFFFFF),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, color: VineTheme.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

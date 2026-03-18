// ABOUTME: Instruction text widget for clip gallery
// ABOUTME: Animated fade and size transitions based on editing/reordering state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';

/// Instruction text that appears below the clip gallery.
///
/// Displays "Tap to edit. Hold and drag to reorder." with animated transitions
/// based on editing and reordering states.
class ClipGalleryInstructionText extends StatelessWidget {
  /// Creates clip gallery instruction text.
  const ClipGalleryInstructionText({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (ClipEditorBloc bloc) => (
        isEditing: bloc.state.isEditing,
        isReordering: bloc.state.isReordering,
      ),
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: 1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: state.isEditing
          ? const SizedBox.shrink()
          : AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: state.isReordering ? 0 : 1,
              child: Align(
                child: Padding(
                  padding: const .only(top: 25),
                  child: Text(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    'Tap to edit. Hold and drag to reorder.',
                    style: VineTheme.bodySmallFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
    );
  }
}

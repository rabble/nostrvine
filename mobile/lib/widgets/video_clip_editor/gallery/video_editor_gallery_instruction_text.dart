// ABOUTME: Instruction text widget for clip gallery
// ABOUTME: Animated fade and size transitions based on editing/reordering state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Instruction text that appears below the clip gallery.
///
/// Displays "Tap to edit. Hold and drag to reorder." with animated transitions
/// based on editing and reordering states.
class ClipGalleryInstructionText extends ConsumerWidget {
  /// Creates clip gallery instruction text.
  const ClipGalleryInstructionText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (isEditing: s.isEditing, isReordering: s.isReordering),
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
              child: const Align(
                child: Padding(
                  padding: .only(top: 25),
                  child: Text(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    'Tap to edit. Hold and drag to reorder.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      height: 1.33,
                      letterSpacing: 0.4,
                      fontSize: 12,
                      color: Color(0x80FFFFFF),
                    ),
                    textAlign: .center,
                  ),
                ),
              ),
            ),
    );
  }
}

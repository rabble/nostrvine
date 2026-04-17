// ABOUTME: Top bar with close, clip counter, and done buttons
// ABOUTME: Displays current clip position and total clip count

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Top bar with close button, clip counter, and done button.
class VideoClipEditorTopBar extends StatelessWidget {
  /// Creates a video editor top bar widget.
  const VideoClipEditorTopBar({super.key, this.fromLibrary = false});

  /// Whether the editor was opened from the clip library.
  final bool fromLibrary;

  @override
  Widget build(BuildContext context) {
    final (currentClipIndex, isEditing, isReordering, totalClips) = context
        .select(
          (ClipEditorBloc bloc) => (
            bloc.state.currentClipIndex,
            bloc.state.isEditing,
            bloc.state.isReordering,
            bloc.state.clips.length,
          ),
        );

    return Padding(
      padding: const .fromLTRB(10, 16, 16, 16),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: .centerLeft,
                child: isReordering
                    ? const SizedBox.shrink()
                    : DivineIconButton(
                        onPressed: isEditing
                            ? () => context.read<ClipEditorBloc>().add(
                                const ClipEditorEditingStopped(),
                              )
                            : context.pop,
                        icon: .x,
                        type: .ghostSecondary,
                      ),
              ),
            ),

            // Clip counter
            Text(
              '${currentClipIndex + 1}/$totalClips',
              style: GoogleFonts.bricolageGrotesque(
                color: VineTheme.whiteText,
                fontSize: 18,
                height: 1.33,
                letterSpacing: 0.15,
                fontWeight: .w800,
                fontFeatures: [const .tabularFigures()],
              ),
            ),

            Expanded(
              child: isEditing || isReordering
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: .centerRight,
                      child: DivineIconButton(
                        icon: .check,
                        semanticLabel:
                            context.l10n.videoEditorDoneSemanticLabel,
                        size: .small,
                        type: .tertiary,
                        onPressed: () {
                          final bloc = context.read<ClipEditorBloc>();
                          bloc.add(const ClipEditorPlaybackPaused());
                          context.pop(bloc.state.clips);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

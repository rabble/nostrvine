// ABOUTME: Top bar with close, clip counter, and done buttons
// ABOUTME: Displays current clip position and total clip count

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Top bar with close button, clip counter, and done button.
class VideoClipEditorTopBar extends ConsumerWidget {
  /// Creates a video editor top bar widget.
  const VideoClipEditorTopBar({super.key, this.fromLibrary = false});

  /// Whether the editor was opened from the clip library.
  final bool fromLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalClips = ref.watch(
      clipManagerProvider.select((state) => state.clips.length),
    );
    final (currentClipIndex, isEditing, isReordering) = context.select(
      (ClipEditorBloc bloc) => (
        bloc.state.currentClipIndex,
        bloc.state.isEditing,
        bloc.state.isReordering,
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
                    : isEditing
                    ? DivineIconButton(
                        onPressed: () => context.read<ClipEditorBloc>().add(
                          const ClipEditorEditingStopped(),
                        ),
                        icon: .x,
                        type: .ghostSecondary,
                      )
                    : DivineIconButton(
                        onPressed: context.pop,
                        icon: .caretLeft,
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
                      child: _NextButton(
                        onTap: () {
                          context.read<ClipEditorBloc>().add(
                            const ClipEditorPlaybackPaused(),
                          );
                          final notifier = ref.read(
                            videoEditorProvider.notifier,
                          );

                          unawaited(notifier.startRenderVideo());
                          // TODO(@hm21): Replace with VideoEditorScreen.path
                          Log.info(
                            '📤 Navigating to metadata screen',
                            name: 'VideoClipEditorTopBar',
                            category: .video,
                          );

                          context.push(VideoMetadataScreen.path);
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

class _NextButton extends StatelessWidget {
  const _NextButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Continue to metadata',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const .symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: VineTheme.whiteText,
            borderRadius: .circular(16),
            boxShadow: const [
              BoxShadow(
                color: VineTheme.innerShadow,
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
              BoxShadow(
                color: VineTheme.innerShadow,
                offset: Offset(0.4, 0.4),
                blurRadius: 0.6,
              ),
            ],
          ),
          child: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Next',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 18,
              fontWeight: .w800,
              height: 1.33,
              letterSpacing: 0.15,
              color: VineTheme.inverseOnSurface,
            ),
          ),
        ),
      ),
    );
  }
}

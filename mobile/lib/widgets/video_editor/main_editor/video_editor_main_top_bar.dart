// ABOUTME: Top toolbar for the video editor with navigation and history controls.
// ABOUTME: Contains close, undo, redo, and done buttons with BLoC integration.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_layer_reorder_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Top action bar for the video editor.
///
/// Displays close, undo, redo, and done buttons. Uses [BlocSelector] to
/// reactively enable/disable undo and redo based on editor state.
class VideoEditorMainTopBar extends ConsumerWidget {
  const VideoEditorMainTopBar({super.key});

  Future<void> _reorderLayers(BuildContext context, List<Layer> layers) async {
    await VineBottomSheet.show<void>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      title: const Text('Layers'),
      body: VideoEditorLayerReorderSheet(
        layers: layers,
        onReorder: (oldIndex, newIndex) {
          final scope = VideoEditorScope.of(context);
          assert(
            scope.editor != null,
            'Editor must be active to reorder layers',
          );
          scope.editor!.moveLayerListPosition(
            oldIndex: oldIndex,
            newIndex: newIndex,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideoReply = ref.watch(videoReplyContextProvider) != null;

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child:
              BlocSelector<
                VideoEditorMainBloc,
                VideoEditorMainState,
                ({bool canUndo, bool canRedo, List<Layer> layers})
              >(
                selector: (state) => (
                  canUndo: state.canUndo,
                  canRedo: state.canRedo,
                  layers: state.layers,
                ),
                builder: (context, state) {
                  final scope = VideoEditorScope.of(context);

                  return Row(
                    spacing: 8,
                    children: [
                      DivineIconButton(
                        size: DivineIconButtonSize.small,
                        type: DivineIconButtonType.ghostSecondary,
                        semanticLabel: 'Close',
                        icon: DivineIconName.caretLeft,
                        onPressed: () {
                          final bloc = context.read<VideoEditorMainBloc>();
                          if (bloc.state.isSubEditorOpen) {
                            scope.editor?.closeSubEditor();
                          } else {
                            context.pop();
                          }
                        },
                      ),
                      const Spacer(),
                      DivineIconButton(
                        size: DivineIconButtonSize.small,
                        type: DivineIconButtonType.ghostSecondary,
                        semanticLabel: 'Undo',
                        icon: DivineIconName.arrowArcLeft,
                        onPressed: state.canUndo
                            ? () => scope.editor?.undoAction()
                            : null,
                      ),
                      DivineIconButton(
                        size: DivineIconButtonSize.small,
                        type: DivineIconButtonType.ghostSecondary,
                        semanticLabel: 'Redo',
                        icon: DivineIconName.arrowArcRight,
                        onPressed: state.canRedo
                            ? () => scope.editor?.redoAction()
                            : null,
                      ),
                      const Spacer(),
                      DivineIconButton(
                        size: DivineIconButtonSize.small,
                        type: DivineIconButtonType.ghostSecondary,
                        semanticLabel: 'Reorder',
                        icon: DivineIconName.stackSimple,
                        onPressed: state.layers.length > 1
                            ? () => _reorderLayers(
                                context,
                                scope.editor?.activeLayers ?? state.layers,
                              )
                            : null,
                      ),
                      if (isVideoReply)
                        _PostReplyButton(
                          onTap: () => scope.editor?.doneEditing(),
                        )
                      else
                        DivineIconButton(
                          size: DivineIconButtonSize.small,
                          type: DivineIconButtonType.ghostSecondary,
                          semanticLabel: 'Done',
                          icon: DivineIconName.check,
                          onPressed: () => scope.editor?.doneEditing(),
                        ),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}

class _PostReplyButton extends StatelessWidget {
  const _PostReplyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: VineTheme.vineGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Post Reply',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: VineTheme.whiteText,
          ),
        ),
      ),
    );
  }
}

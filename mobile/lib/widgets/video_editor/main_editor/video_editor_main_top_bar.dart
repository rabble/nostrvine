// ABOUTME: Top toolbar for the video editor with navigation and history controls.
// ABOUTME: Contains close, undo, redo, and done buttons with BLoC integration.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_layer_reorder_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Top action bar for the video editor.
///
/// Displays close, undo, redo, and done buttons. Uses [BlocSelector] to
/// reactively enable/disable undo and redo based on editor state.
class VideoEditorMainTopBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                        size: .small,
                        type: .ghostSecondary,
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Close',
                        icon: .caretLeft,
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
                        size: .small,
                        type: .ghostSecondary,
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Undo',
                        icon: .arrowArcLeft,
                        onPressed: state.canUndo
                            ? () => scope.editor?.undoAction()
                            : null,
                      ),
                      DivineIconButton(
                        size: .small,
                        type: .ghostSecondary,
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Redo',
                        icon: .arrowArcRight,
                        onPressed: state.canRedo
                            ? () => scope.editor?.redoAction()
                            : null,
                      ),
                      const Spacer(),
                      DivineIconButton(
                        size: .small,
                        type: .ghostSecondary,
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Reorder',
                        icon: .stackSimple,
                        onPressed: state.layers.length > 1
                            ? () => _reorderLayers(
                                context,
                                scope.editor?.activeLayers ?? state.layers,
                              )
                            : null,
                      ),
                      DivineIconButton(
                        size: .small,
                        type: .ghostSecondary,
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticLabel: 'Done',
                        icon: .check,
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

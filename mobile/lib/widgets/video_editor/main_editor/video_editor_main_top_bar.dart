// ABOUTME: Top toolbar for the video editor with navigation and history controls.
// ABOUTME: Contains close, undo, redo, and done buttons with BLoC integration.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
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
                      _IconButton(
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticsLabel: 'Close',
                        iconPath: 'assets/icon/CaretLeft.svg',
                        onTap: () {
                          final bloc = context.read<VideoEditorMainBloc>();
                          if (bloc.state.isSubEditorOpen) {
                            scope.editor?.closeSubEditor();
                          } else {
                            context.pop();
                          }
                        },
                      ),
                      const Spacer(),
                      _IconButton(
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticsLabel: 'Undo',
                        iconPath: 'assets/icon/arrow_arc_left.svg',
                        onTap: state.canUndo
                            ? () => scope.editor?.undoAction()
                            : null,
                      ),
                      _IconButton(
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticsLabel: 'Redo',
                        iconPath: 'assets/icon/arrow_arc_right.svg',
                        onTap: state.canRedo
                            ? () => scope.editor?.redoAction()
                            : null,
                      ),
                      const Spacer(),
                      _IconButton(
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticsLabel: 'Reorder',
                        iconPath: 'assets/icon/stack_simple.svg',
                        onTap: state.layers.length > 1
                            ? () => _reorderLayers(
                                context,
                                scope.editor?.activeLayers ?? state.layers,
                              )
                            : null,
                      ),
                      _IconButton(
                        // TODO(l10n): Replace with context.l10n when localization is added.
                        semanticsLabel: 'Done',
                        iconPath: 'assets/icon/Check.svg',
                        onTap: () => scope.editor?.doneEditing(),
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

// TODO(@hm21): Once the design decision has been made regarding what the
// buttons will look like, create them in the divine_ui package and reuse them.

/// A styled icon button for the top bar with accessibility support.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.semanticsLabel,
    required this.iconPath,
    required this.onTap,
  });

  /// Accessibility label for screen readers.
  final String semanticsLabel;

  /// Path to the SVG icon asset.
  final String iconPath;

  /// Callback when tapped, or `null` to disable the button.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: isEnabled,
      child: Opacity(
        opacity: isEnabled ? 1 : 0.32,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const .all(8),
            decoration: BoxDecoration(
              color: const Color(0x25000000),
              borderRadius: .circular(16),
            ),
            child: SizedBox(
              height: 24,
              width: 24,
              child: SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: const .mode(Colors.white, .srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

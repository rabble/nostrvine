// ABOUTME: Top toolbar for the video editor with navigation and history controls.
// ABOUTME: Contains close, undo, redo, done, and audio buttons with BLoC integration.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_chip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_layer_reorder_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Top action bar for the video editor.
///
/// Displays close, undo, redo, audio, and done buttons. Uses [BlocSelector] to
/// reactively enable/disable undo and redo based on editor state.
class VideoEditorMainOverlayActions extends StatelessWidget {
  const VideoEditorMainOverlayActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isHidden = context.select(
      (VideoEditorMainBloc b) => b.state.openSubEditor == .music,
    );

    return IgnorePointer(
      ignoring: isHidden,
      child: AnimatedOpacity(
        opacity: isHidden ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: const SafeArea(
          child: Stack(
            fit: .expand,
            children: [
              Align(alignment: .topCenter, child: _TopActions()),
              Align(alignment: .bottomCenter, child: _BottomActions()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top row actions: close, audio chip, and done buttons.
class _TopActions extends ConsumerWidget {
  const _TopActions();

  void _onSoundChanged(BuildContext context, WidgetRef ref, AudioEvent? sound) {
    ref.read(videoEditorProvider.notifier).selectSound(sound);
    // Restart playback when sound changes
    context.read<VideoEditorMainBloc>().add(
      const VideoEditorPlaybackRestartRequested(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = VideoEditorScope.of(context);
    final selectedSound = ref.watch(
      videoEditorProvider.select((s) => s.selectedSound),
    );

    return VideoEditorToolbar(
      closeIcon: .caretLeft,
      doneIcon: .caretRight,
      onClose: () {
        final bloc = context.read<VideoEditorMainBloc>();
        if (bloc.state.isSubEditorOpen) {
          scope.editor?.closeSubEditor();
        } else {
          context.pop();
        }
      },
      onDone: () => scope.editor?.doneEditing(),
      center: Flexible(
        child: VideoEditorAudioChip(
          selectedSound: selectedSound,
          onSoundChanged: (sound) => _onSoundChanged(context, ref, sound),
          onSelectionStarted: () {
            context.read<VideoEditorMainBloc>()
              ..add(const VideoEditorMainOpenSubEditor(.music))
              ..add(
                const VideoEditorExternalPauseRequested(isPaused: true),
              );
          },
          onSelectionEnded: () {
            context.read<VideoEditorMainBloc>()
              ..add(const VideoEditorMainSubEditorClosed())
              ..add(
                const VideoEditorExternalPauseRequested(isPaused: false),
              );
          },
        ),
      ),
    );
  }
}

/// Bottom row actions: reorder, undo, redo, and play/pause buttons.
class _BottomActions extends StatelessWidget {
  const _BottomActions();

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
    final scope = VideoEditorScope.of(context);

    return Padding(
      padding: const .fromLTRB(16, 0, 16, 16),
      child:
          BlocSelector<
            VideoEditorMainBloc,
            VideoEditorMainState,
            ({
              bool canUndo,
              bool canRedo,
              List<Layer> layers,
              bool isPlaying,
              bool isPlayerReady,
            })
          >(
            selector: (state) => (
              canUndo: state.canUndo,
              canRedo: state.canRedo,
              layers: state.layers,
              isPlaying: state.isPlaying,
              isPlayerReady: state.isPlayerReady,
            ),
            builder: (context, state) {
              return Row(
                spacing: 8,
                children: [
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: !state.isPlayerReady
                        ? Container(
                            width: 40,
                            height: 40,
                            padding: const .all(10),
                            decoration: BoxDecoration(
                              color: VineTheme.scrim15,
                              borderRadius: .circular(16),
                            ),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                VineTheme.whiteText,
                              ),
                            ),
                          )
                        : DivineIconButton(
                            size: .small,
                            type: .ghostSecondary,
                            // TODO(l10n): Replace with context.l10n when localization is added.
                            semanticLabel: state.isPlaying ? 'Pause' : 'Play',
                            icon: state.isPlaying ? .pause : .play,
                            onPressed: () {
                              context.read<VideoEditorMainBloc>().add(
                                const VideoEditorPlaybackToggleRequested(),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
    );
  }
}

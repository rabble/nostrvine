// ABOUTME: Top toolbar for the video editor with navigation and history controls.
// ABOUTME: Contains close, undo, redo, done, and audio buttons with BLoC integration.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
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
        child: const Stack(
          fit: .expand,
          children: [
            _PlayStateIndicator(),
            Align(alignment: .topCenter, child: _TopActions()),
            Align(alignment: .bottomCenter, child: _BottomActions()),
          ],
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
          // If came from library, go to recorder (not in stack)
          // Otherwise pop back to recorder
          if (scope.fromLibrary) {
            context.pushReplacement(VideoRecorderScreen.path);
          } else {
            context.pop();
          }
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

/// Bottom row actions: reorder layers.
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

    return SafeArea(
      child: Padding(
        padding: const .fromLTRB(16, 0, 16, 16),
        child: BlocSelector<VideoEditorMainBloc, VideoEditorMainState, List<Layer>>(
          selector: (state) => state.layers,
          builder: (context, layers) {
            return DivineIconButton(
              size: .small,
              type: .ghostSecondary,
              // TODO(l10n): Replace with context.l10n when localization is added.
              semanticLabel: 'Reorder',
              icon: .stackSimple,
              onPressed: layers.length > 1
                  ? () => _reorderLayers(
                      context,
                      scope.editor?.activeLayers ?? layers,
                    )
                  : null,
            );
          },
        ),
      ),
    );
  }
}

/// Center play/pause button overlay.
///
/// Fades out the pause icon after 1 second of playback so it doesn't
/// permanently obstruct the video preview.
class _PlayStateIndicator extends StatefulWidget {
  const _PlayStateIndicator();

  @override
  State<_PlayStateIndicator> createState() => _PlayStateIndicatorState();
}

class _PlayStateIndicatorState extends State<_PlayStateIndicator> {
  static const double _iconSize = 32;
  static const _hideDelay = Duration(seconds: 1);

  Timer? _hideTimer;
  final _iconVisible = ValueNotifier<bool>(false);
  bool _didSyncInitialState = false;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _iconVisible.dispose();
    super.dispose();
  }

  void _onPlayingChanged({required bool isPlaying}) {
    _hideTimer?.cancel();

    // Suppress the indicator on the very first play transition,
    // which is the auto-play when the editor opens.
    if (!_didSyncInitialState) {
      _didSyncInitialState = true;
      if (isPlaying) return;
    }

    if (isPlaying) {
      _iconVisible.value = true;
      _hideTimer = Timer(_hideDelay, () {
        if (mounted) _iconVisible.value = false;
      });
    } else {
      _iconVisible.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: BlocConsumer<VideoEditorMainBloc, VideoEditorMainState>(
        listenWhen: (prev, curr) => prev.isPlaying != curr.isPlaying,
        listener: (_, state) => _onPlayingChanged(isPlaying: state.isPlaying),
        buildWhen: (prev, curr) =>
            prev.isPlaying != curr.isPlaying ||
            prev.isPlayerReady != curr.isPlayerReady,
        builder: (context, state) {
          final isPlaying = state.isPlaying;
          final isPlayerReady = state.isPlayerReady;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: .center,
              fit: .expand,
              children: <Widget>[...previousChildren, ?currentChild],
            ),
            child: isPlayerReady
                ? Center(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _iconVisible,
                      builder: (_, visible, child) => AnimatedOpacity(
                        opacity: visible ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: child,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: VineTheme.scrim65,
                          borderRadius: .circular(24),
                        ),
                        padding: const .all(16),
                        child: DivineIcon(
                          icon: isPlaying ? .pauseFill : .playFill,
                          size: _iconSize,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

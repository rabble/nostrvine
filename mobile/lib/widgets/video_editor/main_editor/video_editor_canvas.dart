// ABOUTME: Canvas widget wrapping ProImageEditor for the video editor.
// ABOUTME: Handles layer manipulation callbacks and editor configuration.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:pro_image_editor/core/models/editor_callbacks/pro_image_editor_callbacks.dart';
import 'package:pro_image_editor/core/models/editor_configs/pro_image_editor_configs.dart';
import 'package:pro_image_editor/core/models/editor_configs/utils/editor_safe_area.dart';
import 'package:pro_image_editor/features/main_editor/main_editor.dart';

/// The main canvas area for the video editor.
///
/// Wraps [ProImageEditor] and configures it for video editing with custom
/// styling and callbacks that dispatch events to [VideoEditorMainBloc].
class VideoEditorCanvas extends ConsumerWidget {
  /// Creates a [VideoEditorCanvas].
  VideoEditorCanvas({
    required this.editorKey,
    required this.constraints,
    super.key,
  });

  /// Global key to access the [ProImageEditorState].
  final GlobalKey<ProImageEditorState> editorKey;

  /// Layout constraints from the parent to size the editor.
  final BoxConstraints constraints;

  final _configs = ProImageEditorConfigs(
    mainEditor: MainEditorConfigs(
      safeArea: const EditorSafeArea(
        left: false,
        top: false,
        right: false,
        bottom: false,
      ),
      style: const MainEditorStyle(background: VineTheme.surfaceContainerHigh),
      widgets: MainEditorWidgets(
        appBar: (_, _) => null,
        bottomBar: (_, __, ___) => null,
        removeLayerArea: (key, _, __, ___) => SizedBox.shrink(key: key),
      ),
    ),
    helperLines: const HelperLineConfigs(
      style: HelperLineStyle(
        horizontalColor: Color(0xFFFFF140),
        verticalColor: Color(0xFFFFF140),
        rotateColor: Color(0xFFFFF140),
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bloc = context.read<VideoEditorMainBloc>();
    final clip = ref.watch(clipManagerProvider.select((s) => s.clips.first));

    return FittedBox(
      fit: .cover,
      clipBehavior: .none,
      child: SizedBox(
        width: constraints.maxHeight / clip.targetAspectRatio.value,
        height: constraints.maxHeight,
        // TODO(@hm21): Replace with ProImageEditor.video(
        child: ProImageEditor.file(
          clip.thumbnailPath,
          key: editorKey,
          configs: _configs,
          callbacks: ProImageEditorCallbacks(
            onCompleteWithParameters: (parameters) async {
              // TODO(@hm21): Handle result
              debugPrint(parameters.toString());
            },
            mainEditorCallbacks: MainEditorCallbacks(
              onStateHistoryChange: (stateHistory, editor) {
                bloc.add(
                  VideoEditorMainCapabilitiesChanged(
                    canUndo: editor.canUndo,
                    canRedo: editor.canRedo,
                    isSubEditorOpen: editor.isSubEditorOpen,
                  ),
                );
                // TODO(@hm21): Store state history
              },
              onScaleStart: (_) =>
                  bloc.add(const VideoEditorLayerInteractionStarted()),
              onScaleEnd: (_) =>
                  bloc.add(const VideoEditorLayerInteractionEnded()),
            ),
          ),
        ),
      ),
    );
  }
}

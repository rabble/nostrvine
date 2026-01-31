// ABOUTME: Canvas widget wrapping ProImageEditor for the video editor.
// ABOUTME: Handles layer manipulation callbacks and editor configuration.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
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
  const VideoEditorCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bloc = context.read<VideoEditorMainBloc>();
    final clip = ref.watch(clipManagerProvider.select((s) => s.clips.first));
    final scope = VideoEditorScope.of(context);

    final isSubEditorOpen = context.select(
      (VideoEditorMainBloc b) => b.state.isSubEditorOpen,
    );

    return PopScope(
      canPop: !isSubEditorOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          scope.editor?.closeSubEditor();
          bloc.add(const VideoEditorMainSubEditorClosed());
        }
      },

      // Wraps sub-editors in a nested Navigator so they open within the fitted
      // aspect-ratio area instead of full-screen, since cropping hasn't been
      // applied yet.
      child: Navigator(
        onGenerateRoute: (_) {
          return PageRouteBuilder(
            pageBuilder: (_, _, _) => ProImageEditor.file(
              clip.thumbnailPath,
              key: scope.editorKey,

              /// TODO(@hm21): Once all subeditors have been implemented,
              /// separate the configs/callbacks for better readability.
              configs: ProImageEditorConfigs(
                mainEditor: MainEditorConfigs(
                  safeArea: const EditorSafeArea.none(),
                  style: const MainEditorStyle(
                    background: VineTheme.surfaceContainerHigh,
                  ),
                  widgets: MainEditorWidgets(
                    appBar: (_, _) => null,
                    bottomBar: (_, _, key) => null,
                    removeLayerArea: (key, _, _, _) =>
                        SizedBox.shrink(key: key),
                  ),
                ),
                filterEditor: FilterEditorConfigs(
                  safeArea: const EditorSafeArea.none(),
                  enableMultiSelection: false,
                  widgets: FilterEditorWidgets(
                    appBar: (_, _) => null,
                    bottomBar: (_, _) => null,
                  ),
                ),
                helperLines: const HelperLineConfigs(
                  style: HelperLineStyle(
                    horizontalColor: Color(0xFFFFF140),
                    verticalColor: Color(0xFFFFF140),
                    rotateColor: Color(0xFFFFF140),
                    layerAlignColor: Color(0xFFFFF140),
                  ),
                ),
              ),
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
                      ),
                    );
                    // TODO(@hm21): Store state history
                  },
                  onOpenSubEditor: (editorMode) {
                    final SubEditorType? subEditorType = switch (editorMode) {
                      .paint => .paint,
                      .text => .text,
                      .filter => .filter,
                      .sticker => .stickers,
                      _ => null,
                    };
                    if (subEditorType != null) {
                      bloc.add(VideoEditorMainOpenSubEditor(subEditorType));
                    }
                  },
                  onStartCloseSubEditor: (_) =>
                      bloc.add(const VideoEditorMainSubEditorClosed()),
                  onScaleStart: (_) =>
                      bloc.add(const VideoEditorLayerInteractionStarted()),
                  onScaleEnd: (_) =>
                      bloc.add(const VideoEditorLayerInteractionEnded()),
                ),
                filterEditorCallbacks: FilterEditorCallbacks(
                  onInit: () {
                    final filterBloc = context.read<VideoEditorFilterBloc>();
                    filterBloc.add(const VideoEditorFilterEditorInitialized());
                    final filterState = filterBloc.state;

                    // Sync editor with current BLoC state
                    final filterEditor = scope.filterEditor;
                    if (filterState.selectedFilter != null) {
                      filterEditor?.setFilter(filterState.selectedFilter!);
                    }
                    filterEditor?.setFilterOpacity(filterState.opacity);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

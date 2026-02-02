// ABOUTME: Canvas widget wrapping ProImageEditor for the video editor.
// ABOUTME: Handles layer manipulation callbacks and editor configuration.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The main canvas area for the video editor.
///
/// Wraps [ProImageEditor] and configures it for video editing with custom
/// styling and callbacks that dispatch events to [VideoEditorMainBloc].
class VideoEditorCanvas extends ConsumerStatefulWidget {
  /// Creates a [VideoEditorCanvas].
  const VideoEditorCanvas({super.key});

  @override
  ConsumerState<VideoEditorCanvas> createState() => _VideoEditorCanvasState();
}

class _VideoEditorCanvasState extends ConsumerState<VideoEditorCanvas> {
  bool _isInitialized = false;
  bool _isImportingHistory = false;
  bool _hasImportedHistory = false;

  /// Syncs the main-editor capabilities from the main editor to the bloc.
  void _syncMainCapabilities(VideoEditorScope scope, VideoEditorMainBloc bloc) {
    final editor = scope.editor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bloc.add(
        VideoEditorMainCapabilitiesChanged(
          canUndo: editor?.canUndo ?? false,
          canRedo: editor?.canRedo ?? false,
        ),
      );
    });
  }

  /// Syncs the draw capabilities from the paint editor to the bloc.
  void _syncDrawCapabilities(VideoEditorScope scope, VideoEditorDrawBloc bloc) {
    final paintEditor = scope.paintEditor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bloc.add(
        VideoEditorDrawCapabilitiesChanged(
          canUndo: paintEditor?.canUndo ?? false,
          canRedo: paintEditor?.canRedo ?? false,
        ),
      );
    });
  }

  /// Handles state history changes and exports the history to the provider.
  Future<void> _onStateHistoryChange(
    VideoEditorScope scope,
    VideoEditorMainBloc bloc,
  ) async {
    if (_isImportingHistory || !_isInitialized) return;

    _syncMainCapabilities(scope, bloc);
    final result = await scope.editor!.exportStateHistory(
      configs: ExportEditorConfigs(historySpan: .currentAndBackward),
    );
    final history = await result.toMap();

    ref.read(videoEditorProvider.notifier).updateEditorStateHistory(history);
  }

  @override
  Widget build(BuildContext context) {
    // BLOCs
    final bloc = context.read<VideoEditorMainBloc>();
    final drawBloc = context.read<VideoEditorDrawBloc>();
    final isSubEditorOpen = context.select(
      (VideoEditorMainBloc b) => b.state.isSubEditorOpen,
    );

    // Riverpod
    final clip = ref.watch(clipManagerProvider.select((s) => s.clips.first));
    final editorStateHistory = ref.read(
      videoEditorProvider.select((s) => s.editorStateHistory),
    );

    final scope = VideoEditorScope.of(context);

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
                stateHistory:
                    !_hasImportedHistory && editorStateHistory.isNotEmpty
                    ? StateHistoryConfigs(
                        initStateHistory: ImportStateHistory.fromMap(
                          editorStateHistory,
                        ),
                      )
                    : const StateHistoryConfigs(),
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
                paintEditor: PaintEditorConfigs(
                  safeArea: const EditorSafeArea.none(),
                  widgets: PaintEditorWidgets(
                    appBar: (_, _) => null,
                    bottomBar: (_, _) => null,
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
                    horizontalColor: VideoEditorConstants.primaryColor,
                    verticalColor: VideoEditorConstants.primaryColor,
                    rotateColor: VideoEditorConstants.primaryColor,
                    layerAlignColor: VideoEditorConstants.primaryColor,
                  ),
                ),
                dialogConfigs: DialogConfigs(
                  widgets: DialogWidgets(
                    loadingDialog: (message, configs) => SizedBox.shrink(),
                  ),
                ),
              ),
              callbacks: ProImageEditorCallbacks(
                onCloseEditor: (editorMode) {
                  if (editorMode == .main) context.pop();
                },
                onCompleteWithParameters: (parameters) async {
                  ref
                      .read(videoEditorProvider.notifier)
                      .updateEditorEditingParameters(parameters.toMap());
                },
                mainEditorCallbacks: MainEditorCallbacks(
                  onAfterViewInit: () {
                    _isInitialized = true;
                    _hasImportedHistory = true;
                    _syncMainCapabilities(scope, bloc);
                  },
                  onImportHistoryStart: (state, import) =>
                      _isImportingHistory = true,
                  onImportHistoryEnd: (state, import) {
                    _isImportingHistory = false;
                    _syncMainCapabilities(scope, bloc);
                  },
                  onStateHistoryChange: (_, _) =>
                      _onStateHistoryChange(scope, bloc),
                  onLayerTapUp: (_) => _onStateHistoryChange(scope, bloc),
                  onOpenSubEditor: (editorMode) {
                    final SubEditorType? subEditorType = switch (editorMode) {
                      .paint => .draw,
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
                paintEditorCallbacks: PaintEditorCallbacks(
                  onInit: () {
                    drawBloc.add(const VideoEditorDrawReset());

                    final paintEditor = scope.paintEditor;
                    final drawState = context.read<VideoEditorDrawBloc>().state;
                    // Sync editor with current BLoC state
                    paintEditor
                      ?..setColor(drawState.selectedColor)
                      ..setStrokeWidth(drawState.strokeWidth)
                      ..setOpacity(drawState.opacity)
                      ..setMode(drawState.mode);
                  },
                  onDrawingDone: () => _syncDrawCapabilities(scope, drawBloc),
                  onRedo: () => _syncDrawCapabilities(scope, drawBloc),
                  onUndo: () => _syncDrawCapabilities(scope, drawBloc),
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

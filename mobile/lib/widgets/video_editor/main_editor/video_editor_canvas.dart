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
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_player.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';
import 'package:openvine/utils/unified_logger.dart';
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
  @override
  Widget build(BuildContext context) {
    // BLOCs
    final isSubEditorOpen = context.select(
      (VideoEditorMainBloc b) => b.state.isSubEditorOpen,
    );

    // Riverpod
    final clip = ref.watch(clipManagerProvider.select((s) => s.clips.first));

    final scope = VideoEditorScope.of(context);

    return PopScope(
      canPop: !isSubEditorOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          scope.editor?.closeSubEditor();
          final bloc = context.read<VideoEditorMainBloc>();
          bloc.add(const VideoEditorMainSubEditorClosed());
        }
      },
      child: Padding(
        padding: const .only(bottom: VideoEditorConstants.bottomBarHeight),
        child: LayoutBuilder(
          builder: (_, constraints) {
            return FittedBox(
              fit: .cover,
              child: SizedBox(
                width:
                    constraints.biggest.height / clip.targetAspectRatio.value,
                height: constraints.biggest.height,
                // Wraps sub-editors in a nested Navigator so they open within
                // the fitted aspect-ratio area instead of full-screen, since
                // cropping hasn't been applied yet.
                child: Navigator(
                  clipBehavior: .none,
                  onGenerateRoute: (_) {
                    return PageRouteBuilder(
                      pageBuilder: (_, _, _) =>
                          _VideoEditor(constraints: constraints),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VideoEditor extends ConsumerStatefulWidget {
  const _VideoEditor({required this.constraints});

  final BoxConstraints constraints;

  @override
  ConsumerState<_VideoEditor> createState() => _VideoEditorState();
}

class _VideoEditorState extends ConsumerState<_VideoEditor> {
  static const _renderTaskId = 'diVine_Editor_Merger';

  late final ProVideoController _proVideoController;
  final _isPlayerReadyNotifier = ValueNotifier<bool>(false);
  VideoPlayerController? _videoPlayer;

  bool _isInitialized = false;
  bool _isImportingHistory = false;
  bool _hasImportedHistory = false;

  bool get _isLayerBeingTransformed => _selectedLayer != null;

  Layer? _selectedLayer;

  @override
  void initState() {
    super.initState();
    Log.info(
      '🎬 Canvas initialized',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    _initializePlayer();
  }

  @override
  void dispose() {
    Log.info(
      '🎬 Canvas disposed',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    _videoPlayer?.dispose();
    _isPlayerReadyNotifier.dispose();
    ProVideoEditor.instance.cancel(_renderTaskId);
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    Log.debug(
      '🎬 Initializing video player',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    _proVideoController = ProVideoController(
      videoPlayer: ValueListenableBuilder(
        valueListenable: _isPlayerReadyNotifier,
        builder: (_, isPlayerReady, _) {
          return VideoEditorPlayer(
            isPlayerReady: isPlayerReady,
            controller: _videoPlayer,
          );
        },
      ),
      initialResolution: widget.constraints.biggest,
      // These values are not used since we provide a custom-UI.
      fileSize: 0,
      videoDuration: .zero,
    );

    final clips = ref.read(clipManagerProvider).clips;
    final outputPath = await VideoEditorRenderService.renderVideo(
      taskId: _renderTaskId,
      clips: clips,
    );

    _videoPlayer = VideoPlayerController.file(File(outputPath!));

    await _videoPlayer!.initialize();
    if (!mounted) return;
    await _videoPlayer!.seekTo(clips.first.thumbnailTimestamp);
    // Wait for the video player to actually reach the seek position.
    // The player doesn't seek instantly, it usually takes just a few
    // milliseconds, but we use a slightly higher value to be safe.
    // In the worst case, the user might see a quick frame jump.
    await Future.delayed(Duration(milliseconds: 200));
    if (!mounted) return;
    await _videoPlayer!.setLooping(true);
    if (!mounted) return;
    await _videoPlayer!.play();
    if (!mounted) return;
    _isPlayerReadyNotifier.value = true;
    Log.info(
      '🎬 Video player ready',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
  }

  /// Syncs the main-editor capabilities from the main editor to the bloc.
  void _syncMainCapabilities(VideoEditorScope scope, VideoEditorMainBloc bloc) {
    final editor = scope.editor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bloc.add(
        VideoEditorMainCapabilitiesChanged(
          canUndo: editor?.canUndo ?? false,
          canRedo: editor?.canRedo ?? false,
          layers: editor?.activeLayers,
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
      configs: const ExportEditorConfigs(historySpan: .currentAndBackward),
    );
    final history = await result.toMap();

    ref.read(videoEditorProvider.notifier).updateEditorStateHistory(history);
  }

  /// Handles the completion of the image editor with parameters.
  ///
  /// Precaches the generated image overlay and triggers video rendering.
  Future<void> _handleEditorComplete(CompleteParameters parameters) async {
    Log.info(
      '🎬 Editor complete - starting render (image size: ${parameters.image.length} bytes)',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    final notifier = ref.read(videoEditorProvider.notifier);
    if (parameters.image.isNotEmpty) {
      try {
        await precacheImage(MemoryImage(parameters.image), context);
      } catch (e) {
        Log.warning(
          '🎬 Precache failed, continuing anyway: $e',
          name: 'VideoEditorCanvas',
          category: LogCategory.video,
        );
      }
    }
    notifier.updateEditorEditingParameters(parameters);
    notifier.startRenderVideo();
  }

  /// Handles the done action from the main editor.
  ///
  /// Pauses video, marks processing state, navigates to metadata screen,
  /// and resumes video when returning.
  Future<void> _handleDone() async {
    Log.info(
      '🎬 Done pressed - navigating to metadata screen',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    _videoPlayer?.pause();
    ref.read(videoEditorProvider.notifier).setProcessing(true);
    await context.push(VideoMetadataScreen.path);
    if (mounted) _videoPlayer?.play();
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final scope = VideoEditorScope.of(context);

    // BLOCs
    final bloc = context.read<VideoEditorMainBloc>();
    final drawBloc = context.read<VideoEditorDrawBloc>();

    // Riverpod
    final editorStateHistory = ref.read(
      videoEditorProvider.select((s) => s.editorStateHistory),
    );

    return ProImageEditor.video(
      _proVideoController,
      key: scope.editorKey,

      /// TODO(@hm21): Once all subeditors have been implemented,
      /// separate the configs/callbacks for better readability.
      configs: ProImageEditorConfigs(
        stateHistory: !_hasImportedHistory && editorStateHistory.isNotEmpty
            ? StateHistoryConfigs(
                initStateHistory: ImportStateHistory.fromMap(
                  editorStateHistory,
                ),
              )
            : const StateHistoryConfigs(),
        imageGeneration: ImageGenerationConfigs(
          captureImageByteFormat: .rawStraightRgba,
          customPixelRatio: devicePixelRatio,
        ),
        mainEditor: MainEditorConfigs(
          safeArea: const EditorSafeArea.none(),
          style: const MainEditorStyle(
            uiOverlayStyle: VideoEditorConstants.uiOverlayStyle,
            background: VineTheme.surfaceContainerHigh,
          ),
          widgets: MainEditorWidgets(
            appBar: (_, _) => null,
            bottomBar: (_, _, key) => null,
            removeLayerArea: (key, _, _, _) => SizedBox.shrink(key: key),
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
        videoEditor: VideoEditorConfigs(
          showControls: false,
          widgets: VideoEditorWidgets(
            videoSetupLoadingIndicator: Center(
              child: ClipRRect(
                borderRadius: .all(.circular(32)),
                child: SizedBox.fromSize(
                  size: widget.constraints.biggest,
                  child: VideoEditorThumbnail(constraints: widget.constraints),
                ),
              ),
            ),
          ),
        ),
      ),
      callbacks: ProImageEditorCallbacks(
        onCompleteWithParameters: _handleEditorComplete,
        mainEditorCallbacks: MainEditorCallbacks(
          onAfterViewInit: () {
            _isInitialized = true;
            _hasImportedHistory = true;
            _syncMainCapabilities(scope, bloc);
          },
          onDone: _handleDone,
          onImportHistoryStart: (state, import) {
            Log.debug(
              '🎬 Importing history started',
              name: 'VideoEditorCanvas',
              category: LogCategory.video,
            );
            _isImportingHistory = true;
          },
          onImportHistoryEnd: (state, import) {
            Log.debug(
              '🎬 Importing history completed',
              name: 'VideoEditorCanvas',
              category: LogCategory.video,
            );
            _isImportingHistory = false;
            _syncMainCapabilities(scope, bloc);
          },
          onStateHistoryChange: (_, _) => _onStateHistoryChange(scope, bloc),
          onOpenSubEditor: (editorMode) {
            Log.debug(
              '🎬 Opening sub-editor: $editorMode',
              name: 'VideoEditorCanvas',
              category: LogCategory.video,
            );
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
          onStartCloseSubEditor: (_) {
            Log.debug(
              '🎬 Closing sub-editor',
              name: 'VideoEditorCanvas',
              category: LogCategory.video,
            );
            bloc.add(const VideoEditorMainSubEditorClosed());
          },
          onScaleStart: (_) {
            Log.debug(
              '🎬 Layer interaction started',
              name: 'VideoEditorCanvas',
              category: LogCategory.video,
            );
            bloc.add(const VideoEditorLayerInteractionStarted());
            _selectedLayer = scope.editor?.selectedLayer;
          },
          onScaleUpdate: (details) {
            if (!_isLayerBeingTransformed) return;
            final isOverRemoveArea = scope.isOverRemoveArea(details.focalPoint);
            bloc.add(
              VideoEditorLayerOverRemoveAreaChanged(isOver: isOverRemoveArea),
            );
          },
          onScaleEnd: (_) {
            if (_isLayerBeingTransformed) {
              if (bloc.state.isLayerOverRemoveArea) {
                Log.debug(
                  '🎬 Layer removed via drag',
                  name: 'VideoEditorCanvas',
                  category: LogCategory.video,
                );
                scope.editor?.activeLayers.remove(_selectedLayer!);
              }

              _onStateHistoryChange(scope, bloc);
              _selectedLayer = null;
            }

            bloc.add(const VideoEditorLayerInteractionEnded());
          },
          onAddLayer: (layer) {
            Log.debug(
              '🎬 Layer added: ${layer.runtimeType}',
              name: 'VideoEditorCanvas',
              category: LogCategory.video,
            );
            _syncMainCapabilities(scope, bloc);
          },
          onRemoveLayer: (layer) {
            Log.debug(
              '🎬 Layer removed: ${layer.runtimeType}',
              name: 'VideoEditorCanvas',
              category: LogCategory.video,
            );
            _syncMainCapabilities(scope, bloc);
          },
          onCreateTextLayer: scope.onAddEditTextLayer,
          onEditTextLayer: scope.onAddEditTextLayer,
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
    );
  }
}

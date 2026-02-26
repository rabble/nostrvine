// ABOUTME: Canvas widget wrapping ProImageEditor for the video editor.
// ABOUTME: Handles layer manipulation callbacks and editor configuration.

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_player.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

/// The main canvas area for the video editor.
///
/// Wraps [ProImageEditor] and configures it for video editing with custom
/// styling and callbacks that dispatch events to [VideoEditorMainBloc].
class VideoEditorCanvas extends StatefulWidget {
  /// Creates a [VideoEditorCanvas].
  const VideoEditorCanvas({super.key});

  @override
  State<VideoEditorCanvas> createState() => _VideoEditorCanvasState();
}

class _VideoEditorCanvasState extends State<VideoEditorCanvas> {
  @override
  Widget build(BuildContext context) {
    final isSubEditorOpen = context.select(
      (VideoEditorMainBloc b) => b.state.isSubEditorOpen,
    );

    return PopScope(
      canPop: !isSubEditorOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          final scope = VideoEditorScope.of(context);
          scope.editor?.closeSubEditor();
          final bloc = context.read<VideoEditorMainBloc>();
          bloc.add(const VideoEditorMainSubEditorClosed());
        }
      },
      child: Padding(
        padding: const .only(bottom: VideoEditorConstants.bottomBarHeight),
        child: _CanvasFitter(
          builder: (bodySize, renderSize) =>
              _VideoEditor(renderSize: renderSize, bodySize: bodySize),
        ),
      ),
    );
  }
}

class _VideoEditor extends ConsumerStatefulWidget {
  const _VideoEditor({required this.renderSize, required this.bodySize});

  final Size renderSize;
  final Size bodySize;

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

  /// Tracks whether pointer was over remove area in the previous frame.
  /// Used to deduplicate haptic feedback so it only fires once on entry.
  bool _wasOverRemoveArea = false;

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
    final clips = ref.read(clipManagerProvider).clips;

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
            targetAspectRatio: clips.first.targetAspectRatio,
            originalAspectRatio: clips.first.originalAspectRatio,
            bodySize: widget.bodySize,
            renderSize: widget.renderSize,
          );
        },
      ),
      initialResolution: widget.renderSize,
      // These values are not used since we provide a custom-UI.
      fileSize: 0,
      videoDuration: .zero,
    );

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
    await Future.delayed(const Duration(milliseconds: 200));
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
    // IMPORTANT: Don't start video rendering here. We must await
    // `_handleEditorComplete` which generate the layer image before we start
    // rendering! However, we can navigate to the metadata screen immediately
    // since it shows a progress spinner anyway (~200ms task).
    ref.read(videoEditorProvider.notifier).setProcessing(true);
    await context.push(VideoMetadataScreen.path);
    if (mounted) _videoPlayer?.play();
  }

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

    // BLOCs
    final bloc = context.read<VideoEditorMainBloc>();
    final drawBloc = context.read<VideoEditorDrawBloc>();

    // Riverpod
    final editorStateHistory = ref.read(
      videoEditorProvider.select((s) => s.editorStateHistory),
    );
    final targetAspectRatio = ref.read(
      clipManagerProvider.select((s) => s.clips.first.targetAspectRatio),
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
          customPixelRatio: max(
            1,
            VideoEditorConstants.renderWidth / widget.renderSize.width,
          ),
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
          eraserSize:
              DrawToolType.eraser.config.strokeWidth / scope.fittedBoxScale / 2,
          safeArea: const EditorSafeArea.none(),
          widgets: PaintEditorWidgets(
            appBar: (_, _) => null,
            bottomBar: (_, _) => null,
            colorPicker: (_, _, _, _) => null,
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
        helperLines: HelperLineConfigs(
          style: HelperLineStyle(
            // 1.25 is the pro_image_editor default; we divide by fittedBoxScale
            // to compensate for the FittedBox transformation.
            strokeWidth: 1.25 / scope.fittedBoxScale,
            horizontalColor: VideoEditorConstants.primaryColor,
            verticalColor: VideoEditorConstants.primaryColor,
            rotateColor: VideoEditorConstants.primaryColor,
            layerAlignColor: VideoEditorConstants.primaryColor,
          ),
        ),
        dialogConfigs: DialogConfigs(
          widgets: DialogWidgets(
            loadingDialog: (message, configs) => const SizedBox.shrink(),
          ),
        ),
        videoEditor: VideoEditorConfigs(
          showControls: false,
          widgets: VideoEditorWidgets(
            videoSetupLoadingIndicator: _VideoSetupLoadingIndicator(
              renderSize: widget.renderSize,
              bodySize: widget.bodySize,
              targetAspectRatio: targetAspectRatio,
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

            // Trigger haptic feedback when entering the remove area
            if (isOverRemoveArea && !_wasOverRemoveArea) {
              unawaited(HapticService.destructiveZoneFeedback());
            }
            _wasOverRemoveArea = isOverRemoveArea;

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
                scope.editor?.activeLayers.remove(_selectedLayer);
              }

              _onStateHistoryChange(scope, bloc);
              _selectedLayer = null;
            }

            _wasOverRemoveArea = false;
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
          helperLines: HelperLinesCallbacks(
            onLineHit: () => unawaited(HapticService.snapFeedback()),
          ),
        ),
        paintEditorCallbacks: PaintEditorCallbacks(
          onInit: () {
            drawBloc.add(const VideoEditorDrawReset());

            final paintEditor = scope.paintEditor;
            final drawState = context.read<VideoEditorDrawBloc>().state;
            final toolConfig = drawState.selectedTool.config;
            // Sync editor with current BLoC state - use tool config for
            // strokeWidth/opacity/mode to ensure consistency with tool switch
            paintEditor
              ?..setColor(drawState.selectedColor)
              ..setStrokeWidth(toolConfig.strokeWidth / scope.fittedBoxScale)
              ..setOpacity(toolConfig.opacity)
              ..setMode(toolConfig.mode);
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

class _VideoSetupLoadingIndicator extends StatelessWidget {
  const _VideoSetupLoadingIndicator({
    required this.renderSize,
    required this.bodySize,
    required this.targetAspectRatio,
  });

  final Size renderSize;
  final Size bodySize;
  final model.AspectRatio targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    final useFullSize = targetAspectRatio.useFullScreenForSize(bodySize);

    // Calculate the scale factor that FittedBox.cover applies
    final scale = max(
      bodySize.width / renderSize.width,
      bodySize.height / renderSize.height,
    );

    // Size in renderSize coordinates that equals bodySize after scaling
    final size = bodySize / scale;
    final radius = Radius.circular(32 / scale);

    if (useFullSize) {
      // Cover mode: show the visible portion of bodySize
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(bottom: radius),
          child: SizedBox.fromSize(
            size: size,
            child: VideoEditorThumbnail(contentSize: size),
          ),
        ),
      );
    } else {
      // Contain mode: the visible area is targetAspectRatio fitted in renderSize
      final containSize = Size(
        renderSize.height * targetAspectRatio.value,
        renderSize.height,
      );
      final containRadius = Radius.circular(
        32 * containSize.width / bodySize.width,
      );

      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.all(containRadius),
          child: SizedBox.fromSize(
            size: containSize,
            child: VideoEditorThumbnail(contentSize: containSize),
          ),
        ),
      );
    }
  }
}

class _CanvasFitter extends ConsumerWidget {
  const _CanvasFitter({required this.builder});

  final Widget Function(Size bodySize, Size renderSize) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(clipManagerProvider.select((s) => s.clips.first));
    final scope = VideoEditorScope.of(context);

    return LayoutBuilder(
      builder: (_, constraints) {
        final bodySize = constraints.biggest;

        final useFullSize = clip.targetAspectRatio.useFullScreenForSize(
          bodySize,
        );

        // Height is constrained by maxWidth or maxHeight,
        // depending on which dimension is reached first
        final height = min(bodySize.width, bodySize.height);
        final renderSize = Size(height * clip.originalAspectRatio, height);

        // Notify parent about body size
        scope.bodySizeNotifier.value = bodySize;

        // The child content (ProImageEditor with originalAspectRatio)
        final child = SizedBox.fromSize(
          size: renderSize,
          // Wraps sub-editors in a nested Navigator so they open within
          // the fitted aspect-ratio area instead of full-screen, since
          // cropping hasn't been applied yet.
          child: Navigator(
            clipBehavior: Clip.none,
            onGenerateRoute: (_) => PageRouteBuilder(
              pageBuilder: (_, _, _) => builder(bodySize, renderSize),
            ),
          ),
        );

        if (useFullSize) {
          // Cover mode: fill entire bodySize with the original aspect ratio
          return FittedBox(fit: BoxFit.cover, child: child);
        } else {
          // Contain mode: fit targetAspectRatio within bodySize,
          // then cover that area with the original aspect ratio
          final Size targetSize;
          if (bodySize.aspectRatio > clip.targetAspectRatio.value) {
            // Body is wider, height is limiting
            targetSize = Size(
              bodySize.height * clip.targetAspectRatio.value,
              bodySize.height,
            );
          } else {
            // Body is narrower, width is limiting
            targetSize = Size(
              bodySize.width,
              bodySize.width / clip.targetAspectRatio.value,
            );
          }

          return Center(
            child: SizedBox.fromSize(
              size: targetSize,
              child: FittedBox(fit: BoxFit.cover, child: child),
            ),
          );
        }
      },
    );
  }
}

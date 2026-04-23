// ABOUTME: Canvas widget wrapping ProImageEditor for the video editor.
// ABOUTME: Handles layer manipulation callbacks and editor configuration.

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_feed_preview_overlay.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_player.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    hide AudioTrack, VideoClip;
import 'package:unified_logger/unified_logger.dart';

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
        padding: .only(top: MediaQuery.viewPaddingOf(context).top),
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
  late final ProVideoController _proVideoController;
  final _isPlayerReadyNotifier = ValueNotifier<bool>(false);
  DivineVideoPlayerController? _videoPlayer;
  StreamSubscription<DivineVideoPlayerState>? _videoPlayerSubscription;

  bool _isInitialized = false;
  bool _isImportingHistory = false;

  bool get _isLayerBeingTransformed => _selectedLayer != null;

  Layer? _selectedLayer;

  /// Tracks whether pointer was over remove area in the previous frame.
  /// Used to deduplicate haptic feedback so it only fires once on entry.
  bool _wasOverRemoveArea = false;

  /// Tracks last playback state to detect changes.
  bool _lastIsPlaying = false;

  /// Last position dispatched to BLoC — avoids flooding with duplicates.
  Duration _lastReportedPosition = Duration.zero;

  /// Last duration dispatched to BLoC — avoids flooding with duplicates.
  Duration _lastReportedDuration = Duration.zero;

  /// Whether a native seekTo is currently in flight.
  bool _isSeeking = false;

  /// The most recent seek position received while a seek was in progress.
  /// Processed as a trailing seek once the current seek completes.
  Duration? _pendingSeekPosition;

  /// Cached documents directory path — resolved once in [initState].
  late final Future<String> _documentsPath;

  @override
  void initState() {
    super.initState();
    Log.info(
      '🎬 Canvas initialized',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    _initializeController();
    _documentsPath = getDocumentsPath();

    // Initialize the player with the current clips.
    if (_clipPaths.isNotEmpty) {
      _initializePlayer(_clipPaths);
    }
  }

  @override
  void dispose() {
    Log.info(
      '🎬 Canvas disposed',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    _videoPlayerSubscription?.cancel();
    _videoPlayer?.dispose();
    _isPlayerReadyNotifier.dispose();
    super.dispose();
  }

  /// Extracts playable file paths from the current clip state.
  List<String> get _clipPaths => ref
      .read(clipManagerProvider)
      .clips
      .map((c) => c.video.file?.path)
      .whereType<String>()
      .toList();

  /// Handles playback restart requests from BLoC.
  void _onPlaybackRestartRequested() {
    if (!_isPlayerReadyNotifier.value) return;

    _videoPlayer?.seekTo(Duration.zero);
    _videoPlayer?.play();
  }

  /// Handles playback toggle requests from BLoC.
  void _onPlaybackToggleRequested() {
    if (!_isPlayerReadyNotifier.value) return;

    final isPlaying = _videoPlayer?.state.isPlaying ?? false;
    if (isPlaying) {
      _videoPlayer?.pause();
    } else {
      _videoPlayer?.play();
    }
  }

  /// Handles external pause requests from BLoC.
  void _onExternalPauseChanged({required bool isPaused}) {
    if (!_isPlayerReadyNotifier.value) return;

    if (isPaused) {
      _videoPlayer?.pause();
    } else {
      _videoPlayer?.play();
    }
  }

  /// Handles seek requests from BLoC (e.g. timeline scrubbing).
  ///
  /// Uses a leading + trailing pattern with async backpressure:
  /// - The first request (leading) is executed immediately via await.
  /// - While the native seekTo is in flight, intermediate requests are
  ///   dropped; only the latest position is kept.
  /// - Once the seek completes, the last received position is fired as
  ///   a trailing seek so the video always lands on the final frame.
  ///
  /// This relies on both Android and iOS returning from seekTo only
  /// after the frame is actually decoded and rendered.
  Future<void> _onSeekRequested(Duration position) async {
    if (!_isPlayerReadyNotifier.value) return;

    _proVideoController.setPlayTime(position);

    if (_isSeeking) {
      _pendingSeekPosition = position;
      return;
    }

    _isSeeking = true;
    await _videoPlayer?.seekTo(position);

    // Process trailing seek if one arrived while we were busy.
    while (_pendingSeekPosition != null && mounted) {
      final pending = _pendingSeekPosition!;
      _pendingSeekPosition = null;
      await _videoPlayer?.seekTo(pending);
    }

    _isSeeking = false;
  }

  /// Dispatches playback state changes to the BLoC.
  ///
  /// Reports play/pause state, current position, and duration so the
  /// timeline can stay in sync with the real player.
  /// Only dispatches when values actually change to avoid flooding.
  void _onPlayerStateChanged(DivineVideoPlayerState playerState) {
    final bloc = context.read<VideoEditorMainBloc>();

    final isPlaying = playerState.isPlaying;
    if (isPlaying != _lastIsPlaying) {
      _lastIsPlaying = isPlaying;
      bloc.add(VideoEditorPlaybackChanged(isPlaying: isPlaying));
    }

    if (playerState.position != _lastReportedPosition) {
      _lastReportedPosition = playerState.position;
      bloc.add(VideoEditorPositionChanged(playerState.position));
      _proVideoController.setPlayTime(playerState.position);
    }

    if (playerState.duration != _lastReportedDuration) {
      _lastReportedDuration = playerState.duration;
      bloc.add(VideoEditorDurationChanged(playerState.duration));
    }
  }

  /// Called when clip paths change. Updates the player with the new clips
  /// or pauses when no clips are available.
  void _onClipPathsChanged(List<String> clipPaths) {
    if (clipPaths.isEmpty) {
      _videoPlayer?.pause();
      _isPlayerReadyNotifier.value = false;
      context.read<VideoEditorMainBloc>()
        ..add(const VideoEditorPlaybackChanged(isPlaying: false))
        ..add(const VideoEditorPlayerReady(isReady: false));
      return;
    }

    final clips = ref.read(clipManagerProvider).clips;
    final currentPosition = context
        .read<VideoEditorMainBloc>()
        .state
        .currentPosition;
    _videoPlayer?.setClips(
      [
        for (final clip in clips)
          if (clip.video.file?.path case final path?)
            VideoClip(
              uri: path,
              start: clip.trimStart,
              end: clip.duration - clip.trimEnd,
            ),
      ],
      startPosition: currentPosition,
    );
  }

  /// Creates the [ProVideoController] (only once, not tied to a file).
  void _initializeController() {
    _proVideoController = ProVideoController(
      videoPlayer: ValueListenableBuilder(
        valueListenable: _isPlayerReadyNotifier,
        builder: (_, isPlayerReady, _) {
          return Consumer(
            builder: (context, ref, _) {
              final clip = ref.watch(
                clipManagerProvider.select((s) => s.firstClipOrNull),
              );
              if (clip == null) return const SizedBox.shrink();

              return VideoEditorPlayer(
                controller: _videoPlayer,
                targetAspectRatio: clip.targetAspectRatio,
                originalAspectRatio: clip.originalAspectRatio,
                bodySize: widget.bodySize,
                renderSize: widget.renderSize,
              );
            },
          );
        },
      ),
      initialResolution: widget.renderSize,
      // These values are not used since we provide a custom-UI.
      fileSize: 0,
      videoDuration: .zero,
    );
  }

  /// Initializes (or reinitializes) the native video player with [clipPaths].
  Future<void> _initializePlayer(
    List<String> clipPaths, {
    Duration? startPosition,
  }) async {
    // Dispose old player if it exists.
    await _videoPlayerSubscription?.cancel();
    await _videoPlayer?.dispose();
    _isPlayerReadyNotifier.value = false;

    final clips = ref.read(clipManagerProvider).clips;

    Log.debug(
      '🎬 Initializing video player with ${clipPaths.length} clip(s)',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );

    _videoPlayer = DivineVideoPlayerController(useTexture: true);

    await _videoPlayer!.initialize();
    if (!mounted) return;
    await _videoPlayer!.setClips(
      [
        for (final clip in clips)
          if (clip.video.file?.path case final path?)
            VideoClip(
              uri: path,
              start: clip.trimStart,
              end: clip.duration - clip.trimEnd,
            ),
      ],
      startPosition: startPosition != null && startPosition > Duration.zero
          ? startPosition
          : null,
    );
    if (!mounted) return;

    final editorState = ref.read(videoEditorProvider);
    if (clips.isEmpty) return;
    await Future.wait([
      _videoPlayer!.setLooping(looping: true),
      _videoPlayer!.setVolume(editorState.originalAudioVolume),
    ]);
    if (!mounted) return;

    _isPlayerReadyNotifier.value = true;

    // Notify BLoC that player is ready
    if (mounted) {
      context.read<VideoEditorMainBloc>().add(
        const VideoEditorPlayerReady(),
      );
    }

    // Setup state stream listener
    _videoPlayerSubscription = _videoPlayer!.stateStream.listen(
      _onPlayerStateChanged,
    );

    // Initialize audio if selected
    await _syncAudioTracks();
    Log.info(
      '🎬 Video player ready',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
  }

  /// Syncs native audio overlay tracks from the [TimelineOverlayBloc]
  /// sound items.
  ///
  /// Reads timeline positions (`startTime` / `endTime`) from the BLoC
  /// state and combines them with the source [AudioEvent] from the
  /// Riverpod provider (URL, asset path, start offset).
  Future<void> _syncAudioTracks() async {
    if (_videoPlayer == null) return;

    final overlayState = context.read<TimelineOverlayBloc>().state;
    final audioEvents = overlayState.audioTracks;

    final soundItems = overlayState.items
        .where((item) => item.type == TimelineOverlayType.sound)
        .toList();

    if (soundItems.isEmpty || audioEvents.isEmpty) {
      await _videoPlayer!.removeAllAudioTracks();
      Log.info(
        '🎵 Audio cleared',
        name: 'VideoEditorCanvas',
        category: LogCategory.video,
      );
      return;
    }

    // Index audio events by ID for fast lookup.
    final audioById = {
      for (final e in audioEvents) e.id: e,
    };

    final customVolume = ref.read(videoEditorProvider).customAudioVolume;

    final tracks = <AudioTrack>[];
    for (final item in soundItems) {
      final sound = audioById[item.id];
      if (sound == null || sound.url == null) continue;

      try {
        final AudioTrack track;
        if (sound.isBundled && sound.assetPath != null) {
          track = await AudioTrack.asset(
            sound.assetPath!,
            volume: customVolume,
            videoStartTime: item.startTime,
            videoEndTime: item.endTime,
            trackStart: sound.startOffset,
          );
        } else {
          track = AudioTrack.network(
            sound.url!,
            volume: customVolume,
            videoStartTime: item.startTime,
            videoEndTime: item.endTime,
            trackStart: sound.startOffset,
          );
        }
        tracks.add(track);
      } catch (e, stackTrace) {
        Log.error(
          '🎵 Failed to build audio track ${item.id}: $e',
          name: 'VideoEditorCanvas',
          category: LogCategory.video,
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    if (tracks.isEmpty) {
      await _videoPlayer!.removeAllAudioTracks();
      return;
    }

    try {
      await _videoPlayer!.setAudioTracks(tracks);
    } catch (e, stackTrace) {
      Log.error(
        '🎵 Failed to load audio: $e',
        name: 'VideoEditorCanvas',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return;
    }

    Log.info(
      '🎵 Audio synced: ${tracks.length} track(s)',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
  }

  /// Syncs the main-editor capabilities from the main editor to the bloc.
  void _syncMainCapabilities(VideoEditorScope scope, VideoEditorMainBloc bloc) {
    final editor = scope.editor;
    if (editor == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bloc.add(
        VideoEditorMainCapabilitiesChanged(
          canUndo: editor.canUndo,
          canRedo: editor.canRedo,
          layers: editor.activeLayers,
        ),
      );

      final videoDuration = context.read<ClipEditorBloc>().state.totalDuration;

      context.read<TimelineOverlayBloc>().add(
        TimelineOverlayItemsUpdate(
          layers: editor.activeLayers,
          filters: editor.stateManager.activeFilters,
          totalVideoDuration: videoDuration,
          audioTracks: editor.stateManager.audioTracks,
        ),
      );

      final clips = List<DivineVideoClip>.from(
        editor.stateManager.clipSnapshots(await _documentsPath),
      );
      if (!mounted || clips.isEmpty || _isImportingHistory) return;

      // Only update if clips actually changed to avoid unnecessary rebuilds
      // and autosave triggers. DivineVideoClip uses reference equality, so
      // we compare the editable properties explicitly.
      final currentClips = ref.read(clipManagerProvider).clips;
      if (_clipsChanged(currentClips, clips)) {
        ref.read(clipManagerProvider.notifier).replaceClips(clips);
      }
      if (_clipsChanged(context.read<ClipEditorBloc>().state.clips, clips)) {
        context.read<ClipEditorBloc>().add(ClipEditorInitialized(clips));
      }
    });
  }

  /// Compares two clip lists by their editable properties.
  bool _clipsChanged(
    List<DivineVideoClip> current,
    List<DivineVideoClip> next,
  ) {
    if (current.length != next.length) return true;
    for (var i = 0; i < current.length; i++) {
      final a = current[i];
      final b = next[i];
      if (a.id != b.id ||
          a.video != b.video ||
          a.trimStart != b.trimStart ||
          a.trimEnd != b.trimEnd ||
          a.volume != b.volume) {
        return true;
      }
    }
    return false;
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
    final result = await scope.requireEditor.exportStateHistory(
      configs: const ExportEditorConfigs(
        historySpan: .currentAndBackward,
        // We don't minify the state history so it remains readable for
        // ProofMode.
        enableMinify: false,
      ),
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
    if (parameters.layers.isNotEmpty && parameters.image.isNotEmpty) {
      try {
        // We only precache the image for the preview on the metadata screen,
        // which is not relevant for rendering.
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
  /// and resumes video when returning only if it was playing before.
  /// Audio sync handled by listener.
  Future<void> _handleDone() async {
    Log.info(
      '🎬 Done pressed - navigating to metadata screen',
      name: 'VideoEditorCanvas',
      category: LogCategory.video,
    );
    final wasPlaying = _videoPlayer?.state.isPlaying ?? false;
    _videoPlayer?.pause();
    // IMPORTANT: Don't start video rendering here. We must await
    // `_handleEditorComplete` which generate the layer image before we start
    // rendering! However, we can navigate to the metadata screen immediately
    // since it shows a progress spinner anyway (~200ms task).
    ref.read(videoEditorProvider.notifier).setProcessing(true);
    await context.push(VideoMetadataScreen.path);
    if (mounted && wasPlaying) {
      _videoPlayer?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

    // BLOCs
    final bloc = context.read<VideoEditorMainBloc>();
    final drawBloc = context.read<VideoEditorDrawBloc>();

    // Riverpod
    final clip = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull),
    );
    if (clip == null) return const SizedBox.shrink();

    final editorStateHistory = ref.read(
      videoEditorProvider.select((s) => s.editorStateHistory),
    );
    final targetAspectRatio = clip.targetAspectRatio;

    // Live volume preview: sync player volumes when state changes
    ref.listen<double>(
      videoEditorProvider.select((s) => s.originalAudioVolume),
      (_, volume) => _videoPlayer?.setVolume(volume),
    );
    ref.listen<double>(
      videoEditorProvider.select((s) => s.customAudioVolume),
      (_, volume) => _videoPlayer?.setAudioTrackVolume(0, volume),
    );

    // Reinitialize the player when clip paths change.
    // Uses a custom equality check because List uses reference equality by
    // default, which would cause the listener to fire on every provider
    // rebuild even when the paths haven't actually changed.
    ref.listen<List<String>>(
      clipManagerProvider.select(
        (s) =>
            s.clips.map((c) => c.video.file?.path).whereType<String>().toList(),
      ),
      (previous, clipPaths) {
        if (listEquals(previous, clipPaths)) return;

        // If only the order changed (reorder), the BlocListener below
        // calls setClips with startPosition — no full reinit needed.
        final prevSorted = previous != null
            ? ([...previous]..sort())
            : <String>[];
        final currSorted = [...clipPaths]..sort();
        if (listEquals(prevSorted, currSorted)) return;

        _onClipPathsChanged(clipPaths);
      },
    );

    // Update native player clip boundaries when trim times change.
    ref.listen<List<(Duration, Duration)>>(
      clipManagerProvider.select(
        (s) => s.clips.map((c) => (c.trimStart, c.trimEnd)).toList(),
      ),
      (previous, current) {
        if (listEquals(previous, current)) return;

        final clips = ref.read(clipManagerProvider).clips;
        final currentPosition = context
            .read<VideoEditorMainBloc>()
            .state
            .currentPosition;

        _videoPlayer?.setClips(
          [
            for (final clip in clips)
              if (clip.video.file?.path case final path?)
                VideoClip(
                  uri: path,
                  start: clip.trimStart,
                  end: clip.duration - clip.trimEnd,
                ),
          ],
          startPosition: currentPosition,
        );
      },
    );

    // Listen for playback control requests from BLoC
    return _OverlayCutArea(
      child: MultiBlocListener(
        listeners: [
          // Re-export state history when an overlay item drag or trim
          // ends so the updated positions are persisted for ProofMode.
          BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
            listenWhen: (previous, current) =>
                (previous.draggingItemId != null &&
                    current.draggingItemId == null) ||
                (previous.trimmingItemId != null &&
                    current.trimmingItemId == null),
            listener: (context, state) {
              _onStateHistoryChange(scope, bloc);
            },
          ),
          // Sync native audio tracks when audio sources change
          // (sound added/removed) or a sound item is dragged/trimmed.
          BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
            listenWhen: (previous, current) {
              // Audio sources changed (add / remove / replace).
              if (previous.audioTracks != current.audioTracks) return true;

              // Sound item drag/trim ended.
              final dragEnded =
                  previous.draggingItemId != null &&
                  current.draggingItemId == null;
              final trimEnded =
                  previous.trimmingItemId != null &&
                  current.trimmingItemId == null;
              if (!dragEnded && !trimEnded) return false;

              final changedId =
                  previous.draggingItemId ?? previous.trimmingItemId;
              final item = current.items
                  .where((i) => i.id == changedId)
                  .firstOrNull;
              return item?.type == TimelineOverlayType.sound;
            },
            listener: (context, state) {
              _syncAudioTracks();
            },
          ),
          // Update native player clip boundaries when trim handle is
          // released or for non-trim clip changes (reorder, add, remove).
          BlocListener<ClipEditorBloc, ClipEditorState>(
            listenWhen: (previous, current) {
              // Trim handle released.
              if (previous.isTrimDragging && !current.isTrimDragging) {
                return true;
              }
              // Non-trim clip changes (reorder, add, remove).
              if (!current.isTrimDragging &&
                  !previous.isTrimDragging &&
                  previous.clips != current.clips) {
                return true;
              }
              return false;
            },
            listener: (context, state) {
              final currentPosition = context
                  .read<VideoEditorMainBloc>()
                  .state
                  .currentPosition;
              _videoPlayer?.setClips(
                [
                  for (final clip in state.clips)
                    if (clip.video.file?.path case final path?)
                      VideoClip(
                        uri: path,
                        start: clip.trimStart,
                        end: clip.duration - clip.trimEnd,
                      ),
                ],
                startPosition: currentPosition,
              );
            },
          ),
          BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
            listenWhen: (previous, current) =>
                previous.isExternalPauseRequested !=
                current.isExternalPauseRequested,
            listener: (context, state) {
              _onExternalPauseChanged(
                isPaused: state.isExternalPauseRequested,
              );
            },
          ),
          BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
            listenWhen: (previous, current) =>
                previous.playbackRestartCounter !=
                current.playbackRestartCounter,
            listener: (context, state) {
              _onPlaybackRestartRequested();
            },
          ),
          BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
            listenWhen: (previous, current) =>
                previous.playbackToggleCounter != current.playbackToggleCounter,
            listener: (context, state) {
              _onPlaybackToggleRequested();
            },
          ),
          BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
            listenWhen: (previous, current) =>
                previous.seekCounter != current.seekCounter,
            listener: (context, state) {
              _onSeekRequested(state.seekPosition);
            },
          ),
          BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
            listenWhen: (previous, current) =>
                previous.isMuted != current.isMuted,
            listener: (context, state) {
              _videoPlayer?.setVolume(state.isMuted ? 0 : 1);
              ref
                  .read(videoEditorProvider.notifier)
                  .setOriginalAudioVolume(state.isMuted ? 0 : 1);
            },
          ),
        ],
        child: ProImageEditor.video(
          _proVideoController,
          key: scope.editorKey,
          configs: ProImageEditorConfigs(
            stateHistory: StateHistoryConfigs(
              initStateHistory: editorStateHistory.isNotEmpty
                  ? .fromMap(editorStateHistory)
                  : null,
            ),
            imageGeneration: ImageGenerationConfigs(
              captureImageByteFormat: .rawStraightRgba,
              enableBackgroundGeneration: false,
              enableUseOriginalBytes: false,
              // Disabled in debug mode: combined RAM usage from the editor
              // and MediaKit (background) causes crashes on hot-reload.
              // Release builds are unaffected.
              enableIsolateGeneration: kReleaseMode,
              processorConfigs: const ProcessorConfigs(
                numberOfBackgroundProcessors: 3,
                processorMode: .limit,
                initializationDelay:
                    VideoEditorConstants.isolatesInitialisationDelay,
              ),
              customPixelRatio: max(
                1,
                max(
                  VideoEditorConstants.quality.resolution.height /
                      widget.renderSize.height,
                  VideoEditorConstants.quality.resolution.width /
                      widget.renderSize.width,
                ),
              ),
            ),
            mainEditor: MainEditorConfigs(
              safeArea: const EditorSafeArea.none(),
              style: const MainEditorStyle(
                uiOverlayStyle: VideoEditorConstants.uiOverlayStyle,
                background: VineTheme.backgroundCamera,
              ),
              captureLayersOnDone: true,
              captureImageOnDone: false,
              widgets: MainEditorWidgets(
                appBar: (_, _) => null,
                bottomBar: (_, _, key) => null,
                removeLayerArea: (key, _, _, _) => SizedBox.shrink(key: key),
                bodyItems: (editor, rebuildStream) {
                  return [
                    ReactiveWidget(
                      builder: (context) =>
                          BlocSelector<
                            VideoEditorMainBloc,
                            VideoEditorMainState,
                            ({
                              bool isOver,
                              bool isReordering,
                              bool isSubEditorOpen,
                            })
                          >(
                            selector: (state) => (
                              isOver:
                                  state.currentPosition.inMilliseconds >
                                  VideoEditorConstants
                                      .maxDuration
                                      .inMilliseconds,
                              isReordering: state.isReordering,
                              isSubEditorOpen: state.isSubEditorOpen,
                            ),
                            builder: (context, record) {
                              if (!record.isOver ||
                                  record.isReordering ||
                                  record.isSubEditorOpen) {
                                return const SizedBox.shrink();
                              }
                              return IgnorePointer(
                                child: ColoredBox(
                                  color: VineTheme.backgroundColor.withAlpha(
                                    128,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              );
                            },
                          ),
                      stream: rebuildStream,
                    ),
                    ReactiveWidget(
                      builder: (context) => VideoEditorFeedPreviewOverlay(
                        renderSize: widget.renderSize,
                        targetAspectRatio: targetAspectRatio.value,
                        isFeedPreviewVisible: editor.isLayerBeingTransformed,
                      ),
                      stream: rebuildStream,
                    ),
                  ];
                },
              ),
            ),
            paintEditor: PaintEditorConfigs(
              eraserSize:
                  DrawToolType.eraser.config.strokeWidth /
                  scope.fittedBoxScale /
                  2,
              safeArea: const EditorSafeArea.none(),
              enableEdit: false,
              style: const PaintEditorStyle(
                background: VineTheme.backgroundCamera,
              ),
              widgets: PaintEditorWidgets(
                appBar: (_, _) => null,
                bottomBar: (_, _) => null,
                colorPicker: (_, _, _, _) => null,
              ),
            ),
            filterEditor: FilterEditorConfigs(
              safeArea: const EditorSafeArea.none(),
              enableMultiSelection: false,
              style: const FilterEditorStyle(
                background: VineTheme.backgroundCamera,
              ),
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

                if (editorStateHistory.isEmpty) {
                  final clips = ref.read(clipManagerProvider).clips;

                  scope.requireEditor.stateManager.replaceHistory(
                    scope.requireEditor.stateHistory.first.copyWith(
                      meta: {
                        ...scope.requireEditor.stateManager.activeMeta,
                        VideoEditorConstants.clipsStateHistoryKey: clips
                            .map((e) => e.toJson())
                            .toList(),
                      },
                    ),
                    index: 0,
                  );
                }

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
              onStateHistoryChange: (_, _) =>
                  _onStateHistoryChange(scope, bloc),
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
                final isOverRemoveArea = scope.isOverRemoveArea(
                  details.focalPoint,
                );

                // Trigger haptic feedback when entering the remove area
                if (isOverRemoveArea && !_wasOverRemoveArea) {
                  unawaited(HapticService.destructiveZoneFeedback());
                }
                _wasOverRemoveArea = isOverRemoveArea;

                bloc.add(
                  VideoEditorLayerOverRemoveAreaChanged(
                    isOver: isOverRemoveArea,
                  ),
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
              onRedo: () => _syncMainCapabilities(scope, bloc),
              onUndo: () => _syncMainCapabilities(scope, bloc),
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
                  ..setStrokeWidth(
                    toolConfig.strokeWidth / scope.fittedBoxScale,
                  )
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
              },
            ),
          ),
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
    // Contain mode: the visible area is targetAspectRatio fitted in renderSize
    final containSize = Size(
      renderSize.height * targetAspectRatio.value,
      renderSize.height,
    );
    final containRadius = Radius.circular(
      VideoEditorConstants.canvasRadius * containSize.width / bodySize.width,
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

class _CanvasFitter extends ConsumerWidget {
  const _CanvasFitter({required this.builder});

  final Widget Function(Size bodySize, Size renderSize) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull),
    );
    if (clip == null) return const SizedBox.shrink();
    final scope = VideoEditorScope.of(context);

    return LayoutBuilder(
      builder: (_, constraints) {
        final bodySize = constraints.biggest;

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
      },
    );
  }
}

class _OverlayCutArea extends ConsumerWidget {
  const _OverlayCutArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAspectRatio = ref.read(
      clipManagerProvider.select((s) => s.firstClipOrNull?.targetAspectRatio),
    );
    if (targetAspectRatio == null) return const SizedBox.shrink();

    if (targetAspectRatio == .vertical) return child;

    return BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
      buildWhen: (previous, current) =>
          previous.isLayerInteractionActive != current.isLayerInteractionActive,
      builder: (context, state) {
        final hideOverlay = state.isLayerInteractionActive;

        return LayoutBuilder(
          builder: (context, constraints) {
            final boxSize = constraints.biggest;
            // Child is always 1:1 and BoxFit.contain, so it fills the
            // shorter dimension fully.
            final childSide = boxSize.shortestSide;
            final verticalGap = (boxSize.height - childSide) / 2;
            final horizontalGap = (boxSize.width - childSide) / 2;

            return Stack(
              fit: StackFit.expand,
              children: [
                child,
                AnimatedOpacity(
                  opacity: hideOverlay ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Top bar
                      if (verticalGap > 0)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: verticalGap,
                          child: const ColoredBox(color: VineTheme.scrim65),
                        ),
                      // Bottom bar
                      if (verticalGap > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: verticalGap,
                          child: const ColoredBox(color: VineTheme.scrim65),
                        ),
                      // Left bar
                      if (horizontalGap > 0)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: 0,
                          width: horizontalGap,
                          child: const ColoredBox(color: VineTheme.scrim65),
                        ),
                      // Right bar
                      if (horizontalGap > 0)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: horizontalGap,
                          child: const ColoredBox(color: VineTheme.scrim65),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

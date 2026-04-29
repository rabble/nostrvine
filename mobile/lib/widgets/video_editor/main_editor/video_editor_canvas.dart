// ABOUTME: Canvas widget wrapping ProImageEditor for the video editor.
// ABOUTME: Handles layer manipulation callbacks and editor configuration.

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide Layer;
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
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    hide AudioTrack, VideoClip;
import 'package:unified_logger/unified_logger.dart';

/// The main canvas area for the video editor.
///
/// Wraps [ProImageEditor] and configures it for video editing with custom
/// styling and callbacks that dispatch events to [VideoEditorMainBloc].
class VideoEditorCanvas extends StatelessWidget {
  /// Creates a [VideoEditorCanvas].
  const VideoEditorCanvas({super.key});

  /// Pushes the post-`setClips` start position back into the
  /// [VideoEditorMainBloc] and the [ProVideoController] after a trim
  /// release.
  ///
  /// Skips the bloc dispatch when [trimEndAlreadyDispatched] is `true`
  /// — the same value was already pushed pre-await — but always
  /// updates the controller's play time so the on-screen scrubber
  /// matches the native player's seek target.
  @visibleForTesting
  static void syncPositionAfterTrimRelease({
    required VideoEditorMainBloc mainBloc,
    required ProVideoController proVideoController,
    required Duration startPosition,
    required bool trimEndAlreadyDispatched,
  }) {
    if (!trimEndAlreadyDispatched) {
      mainBloc.add(VideoEditorPositionChanged(startPosition));
    }
    proVideoController.setPlayTime(startPosition);
  }

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
      // Const child: Flutter detects identical() widget and skips the
      // rebuild cascade (_CanvasFitter → LayoutBuilder → _VideoEditorState)
      // when only isSubEditorOpen changes.
      child: const _CanvasBody(),
    );
  }
}

class _CanvasBody extends StatelessWidget {
  const _CanvasBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: .only(top: MediaQuery.viewPaddingOf(context).top),
      child: _CanvasFitter(
        builder: (bodySize, renderSize) =>
            _VideoEditor(renderSize: renderSize, bodySize: bodySize),
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

  /// Monotonically increasing seek generation. Bumped on every composition
  /// swap so in-flight seeks from the previous composition are discarded.
  int _seekEpoch = 0;

  /// Cached documents directory path — resolved once in [initState].
  late final Future<String> _documentsPath;

  bool _isTrimmingLayer = false;
  bool _isTrimmingClip = false;
  bool _isDraggingLayer = false;

  /// Most recent live-preview seek target captured while a layer trim
  /// handle is being dragged. Used at gesture end to sync the
  /// VideoEditorMainBloc's currentPosition (and thus the UI timeline
  /// scrubber) to the release point in a single dispatch — doing it
  /// inside the seek loop would let the scrubber jump mid-drag.
  Duration? _lastLayerTrimPosition;

  /// Same as [_lastLayerTrimPosition] but for layer item drag
  /// (move-along-timeline) gestures. Captures the dragged item's
  /// startTime during the drag and is dispatched once on release.
  Duration? _lastLayerDragPosition;

  /// Most recent in-progress clip trim. Captured while the gesture is
  /// active so that, once it ends and the multi-clip composite is
  /// restored, we can seek to the composite-timeline position that
  /// matches where the user released the trim handle.
  String? _lastTrimClipId;
  Duration? _lastTrimPositionInClip;

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
  ///
  /// Returns the composite-timeline position of the most recent
  /// in-progress clip trim (and clears the captured values), so that
  /// after a trim drag ends and the multi-clip composite is restored,
  /// playback stays on the frame the user released. Returns `null`
  /// when no trim was in progress, the trimmed clip is no longer in
  /// the list, or the captured position falls outside the clip's
  /// trimmed range.
  Duration? _consumeTrimEndStartPosition(List<DivineVideoClip> clips) {
    final clipId = _lastTrimClipId;
    final positionInClip = _lastTrimPositionInClip;
    _lastTrimClipId = null;
    _lastTrimPositionInClip = null;
    if (clipId == null || positionInClip == null) return null;

    var precedingDuration = Duration.zero;
    for (final clip in clips) {
      if (clip.id == clipId) {
        final relative = positionInClip - clip.trimStart;
        if (relative < Duration.zero || relative > clip.trimmedDuration) {
          return null;
        }
        return precedingDuration + relative;
      }
      precedingDuration += clip.trimmedDuration;
    }
    return null;
  }

  Future<void> _onSeekRequested(Duration position) async {
    if (!_isPlayerReadyNotifier.value) return;

    _proVideoController.setPlayTime(position);

    if (_isSeeking) {
      _pendingSeekPosition = position;
      return;
    }

    _isSeeking = true;
    final epoch = _seekEpoch;
    try {
      await _videoPlayer?.seekTo(position);
      if (_seekEpoch != epoch) {
        _pendingSeekPosition = null;
        return;
      }

      // Process trailing seek if one arrived while we were busy.
      while (_pendingSeekPosition != null && mounted) {
        final pending = _pendingSeekPosition!;
        _pendingSeekPosition = null;
        if (_seekEpoch != epoch) {
          _pendingSeekPosition = null;
          break;
        }
        await _videoPlayer?.seekTo(pending);
      }
    } finally {
      // Only reset under the current epoch; a composition swap takes over ownership.
      if (_seekEpoch == epoch) {
        _isSeeking = false;
      }
    }
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

    if (!_isTrimmingLayer &&
        !_isTrimmingClip &&
        !_isDraggingLayer &&
        _pendingSeekPosition == null &&
        playerState.position != _lastReportedPosition) {
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
    _videoPlayer?.setClips([
      for (final clip in clips)
        if (clip.video.file?.path case final path?)
          VideoClip(
            uri: path,
            start: clip.trimStart,
            end: clip.duration - clip.trimEnd,
          ),
    ], startPosition: currentPosition);
  }

  /// Creates the [ProVideoController] (only once, not tied to a file).
  void _initializeController() {
    _proVideoController =
        ProVideoController(
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
        )..initialize(
          callbacksAudioFunction: () => const AudioEditorCallbacks(),
          callbacksFunction: VideoEditorCallbacks.new,
          configsFunction: () => const VideoEditorConfigs(),
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
      context.read<VideoEditorMainBloc>().add(const VideoEditorPlayerReady());
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
    final audioById = {for (final e in audioEvents) e.id: e};

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
        // Skip when there are no clips left (e.g. clearAll during
        // teardown). Sending `setClips([])` to the native player
        // builds a composition with `renderSize == .zero` on iOS,
        // which crashes `AVPlayerItem.setVideoComposition:`.
        if (clips.isEmpty) return;
        final currentPosition = context
            .read<VideoEditorMainBloc>()
            .state
            .currentPosition;

        _videoPlayer?.setClips([
          for (final clip in clips)
            if (clip.video.file?.path case final path?)
              VideoClip(
                uri: path,
                start: clip.trimStart,
                end: clip.duration - clip.trimEnd,
              ),
        ], startPosition: currentPosition);
      },
    );

    // Listen for playback control requests from BLoC
    return MultiBlocListener(
      listeners: [
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) {
            _isTrimmingLayer = previous.trimmingItemId != null;
            return previous.trimPosition != current.trimPosition &&
                _isTrimmingLayer;
          },
          listener: (context, state) {
            // trimPosition is null on the release emit — skip to preserve
            // _lastLayerTrimPosition for the end-listener below.
            final position = state.trimPosition;
            if (position == null) return;
            _lastLayerTrimPosition = position;
            _onSeekRequested(position);
          },
        ),
        // Sync scrubber once at gesture end (not mid-drag) to avoid
        // premature scrubber jumps while the seek is still in flight.
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) =>
              previous.trimmingItemId != null && current.trimmingItemId == null,
          listener: (context, _) {
            final position = _lastLayerTrimPosition;
            _lastLayerTrimPosition = null;
            if (position == null) return;
            _lastReportedPosition = position;
            context.read<VideoEditorMainBloc>().add(
              VideoEditorPositionChanged(position),
            );
          },
        ),
        // Live seek while a layer item is dragged: follow its startTime.
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) {
            _isDraggingLayer = current.draggingItemId != null;
            return previous.dragPosition != current.dragPosition &&
                current.dragPosition != null;
          },
          listener: (context, state) {
            final position = state.dragPosition;
            if (position == null) return;
            _lastLayerDragPosition = position;
            _onSeekRequested(position);
          },
        ),
        // Sync scrubber once at drag end (not mid-drag).
        BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
          listenWhen: (previous, current) =>
              previous.draggingItemId != null && current.draggingItemId == null,
          listener: (context, _) {
            final position = _lastLayerDragPosition;
            _lastLayerDragPosition = null;
            if (position == null) return;
            _lastReportedPosition = position;
            context.read<VideoEditorMainBloc>().add(
              VideoEditorPositionChanged(position),
            );
          },
        ),
        BlocListener<ClipEditorBloc, ClipEditorState>(
          // Swap to single-clip (untrimmed) view on trim start so
          // trimPosition seeks the correct frame.
          listenWhen: (previous, current) =>
              previous.trimmingClipId != current.trimmingClipId,
          listener: (context, state) {
            _isTrimmingClip = state.trimmingClipId != null;
            if (state.trimmingClipId == null) return;
            final clip = state.clips.firstWhere(
              (c) => c.id == state.trimmingClipId,
            );
            final path = clip.video.file?.path;
            if (path == null) return;
            // Composition swap: invalidate in-flight seeks and release _isSeeking.
            _seekEpoch++;
            _pendingSeekPosition = null;
            _isSeeking = false;
            _videoPlayer?.setClips([
              VideoClip(uri: path, end: clip.duration),
            ]);
          },
        ),
        BlocListener<ClipEditorBloc, ClipEditorState>(
          // Live preview seek while a clip trim handle is dragged.
          listenWhen: (previous, current) =>
              current.trimmingClipId != null &&
              previous.trimPosition != current.trimPosition &&
              current.trimPosition != null,
          listener: (context, state) {
            _lastTrimClipId = state.trimmingClipId;
            _lastTrimPositionInClip = state.trimPosition;
            _onSeekRequested(state.trimPosition!);
          },
        ),
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
          listener: (context, state) async {
            // See note on the trim-times listener above: skip empty
            // clip lists to avoid crashing the iOS native player.
            if (state.clips.isEmpty) return;

            // Seek to the trim handle's release point when restoring the composite.
            final trimEndPosition = _consumeTrimEndStartPosition(state.clips);
            final startPosition = trimEndPosition ?? bloc.state.currentPosition;
            // Sync so subsequent re-emits read the post-seek position.
            if (trimEndPosition != null) {
              bloc.add(VideoEditorPositionChanged(trimEndPosition));
            }
            // Composition swap back — invalidate in-flight single-clip seeks.
            _seekEpoch++;
            _pendingSeekPosition = null;
            // Claim _isSeeking under the new epoch; try/finally ensures
            // release even if setClips throws.
            _isSeeking = true;
            final ownerEpoch = _seekEpoch;

            try {
              await _videoPlayer?.setClips([
                for (final clip in state.clips)
                  if (clip.video.file?.path case final path?)
                    VideoClip(
                      uri: path,
                      start: clip.trimStart,
                      end: clip.duration - clip.trimEnd,
                    ),
              ], startPosition: startPosition);
              if (mounted) {
                VideoEditorCanvas.syncPositionAfterTrimRelease(
                  mainBloc: bloc,
                  proVideoController: _proVideoController,
                  startPosition: startPosition,
                  trimEndAlreadyDispatched: trimEndPosition != null,
                );
              }
            } catch (e, s) {
              Log.error(
                'setClips failed on trim release: $e',
                name: 'VideoEditorCanvas',
                category: LogCategory.video,
                error: e,
                stackTrace: s,
              );
            } finally {
              _lastReportedPosition = startPosition;
              if (_seekEpoch == ownerEpoch) {
                _isSeeking = false;
              }
            }
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (previous, current) =>
              previous.isExternalPauseRequested !=
              current.isExternalPauseRequested,
          listener: (context, state) {
            _onExternalPauseChanged(isPaused: state.isExternalPauseRequested);
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (previous, current) =>
              previous.playbackRestartCounter != current.playbackRestartCounter,
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
                ? .fromMap(
                    editorStateHistory,
                    configs: ImportEditorConfigs(
                      widgetLoader: (id, {meta}) {
                        if (meta == null) return const SizedBox.shrink();

                        return VideoEditorSticker(
                          sticker: .fromJson(meta),
                          enableLimitCacheSize: false,
                        );
                      },
                    ),
                  )
                : null,
          ),
          imageGeneration: ImageGenerationConfigs(
            captureImageByteFormat: .rawStraightRgba,
            outputFormat: .png,
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
                                VideoEditorConstants.maxDuration.inMilliseconds,
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
                                color: VineTheme.backgroundColor.withAlpha(128),
                                child: const SizedBox.expand(),
                              ),
                            );
                          },
                        ),
                    stream: rebuildStream,
                  ),
                  ReactiveWidget(
                    builder: (context) => VideoEditorFeedPreviewOverlay(
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
              final isOverRemoveArea = scope.isOverRemoveArea(
                details.focalPoint,
              );

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
            },
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

        // The visual chain below (Center > SizedBox > FittedBox >
        // SizedBox > Navigator) is unchanged — it owns the aspect-ratio
        // mapping (cover-fit [renderSize] into [targetSize], centered
        // in [bodySize]).
        //
        // [HitTestExpander] wraps it so that taps in the scrim /
        // letterbox zone (outside [targetSize]) are clamped to the
        // nearest point inside [targetSize] and re-dispatched into the
        // chain. Without this, `Center.hitTestChildren` drops every
        // pointer event that falls outside its child rect, so the
        // editor's top-level GestureDetector never opens an arena and
        // [onScaleStart] / [onScaleUpdate] never fire.
        return _OverlayCutArea(
          child: HitTestExpander(
            visibleSize: targetSize,
            child: Center(
              child: SizedBox.fromSize(
                size: targetSize,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox.fromSize(
                    size: renderSize,
                    child: Navigator(
                      clipBehavior: Clip.none,
                      onGenerateRoute: (_) => PageRouteBuilder(
                        pageBuilder: (_, _, _) => builder(bodySize, renderSize),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
    final targetAspectRatio = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull?.targetAspectRatio),
    );
    if (targetAspectRatio == null) return const SizedBox.shrink();

    final overlayColor = VineTheme.backgroundCamera.withAlpha(166);
    final safeArea = MediaQuery.paddingOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.biggest;
        // Compute the visible child size: largest rect with
        // targetAspectRatio that fits inside boxSize (BoxFit.contain).
        final double childWidth;
        final double childHeight;
        if (boxSize.width / boxSize.height > targetAspectRatio.value) {
          childHeight = boxSize.height;
          childWidth = boxSize.height * targetAspectRatio.value;
        } else {
          childWidth = boxSize.width;
          childHeight = boxSize.width / targetAspectRatio.value;
        }
        final verticalGap = (boxSize.height - childHeight) / 2;
        final horizontalGap = (boxSize.width - childWidth) / 2;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: .none,
          children: [
            child,

            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: .none,
                children: [
                  // Top bar — extends up into the safe area so there
                  // is no uncovered strip above the scrim when the
                  // canvas is padded below the status bar.
                  if (verticalGap > 0 || safeArea.top > 0)
                    Positioned(
                      top: -safeArea.top,
                      left: 0,
                      right: 0,
                      height: verticalGap + safeArea.top,
                      child: ColoredBox(color: overlayColor),
                    ),
                  // Bottom bar
                  if (verticalGap > 0)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: verticalGap,
                      child: ColoredBox(color: overlayColor),
                    ),
                  // Left bar
                  if (horizontalGap > 0)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: horizontalGap,
                      child: ColoredBox(color: overlayColor),
                    ),
                  // Right bar
                  if (horizontalGap > 0)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      width: horizontalGap,
                      child: ColoredBox(color: overlayColor),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Forwards hit-tests from the entire parent box into [child], even
/// when the pointer falls outside [child]'s painted area.
///
/// Layout / paint are unchanged — [child] is laid out with the parent
/// constraints and painted at offset zero, exactly like a passthrough
/// wrapper. Only [hitTest] is customised: positions outside the
/// centered [visibleSize] rect are clamped to its nearest edge so the
/// downstream hit-test chain (which clips to `Center > SizedBox`) sees
/// a position it accepts and forwards the down event normally.
///
/// Subsequent move events flow through the gesture arena that the
/// initial down opens, so [GestureDetector.onScaleUpdate] still
/// receives real-pointer deltas.
@visibleForTesting
class HitTestExpander extends SingleChildRenderObjectWidget {
  /// Creates a [HitTestExpander].
  @visibleForTesting
  const HitTestExpander({
    required this.visibleSize,
    required Widget super.child,
    super.key,
  });

  /// The size of the painted, hit-testable region inside the parent
  /// box, centered on both axes. Hits outside this rect are clamped
  /// onto its nearest edge before being forwarded.
  final Size visibleSize;

  // The render object is a true implementation detail; the widget is
  // only public for `@visibleForTesting`.
  @override
  // ignore: library_private_types_in_public_api
  _RenderHitTestExpander createRenderObject(BuildContext context) {
    return _RenderHitTestExpander(visibleSize: visibleSize);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    // ignore: library_private_types_in_public_api
    _RenderHitTestExpander renderObject,
  ) {
    renderObject.visibleSize = visibleSize;
  }
}

class _RenderHitTestExpander extends RenderProxyBox {
  _RenderHitTestExpander({required Size visibleSize})
    : _visibleSize = visibleSize;

  /// Symmetric 1 px inset applied when clamping a hit position onto
  /// the visible rect. Required because downstream transforms
  /// (FittedBox cover-fit) can map an exact `left`/`top` value to a
  /// slightly negative local coordinate after float multiplication,
  /// which then fails `Rect.contains` and drops the hit. The trailing
  /// inset is needed because `Rect.contains` excludes the right /
  /// bottom edge.
  static const double _hitTestEpsilon = 1.0;

  Size _visibleSize;
  set visibleSize(Size value) {
    if (value == _visibleSize) return;
    _visibleSize = value;
    // No markNeedsLayout/Paint: layout and paint don't depend on
    // [visibleSize] — only [hitTest] does, and that runs per-event.
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    final left = (size.width - _visibleSize.width) / 2;
    final top = (size.height - _visibleSize.height) / 2;
    final clampedDx = position.dx.clamp(
      left + _hitTestEpsilon,
      left + _visibleSize.width - _hitTestEpsilon,
    );
    final clampedDy = position.dy.clamp(
      top + _hitTestEpsilon,
      top + _visibleSize.height - _hitTestEpsilon,
    );
    return c.hitTest(result, position: Offset(clampedDx, clampedDy));
  }
}

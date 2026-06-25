// ABOUTME: Main screen for the video editor with layer editing capabilities.
// ABOUTME: Orchestrates BLoC providers, sticker precaching, and editor canvas.

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/codec_heavy_surface_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_text_editor_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/await_push_transition.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_scaffold.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// The main video editor screen for adding layers (text, stickers, effects).
///
/// Manages the [VideoEditorMainBloc] and [VideoEditorStickerBloc] lifecycle,
/// precaches sticker images, and coordinates the editor canvas with toolbars.
class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({super.key, this.draftId, this.fromLibrary = false});

  /// Optional draft ID to load an existing draft.
  final String? draftId;

  /// Whether the editor was opened from the clip library.
  final bool fromLibrary;

  /// Route name for this screen.
  static const routeName = 'video-editor';

  static const draftRouteName = '$routeName-draft';

  /// Path for this route.
  static const path = '/video-editor';

  static const draftPathWithId = '$path/:draftId';

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen>
    with CodecHeavySurfaceGuard {
  // The editor builds its preview decoder immediately, so release the feed's
  // decoder now rather than waiting for the entrance transition.
  @override
  bool get assertCodecSignalAfterEntranceTransition => false;

  final _editorKey = GlobalKey<ProImageEditorState>();
  final GlobalKey<State<StatefulWidget>> _removeAreaKey = GlobalKey();

  late final _isLoadingDraft = ValueNotifier<bool>(widget.draftId != null);

  /// Manually managed instead of using [BlocProvider.create] so we can reuse
  /// it in contexts outside the widget tree (e.g., bottom sheets opened via
  /// [VineBottomSheet.show]).
  late final VideoEditorStickerBloc _stickerBloc;

  /// Manually managed so we can dispatch [ClipEditorInitialized] after the
  /// video editor provider finishes loading (especially for drafts).
  late final ClipEditorBloc _clipEditorBloc;

  /// Manually managed so [_extractWaveform] can dispatch events without
  /// needing a child context below [MultiBlocProvider].
  late final TimelineOverlayBloc _timelineOverlayBloc;

  /// Body size notifier, updated by [_CanvasFitter].
  final _bodySizeNotifier = ValueNotifier<Size>(Size.zero);

  /// Editor zoom transform notifier (identity = not zoomed), driven by the
  /// editor's zoom matrix. The letterbox scrim applies the same transform so
  /// the bars move with the magnified frame.
  final _zoomMatrixNotifier = ValueNotifier<Matrix4>(Matrix4.identity());

  /// Tracks the previous audio tracks to detect offset changes.
  List<AudioEvent> _previousAudioTracks = const [];

  /// Track ids whose missing duration we already tried to backfill, so a
  /// failed probe isn't retried on every audio-track change.
  final Set<String> _durationHealAttempted = {};

  ProImageEditorState? get _editor => _editorKey.currentState;

  DivineVideoClip? get _clip => ref.read(clipManagerProvider).firstClipOrNull;

  /// FittedBox scale factor between bodySize and renderSize.
  double get _fittedBoxScale => VideoEditorScope.calculateFittedBoxScale(
    _bodySizeNotifier.value,
    _clip?.originalAspectRatio ?? 9 / 16,
  );

  @override
  void initState() {
    super.initState();
    Log.info(
      '🎬 Initialized (draftId: ${widget.draftId}, fromLibrary: ${widget.fromLibrary})',
      name: 'VideoEditorScreen',
      category: LogCategory.video,
    );
    _stickerBloc = VideoEditorStickerBloc(onPrecacheStickers: _precacheStickers)
      ..add(const VideoEditorStickerLoad());
    _clipEditorBloc = ClipEditorBloc(
      onFinalClipInvalidated: () {
        ref.read(videoEditorProvider.notifier).invalidateFinalRenderedClip();

        if (_editor != null) {
          // A split subdivides one clip at the same total span, so no marker
          // moves — a marker on the left half stays on the start clip, one on
          // the right stays on the end clip. Persist the current markers in
          // the same history entry as the split clips so undo/redo restores a
          // consistent timeline.
          _editor!.addHistory(
            meta: {
              ..._editor!.stateManager.activeMeta,
              VideoEditorConstants.clipsStateHistoryKey: _clipEditorBloc
                  .state
                  .clips
                  .map((e) => e.toJson())
                  .toList(),
              VideoEditorConstants.timelineMarkersStateHistoryKey:
                  _timelineOverlayBloc.state.timelineMarkers
                      .map((marker) => marker.inMilliseconds)
                      .toList(),
            },
          );
        }
      },
    );
    _timelineOverlayBloc = TimelineOverlayBloc();

    // For non-draft flows clips are already available.
    final initialClips = ref.read(clipManagerProvider).clips;
    if (initialClips.isNotEmpty) {
      _clipEditorBloc.add(ClipEditorInitialized(initialClips));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      Log.debug(
        '🎬 Initializing video editor provider',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
      );

      await ref
          .read(videoEditorProvider.notifier)
          .initialize(draftId: widget.draftId);

      Log.info(
        '🎬 Video editor initialized successfully',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
      );

      // A restored draft's text layers carry only the serialized Google Font
      // family name. Re-register the editor fonts before the canvas imports
      // the state history, otherwise the imported overlays fall back to the
      // default font (see #5181).
      if (mounted &&
          ref.read(videoEditorProvider).editorStateHistory.isNotEmpty) {
        await _preloadEditorTextFonts();
      }

      if (mounted) {
        // Clips are now loaded — initialize the clip editor BLoC.
        final clips = ref.read(clipManagerProvider).clips;
        _clipEditorBloc.add(ClipEditorInitialized(clips));

        _isLoadingDraft.value = false;
      }
    });
  }

  @override
  void dispose() {
    Log.info(
      '🎨 Disposed',
      name: 'VideoEditorScreen',
      category: LogCategory.video,
    );
    _stickerBloc.close();
    _clipEditorBloc.close();
    _timelineOverlayBloc.close();
    _isLoadingDraft.dispose();
    _bodySizeNotifier.dispose();
    _zoomMatrixNotifier.dispose();
    super.dispose();
  }

  /// Registers every text-overlay Google Font so a restored draft resolves
  /// the font family stored on its text layers.
  ///
  /// Calling a `GoogleFonts.*` getter registers its [FontLoader] as a side
  /// effect; the serialized [TextLayer] only keeps the family string, so the
  /// loader must be re-registered each session before the overlays render.
  /// Already-loaded fonts resolve instantly, so the timeout only guards the
  /// first, uncached load.
  Future<void> _preloadEditorTextFonts() async {
    for (final font in VideoEditorConstants.textFonts) {
      font();
    }
    await GoogleFonts.pendingFonts().timeout(
      VideoEditorConstants.textFontLoadTimeout,
      onTimeout: () => const [],
    );
  }

  /// Precaches stickers for faster display.
  void _precacheStickers(List<StickerData> stickers) {
    if (!mounted) return;

    Log.debug(
      '🎨 Precaching ${stickers.length} stickers',
      name: 'VideoEditorScreen',
      category: LogCategory.video,
    );

    final estimatedSize = MediaQuery.sizeOf(context) / 3;

    for (final sticker in stickers) {
      // SVG assets are vector and don't need raster precaching.
      if (sticker.networkUrl == null) continue;

      unawaited(
        precacheImage(
          NetworkImage(sticker.networkUrl!),
          context,
          size: estimatedSize,
        ),
      );
    }
  }

  /// Opens the camera recorder as a modal overlay over the editor.
  ///
  /// Snapshots the current clip IDs before opening so that any newly recorded
  /// clips can be rolled back if the user cancels (`result != true`).
  /// On success or cancel, calls [_syncClipsToEditor] to keep the
  /// [ClipEditorBloc] in sync.
  Future<void> _openCamera({required ClipEditorBloc clipEditorBloc}) async {
    final initialIds = ref
        .read(clipManagerProvider)
        .clips
        .map((c) => c.id)
        .toSet();

    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder<bool>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: VineTheme.transparent,
        pageBuilder: (_, _, _) => const VideoRecorderScreen(fromEditor: true),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    if (result != true) {
      final notifier = ref.read(clipManagerProvider.notifier);
      final newClips = ref
          .read(clipManagerProvider)
          .clips
          .where((c) => !initialIds.contains(c.id))
          .toList();
      for (final clip in newClips) {
        await notifier.removeClipById(clip.id);
      }
    }

    _syncClipsToEditor(clipEditorBloc: clipEditorBloc);
  }

  Future<void> _openClipsEditor({
    required VideoEditorMainBloc mainBloc,
    required ClipEditorBloc clipEditorBloc,
  }) async {
    // Pause playback while the library is open.
    mainBloc
      ..add(const VideoEditorMainOpenSubEditor(.clips))
      ..add(const VideoEditorExternalPauseRequested(isPaused: true));
    final currentClips = ref.read(clipManagerProvider).clips;

    final newClips = await VineBottomSheet.show<List<DivineVideoClip>>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 1,
      minChildSize: 0.9,
      buildScrollBody: (scrollController) => LibraryScreen(
        initialTabIndex: 1,
        selectionMode: true,
        editorClips: currentClips,
        scrollController: scrollController,
      ),
    );

    mainBloc.add(const VideoEditorMainSubEditorClosed());

    if (newClips != null && newClips.isNotEmpty) {
      Log.info(
        '🎬 Adding ${newClips.length} new clips from library',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
      );

      final clipManager = ref.read(clipManagerProvider.notifier);
      clipManager.addMultipleClips(newClips);

      _syncClipsToEditor(clipEditorBloc: clipEditorBloc);
    }
  }

  /// Syncs the current clip list from [clipManagerProvider] into the
  /// [ClipEditorBloc] and appends a history entry to the pro_image_editor.
  void _syncClipsToEditor({required ClipEditorBloc clipEditorBloc}) {
    // Sync the updated clip list into the editor BLoC.
    final updatedClips = ref.read(clipManagerProvider).clips;
    clipEditorBloc.add(ClipEditorInitialized(updatedClips));

    if (_editor != null) {
      _editor!.setClipState(updatedClips);
    }
  }

  /// Opens the sticker picker sheet and adds the selected sticker as a layer.
  ///
  /// Resets the search query before opening and adds a [WidgetLayer] to the
  /// editor canvas if a sticker is selected.
  Future<void> _addStickers() async {
    // Reset search when opening the sheet
    _stickerBloc.add(const VideoEditorStickerSearch(''));

    final sticker = await VineBottomSheet.show<StickerData>(
      context: context,
      title: Text(context.l10n.videoEditorStickers),
      maxChildSize: 1,
      initialChildSize: 1,
      minChildSize: 0.8,
      buildScrollBody: (scrollController) => BlocProvider.value(
        value: _stickerBloc,
        child: VideoEditorStickerSheet(scrollController: scrollController),
      ),
    );

    if (sticker != null) {
      Log.debug(
        '🎨 Adding sticker layer: ${sticker.description}',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
      );
      // 1/3 of screen width, converted to render coordinates
      final bodySize = _bodySizeNotifier.value;
      final stickerWidth = min(300.0, (bodySize.width / 3) / _fittedBoxScale);

      final layer = WidgetLayer(
        width: stickerWidth,
        widget: VideoEditorSticker(
          sticker: sticker,
          enableLimitCacheSize: false,
        ),
        meta: sticker.toJson(),
        exportConfigs: WidgetLayerExportConfigs(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          meta: sticker.toJson(),
        ),
      );
      _editor!.addLayer(layer, blockSelectLayer: true);
    }
  }

  /// Opens the text editor screen to add or edit a text layer.
  ///
  /// If [layer] is provided, the editor is initialized with its values for
  /// editing. Otherwise, a new text layer is created.
  ///
  /// Returns the resulting [TextLayer] if the user confirms, or `null` if
  /// cancelled.
  Future<TextLayer?> _addEditTextLayer({
    required VideoEditorMainBloc mainBloc,
    required VideoEditorTextBloc textBloc,
    TextLayer? layer,
  }) async {
    Log.debug(
      '🎨 Opening text editor (editing: ${layer != null})',
      name: 'VideoEditorScreen',
      category: LogCategory.video,
    );
    mainBloc.add(const VideoEditorMainOpenSubEditor(.text));

    final result = await Navigator.push<TextLayer>(
      context,
      PageRouteBuilder<TextLayer>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: VineTheme.transparent,
        pageBuilder: (_, _, _) => BlocProvider.value(
          value: textBloc,
          child: VideoTextEditorScreen(layer: layer),
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    textBloc.add(const VideoEditorTextClosePanels());
    mainBloc.add(const VideoEditorMainSubEditorClosed());

    if (result == null || layer != null) return result;

    return result.copyWith(scale: 1 / _fittedBoxScale);
  }

  Future<void> _openMusicLibrary() async {
    var result = await AudioSelectionBottomSheet.show(context);
    if (!mounted || result == null) return;

    // Nostr sounds sometimes carry no duration tag, which otherwise persists a
    // zero-length timeline window (endTime=0). Probe the source once and store
    // the real duration so the track is placed and rendered correctly.
    final durationSecs = await _resolveSoundDurationSecs(result);
    if (!mounted) return;

    final editor = _editorKey.currentState;
    if (editor == null) return;

    final audioDuration = Duration(
      milliseconds: (durationSecs * 1000).toInt(),
    );
    final clipDuration = _clipEditorBloc.state.totalDuration;
    const maxDuration = VideoEditorConstants.maxDuration;
    final endTime = [
      audioDuration,
      clipDuration,
      maxDuration,
    ].reduce((a, b) => a < b ? a : b);

    result = result.copyWith(
      id: '${result.id}-${DateTime.now().millisecondsSinceEpoch}',
      startTime: .zero,
      endTime: endTime,
      duration: durationSecs > 0 ? durationSecs : null,
    );
    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: [
          ...editor.stateManager.audioTracks.map((e) => e.toJson()),
          result.toJson(),
        ],
      },
    );
  }

  /// Resolves the sound's duration in seconds, probing the source via
  /// [ProVideoEditor.getMetadata] when the event carries no duration tag
  /// (common for Nostr sounds). Returns the tagged duration when present, or
  /// `0` when it can't be determined.
  Future<double> _resolveSoundDurationSecs(AudioEvent sound) async {
    final tagged = sound.duration ?? 0;
    if (tagged > 0) return tagged;

    final path = sound.isBundled ? sound.assetPath : sound.url;
    if (path == null || path.isEmpty) return 0;
    try {
      final source = sound.isBundled
          ? EditorVideo.asset(path)
          : path.startsWith('/')
          ? EditorVideo.file(path)
          : EditorVideo.network(path);
      final metadata = await ProVideoEditor.instance.getMetadata(source);
      return metadata.duration.inMilliseconds / 1000.0;
    } catch (e, s) {
      Log.error(
        'Failed to probe audio duration for ${sound.id}',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
        error: e,
        stackTrace: s,
      );
      return 0;
    }
  }

  /// Backfills a real duration onto persisted audio tracks that carry none.
  ///
  /// Sounds added before [_resolveSoundDurationSecs] existed (or from Nostr
  /// events without a duration tag) persist `duration == 0`, which becomes a
  /// zero-length timeline window (`endTime == 0`) — an invisible bar. Probe the
  /// source once, recompute `endTime`, and rewrite the editor history so the
  /// repair persists. Each track is attempted at most once per session.
  Future<void> _healMissingAudioDurations(List<AudioEvent> tracks) async {
    final pending = tracks
        .where(
          (t) =>
              (t.duration ?? 0) <= 0 && !_durationHealAttempted.contains(t.id),
        )
        .toList(growable: false);
    if (pending.isEmpty) return;
    _durationHealAttempted.addAll(pending.map((t) => t.id));

    final resolved = <String, double>{};
    for (final track in pending) {
      final secs = await _resolveSoundDurationSecs(track);
      if (secs > 0) resolved[track.id] = secs;
    }
    if (!mounted || resolved.isEmpty) return;

    final editor = _editorKey.currentState;
    if (editor == null) return;

    final clipDuration = _clipEditorBloc.state.totalDuration;
    const maxDuration = VideoEditorConstants.maxDuration;
    final healed = editor.stateManager.audioTracks.map((track) {
      final secs = resolved[track.id];
      if (secs == null) return track;
      final audioDuration = Duration(milliseconds: (secs * 1000).toInt());
      final endTime = [
        audioDuration,
        clipDuration,
        maxDuration,
      ].reduce((a, b) => a < b ? a : b);
      return track.copyWith(duration: secs, endTime: endTime);
    }).toList();

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: healed
            .map((e) => e.toJson())
            .toList(),
      },
    );
  }

  /// Extracts waveform data for an audio track and updates the timeline
  /// overlay with the samples.
  Future<void> _extractWaveform(AudioEvent audio) async {
    final path = audio.isBundled ? audio.assetPath : audio.url;
    if (path == null) return;

    try {
      final video = audio.isBundled
          ? EditorVideo.asset(path)
          : path.startsWith('/')
          ? EditorVideo.file(path)
          : EditorVideo.network(path);
      final data = await ProVideoEditor.instance.getWaveform(
        WaveformConfigs(
          video: video,
          startTime: audio.startOffset,
          endTime:
              audio.startOffset +
              Duration(
                milliseconds:
                    ((audio.duration ??
                                VideoEditorConstants.maxDuration.inSeconds) *
                            1000)
                        .toInt(),
              ),
        ),
      );
      if (!mounted) return;
      _timelineOverlayBloc.add(
        TimelineOverlayWaveformLoaded(
          itemId: audio.id,
          leftChannel: data.leftChannel,
          rightChannel: data.rightChannel,
        ),
      );
    } catch (e, s) {
      Log.error(
        'Failed to extract timeline waveform: $e',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Awaits the entrance transition of a screen pushed over the editor.
  ///
  /// Uses the screen's own context, which sits **above** the canvas's nested
  /// `Navigator`, so `ModalRoute.of` resolves to the go_router editor route
  /// whose `secondaryAnimation` the push actually drives. The canvas's own
  /// context resolves to that inner route instead, which the outer push never
  /// animates — so the canvas delegates here.
  Future<void> _awaitMetadataCoverTransition() => awaitPushTransition(
    context,
    timeout: VideoEditorConstants.coverTransitionTimeout,
  );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => VideoEditorMainBloc()),
        BlocProvider.value(value: _stickerBloc),
        BlocProvider(create: (_) => VideoEditorFilterBloc()),
        BlocProvider(create: (_) => VideoEditorDrawBloc()),
        BlocProvider(create: (_) => VideoEditorTextBloc()),
        BlocProvider.value(value: _timelineOverlayBloc),
        BlocProvider.value(value: _clipEditorBloc),
      ],
      child: BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
        listenWhen: (previous, current) =>
            previous.audioTracks != current.audioTracks,
        listener: (context, state) {
          final previousById = {for (final a in _previousAudioTracks) a.id: a};
          _previousAudioTracks = state.audioTracks;

          final existingWaveformIds = state.items
              .where((i) => i.waveformLeftChannel != null)
              .map((i) => i.id)
              .toSet();

          for (final audio in state.audioTracks) {
            final hadWaveform = existingWaveformIds.contains(audio.id);
            final prev = previousById[audio.id];
            final offsetChanged =
                prev != null && prev.startOffset != audio.startOffset;

            if (!hadWaveform || offsetChanged) {
              unawaited(_extractWaveform(audio));
            }
          }

          unawaited(_healMissingAudioDurations(state.audioTracks));
        },
        child: Builder(
          builder: (context) {
            final clip = ref.watch(
              clipManagerProvider.select((s) => s.firstClipOrNull),
            );
            return VideoEditorScope(
              editorKey: _editorKey,
              removeAreaKey: _removeAreaKey,
              originalClipAspectRatio: clip?.originalAspectRatio ?? 9 / 16,
              bodySizeNotifier: _bodySizeNotifier,
              zoomMatrixNotifier: _zoomMatrixNotifier,
              fromLibrary: widget.fromLibrary,
              onOpenCamera: () =>
                  _openCamera(clipEditorBloc: context.read<ClipEditorBloc>()),
              onOpenClipsEditor: () {
                final mainBloc = context.read<VideoEditorMainBloc>();
                final clipEditorBloc = context.read<ClipEditorBloc>();
                _openClipsEditor(
                  mainBloc: mainBloc,
                  clipEditorBloc: clipEditorBloc,
                );
              },
              onAddStickers: _addStickers,
              onAddEditTextLayer: ([layer]) {
                final mainBloc = context.read<VideoEditorMainBloc>();
                final textBloc = context.read<VideoEditorTextBloc>();

                return _addEditTextLayer(
                  mainBloc: mainBloc,
                  textBloc: textBloc,
                  layer: layer,
                );
              },
              onOpenMusicLibrary: _openMusicLibrary,
              awaitPushCoverTransition: _awaitMetadataCoverTransition,
              child: ValueListenableBuilder<bool>(
                valueListenable: _isLoadingDraft,
                builder: (_, isLoading, _) =>
                    VideoEditorScaffold(isLoading: isLoading),
              ),
            );
          },
        ),
      ),
    );
  }
}

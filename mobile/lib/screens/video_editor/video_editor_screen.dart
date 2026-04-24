// ABOUTME: Main screen for the video editor with layer editing capabilities.
// ABOUTME: Orchestrates BLoC providers, sticker precaching, and editor canvas.

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_text_editor_screen.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_adjust_sheet.dart';
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
  const VideoEditorScreen({
    super.key,
    this.draftId,
    this.fromLibrary = false,
  });

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

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
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

  /// Tracks the previous audio tracks to detect offset changes.
  List<AudioEvent> _previousAudioTracks = const [];

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
          _editor!.addHistory(
            meta: {
              ..._editor!.stateManager.activeMeta,
              VideoEditorConstants.clipsStateHistoryKey: _clipEditorBloc
                  .state
                  .clips
                  .map((e) => e.toJson())
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
    super.dispose();
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

      // Sync the updated clip list into the editor BLoC.
      final updatedClips = ref.read(clipManagerProvider).clips;
      clipEditorBloc.add(ClipEditorInitialized(updatedClips));

      if (_editor != null) {
        _editor!.addHistory(
          meta: {
            ..._editor!.stateManager.activeMeta,
            VideoEditorConstants.clipsStateHistoryKey: updatedClips
                .map((e) => e.toJson())
                .toList(),
          },
        );
      }
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
        widget: Semantics(
          label: sticker.description,
          child: VideoEditorSticker(
            sticker: sticker,
            enableLimitCacheSize: false,
          ),
        ),
        exportConfigs: WidgetLayerExportConfigs(
          assetPath: sticker.assetPath,
          networkUrl: sticker.networkUrl,
          meta: {'description': sticker.description, 'tags': sticker.tags},
        ),
      );
      _editor!.addLayer(layer, blockSelectLayer: true);
    }
  }

  /// Opens the audio volume adjust sheet.
  Future<void> _adjustVolume() async {
    final notifier = ref.read(videoEditorProvider.notifier);
    final state = ref.read(videoEditorProvider);
    final initialRecordedVolume = state.originalAudioVolume;
    final initialCustomVolume = state.customAudioVolume;

    final result = await VineBottomSheet.show<AudioAdjustResult>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: VideoEditorAudioAdjustSheet(
        initialRecordedVolume: initialRecordedVolume,
        initialCustomVolume: initialCustomVolume,
        onRecordedVolumeChanged: notifier.previewOriginalAudioVolume,
        onCustomVolumeChanged: notifier.previewCustomAudioVolume,
      ),
    );

    if (result != null) {
      notifier
        ..setOriginalAudioVolume(result.recordedVolume)
        ..setCustomAudioVolume(result.customVolume);
    } else {
      // Dismissed — restore previewed values without side effects
      notifier
        ..previewOriginalAudioVolume(initialRecordedVolume)
        ..previewCustomAudioVolume(initialCustomVolume);
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
    var result = await VineBottomSheet.show<AudioEvent>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 1,
      minChildSize: 0.8,
      buildScrollBody: (scrollController) =>
          AudioSelectionBottomSheet(scrollController: scrollController),
    );

    final editor = _editorKey.currentState;

    if (!mounted || editor == null || result == null) return;

    final audioDuration = Duration(
      milliseconds: ((result.duration ?? 0) * 1000).toInt(),
    );
    final clipDuration = _clipEditorBloc.state.totalDuration;
    const maxDuration = VideoEditorConstants.maxDuration;
    final endTime = [audioDuration, clipDuration, maxDuration].reduce(
      (a, b) => a < b ? a : b,
    );

    result = result.copyWith(
      id: '${result.id}-${DateTime.now().millisecondsSinceEpoch}',
      startTime: .zero,
      endTime: endTime,
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

  /// Extracts waveform data for an audio track and updates the timeline
  /// overlay with the samples.
  Future<void> _extractWaveform(AudioEvent audio) async {
    final path = audio.isBundled ? audio.assetPath : audio.url;
    if (path == null) return;

    try {
      final video = audio.isBundled
          ? EditorVideo.asset(path)
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
          final previousById = {
            for (final a in _previousAudioTracks) a.id: a,
          };
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
              fromLibrary: widget.fromLibrary,
              onOpenClipsEditor: () {
                final mainBloc = context.read<VideoEditorMainBloc>();
                final clipEditorBloc = context.read<ClipEditorBloc>();
                _openClipsEditor(
                  mainBloc: mainBloc,
                  clipEditorBloc: clipEditorBloc,
                );
              },
              onAddStickers: _addStickers,
              onAdjustVolume: _adjustVolume,
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

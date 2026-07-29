// ABOUTME: Full-screen green-screen editor for a single clip: auto-detect or
// ABOUTME: tune the key, choose what replaces it, all over a live preview that
// ABOUTME: needs no render.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/video_editor/chroma_key/chroma_key_editor_cubit.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/utils/image_orientation.dart';
import 'package:openvine/utils/loop_restarts.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_clip_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_controls.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_keyed_video.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, ProVideoEditor, ProgressModel;
import 'package:unified_logger/unified_logger.dart';

/// Sets up a clip's green screen.
///
/// Tuning is free, driven by the preview shader. Confirming dispatches the
/// bake to [ClipEditorBloc] and keeps the screen up — blocked, with the
/// render's progress — until the clip's new file lands, so the user sees the
/// work finish instead of being dropped back onto an unchanged timeline.
///
/// Re-opening a clip that already has a key restores its settings and previews
/// the footage as it was *before* the bake, so adjusting the key is a fresh
/// pass over clean pixels rather than a second key stacked on the first.
class VideoClipChromaKeyScreen extends StatefulWidget {
  const VideoClipChromaKeyScreen({
    required this.clip,
    @visibleForTesting this.detectOnOpen = true,
    super.key,
  });

  final DivineVideoClip clip;

  /// Whether a clip without a key measures itself as soon as the screen opens.
  @visibleForTesting
  final bool detectOnOpen;

  @override
  State<VideoClipChromaKeyScreen> createState() =>
      _VideoClipChromaKeyScreenState();
}

class _VideoClipChromaKeyScreenState extends State<VideoClipChromaKeyScreen> {
  late final ChromaKeyEditorCubit _cubit;
  DivineVideoPlayerController? _player;

  @override
  void initState() {
    super.initState();
    _cubit = ChromaKeyEditorCubit(
      video: EditorVideo.file(_previewPath),
      initialChromaKey: widget.clip.chromaKey,
    );
    // Measuring beats guessing and costs one thumbnail decode, so a clip
    // without a key opens with the screen colour already measured. A clip that
    // has one keeps it: re-measuring would throw the user's tuning away.
    if (widget.detectOnOpen && widget.clip.chromaKey == null) {
      unawaited(_cubit.detectFromFootage());
    }
    unawaited(_initializePlayer());
  }

  /// The footage the preview and the measurement run on.
  ///
  /// For an already-keyed clip that is the pre-bake original: keying the baked
  /// video again would show a key applied twice, and measuring it would sample
  /// the replaced background instead of the screen.
  /// Whether the pre-key footage is still on disk to restore.
  late final bool _hasKeySource = () {
    final source = widget.clip.chromaKeySourcePath;
    return source != null && File(source).existsSync();
  }();

  String get _previewPath {
    final source = widget.clip.chromaKeySourcePath;
    if (source != null && File(source).existsSync()) return source;
    return widget.clip.video?.file?.path ?? '';
  }

  Future<void> _initializePlayer() async {
    final path = _previewPath;
    if (path.isEmpty) return;

    // Re-check `mounted` after every await and tear the controller down when
    // this screen went away mid-load, rather than leaking it.
    final player = DivineVideoPlayerController(useTexture: true);
    try {
      await player.initialize();
      if (!mounted) return await player.dispose();
      await player.setSource(
        VideoClip(
          uri: path,
          start: widget.clip.trimStart,
          end: widget.clip.duration - widget.clip.trimEnd,
          // Muted: the clip loops for minutes while the key is tuned, and this
          // screen is a purely visual judgement.
          volume: 0,
          playbackSpeed: widget.clip.playbackSpeed ?? 1.0,
        ),
      );
      if (!mounted) return await player.dispose();
      await player.setLooping(looping: true);
      if (!mounted) return await player.dispose();
      await player.play();
      if (!mounted) return await player.dispose();
      setState(() => _player = player);
    } catch (error, stackTrace) {
      Log.error(
        'Chroma-key preview player failed to start',
        name: 'VideoClipChromaKeyScreen',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      await player.dispose();
    }
  }

  /// Fires when the looping clip wraps, so a video backdrop restarts with it.
  ///
  /// Broadcast because the backdrop widget subscribes and unsubscribes as the
  /// background type changes.
  Stream<void> get _clipRestarts => _restarts ??= loopRestarts(
    _player!.stateStream.map((state) => state.position),
  ).asBroadcastStream();
  Stream<void>? _restarts;

  @override
  void dispose() {
    unawaited(_player?.dispose());
    unawaited(_cubit.close());
    super.dispose();
  }

  Future<void> _pickBackground(ClipChromaKeyBackgroundType type) async {
    switch (type) {
      case ClipChromaKeyBackgroundType.transparent:
        _cubit.useTransparentBackground();
      case ClipChromaKeyBackgroundType.color:
        final picked = await showFullColorPicker(
          context,
          initialColor:
              _cubit.state.chromaKey.key.backgroundColor ??
              VineTheme.surfaceBackground,
        );
        // Only the RGB channels are used — both renderers fill the keyed area
        // solidly — so a translucent pick would be rejected by the key.
        if (picked != null) {
          _cubit.useColorBackground(picked.withValues(alpha: 1));
        }
      case ClipChromaKeyBackgroundType.image:
        await _pickImageBackground();
      case ClipChromaKeyBackgroundType.video:
        if (!mounted) return;
        final path = await showChromaKeyClipPicker(context);
        if (path != null) _cubit.useVideoBackground(path);
    }
  }

  Future<void> _pickImageBackground() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    try {
      // `image_picker` hands back a cache path the OS may prune, while clip
      // state persists as a documents-relative basename — so take a copy we
      // own before pointing the key at it.
      //
      // The copy is normalized rather than byte-for-byte: a portrait photo is
      // usually stored as landscape pixels plus an EXIF orientation tag, and
      // the renderer decodes raw bytes, so it would show the backdrop rotated.
      // Baking the rotation in also caps the photo to a sane size for a
      // backdrop that is stretched to the video frame anyway.
      final documentsPath = await getDocumentsPath();
      final target = p.join(
        documentsPath,
        'chroma_bg_${widget.clip.id}_'
        '${DateTime.now().microsecondsSinceEpoch}.png',
      );
      final normalized = await compute(
        bakeImageOrientation,
        await File(picked.path).readAsBytes(),
      );
      await File(target).writeAsBytes(normalized, flush: true);
      _cubit.useImageBackground(target);
    } catch (error, stackTrace) {
      Log.error(
        'Failed to copy the chroma-key background image',
        name: 'VideoClipChromaKeyScreen',
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoEditorChromaKeyImagePickFailed,
        ),
      );
    }
  }

  /// The render id of *this* clip's bake, or `null` when the bake in flight
  /// belongs to another clip.
  ///
  /// Scoped to the clip rather than the bloc-wide flag so a bake started
  /// elsewhere never locks this screen.
  String? _bakeInFlight(ClipEditorState state) =>
      state.isChromaKeying && state.chromaKeyingClipId == widget.clip.id
      ? state.chromaKeyingRenderId
      : null;

  @override
  Widget build(BuildContext context) {
    final bakingRenderId = context.select<ClipEditorBloc, String?>(
      (bloc) => _bakeInFlight(bloc.state),
    );
    final isBaking = bakingRenderId != null;

    return BlocProvider<ChromaKeyEditorCubit>.value(
      value: _cubit,
      child: PopScope(
        // A half-written clip file is not something to hand back, so the
        // system back gesture waits with everything else.
        canPop: !isBaking,
        child: Scaffold(
          backgroundColor: VineTheme.surfaceBackground,
          body: SafeArea(
            child: MultiBlocListener(
              listeners: [
                BlocListener<ChromaKeyEditorCubit, ChromaKeyEditorState>(
                  listenWhen: (previous, current) =>
                      previous.detectionStatus != current.detectionStatus,
                  listener: (context, state) {
                    if (state.detectionStatus !=
                        ChromaKeyDetectionStatus.failure) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      DivineSnackbarContainer.snackBar(
                        context.l10n.videoEditorChromaKeyDetectFailed,
                      ),
                    );
                    context
                        .read<ChromaKeyEditorCubit>()
                        .acknowledgeDetectionFailure();
                  },
                ),
                BlocListener<ClipEditorBloc, ClipEditorState>(
                  listenWhen: (previous, current) =>
                      !identical(
                        previous.lastChromaKeyResult,
                        current.lastChromaKeyResult,
                      ) &&
                      current.lastChromaKeyResult != null,
                  listener: _onBakeResult,
                ),
              ],
              child: Stack(
                children: [
                  Column(
                    children: [
                      VideoEditorToolbar(
                        onClose: () {
                          if (!isBaking) Navigator.of(context).pop();
                        },
                        onDone: isBaking ? null : () => _confirm(context),
                        closeSemanticLabel:
                            context.l10n.videoEditorChromaKeyCloseSemanticLabel,
                        doneSemanticLabel:
                            context.l10n.videoEditorChromaKeyDoneSemanticLabel,
                        center: Text(
                          context.l10n.videoEditorChromaKeyTitle,
                          style: VineTheme.titleMediumFont(
                            color: VineTheme.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _Preview(
                          aspectRatio: widget.clip.targetAspectRatio.value,
                          player: _player,
                          restarts: _player == null ? null : _clipRestarts,
                        ),
                      ),
                      // Undoing a key is a file swap, not a render — the clip
                      // kept the footage it was applied to. Only offered when
                      // that footage is still there to go back to.
                      if (widget.clip.chromaKey != null && _hasKeySource)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DivineButton(
                            label: context.l10n.videoEditorChromaKeyRemove,
                            type: .ghost,
                            size: .small,
                            expanded: true,
                            onPressed: isBaking
                                ? null
                                : () => context.read<ClipEditorBloc>().add(
                                    ClipEditorChromaKeyRemoved(widget.clip.id),
                                  ),
                          ),
                        ),
                      Flexible(
                        child: ChromaKeyControls(
                          onPickBackground: _pickBackground,
                        ),
                      ),
                    ],
                  ),
                  if (bakingRenderId != null)
                    _BakingOverlay(renderId: bakingRenderId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirm(BuildContext context) {
    // The bloc owns the render so it survives this screen; the screen stays up
    // and blocked until the result lands, which is what makes the wait legible.
    context.read<ClipEditorBloc>().add(
      ClipEditorChromaKeyRequested(
        clipId: widget.clip.id,
        chromaKey: _cubit.state.chromaKey,
      ),
    );
  }

  void _onBakeResult(BuildContext context, ClipEditorState state) {
    switch (state.lastChromaKeyResult) {
      case ChromaKeySuccess():
        Navigator.of(context).pop();
      case ChromaKeyFailure():
        // Stay open: the settings are still on screen, so retrying costs
        // nothing but another tap.
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorChromaKeyFailed,
          ),
        );
      case ChromaKeyDiscarded():
        // The clip is gone from under us — there is nothing left to edit.
        Navigator.of(context).pop();
      case null:
        break;
    }
  }
}

/// Blocks the screen while the clip is re-rendered, showing the render's own
/// progress rather than an indefinite spinner.
class _BakingOverlay extends StatelessWidget {
  const _BakingOverlay({required this.renderId});

  final String renderId;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: VineTheme.backgroundCamera.withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              const BrandedLoadingIndicator(size: 44),
              Text(
                context.l10n.videoEditorChromaKeyApplying,
                style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
              ),
              // RepaintBoundary: without it the progress text repaints the
              // whole overlay on every tick.
              RepaintBoundary(
                child: StreamBuilder<ProgressModel>(
                  stream: ProVideoEditor.instance.progressStreamById(renderId),
                  builder: (context, snapshot) {
                    final progress = snapshot.data?.progress ?? 0;
                    return Text(
                      '${(progress * 100).round()}%',
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The looping clip with the key applied live.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.aspectRatio,
    required this.player,
    required this.restarts,
  });

  final double aspectRatio;
  final DivineVideoPlayerController? player;

  /// Loop signal handed to a video backdrop so it restarts with the clip.
  final Stream<void>? restarts;

  @override
  Widget build(BuildContext context) {
    final controller = player;
    if (controller == null) {
      return const Center(child: BrandedLoadingIndicator());
    }

    final chromaKey = context.select(
      (ChromaKeyEditorCubit c) => c.state.chromaKey,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ChromaKeyedVideo(
              chromaKey: chromaKey,
              backdropRestarts: restarts,
              child: DivineVideoPlayer(controller: controller),
            ),
          ),
        ),
      ),
    );
  }
}

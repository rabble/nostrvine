// ABOUTME: Main screen for the video editor with layer editing capabilities.
// ABOUTME: Orchestrates BLoC providers, sticker precaching, and editor canvas.

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_editor/video_clip_editor_screen.dart';
import 'package:openvine/screens/video_editor/video_text_editor_screen.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_editor/audio_editor/video_editor_audio_adjust_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_scaffold.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

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

  /// Body size notifier, updated by [_CanvasFitter].
  final _bodySizeNotifier = ValueNotifier<Size>(Size.zero);

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      Log.debug(
        '🎬 Initializing video editor provider',
        name: 'VideoClipEditorScreen',
        category: LogCategory.video,
      );

      await ref
          .read(videoEditorProvider.notifier)
          .initialize(draftId: widget.draftId);

      Log.info(
        '🎬 Video editor initialized successfully',
        name: 'VideoClipEditorScreen',
        category: LogCategory.video,
      );

      if (mounted) {
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
      final ImageProvider? provider = sticker.networkUrl != null
          ? NetworkImage(sticker.networkUrl!)
          : sticker.assetPath != null
          ? AssetImage(sticker.assetPath!)
          : null;

      if (provider == null) continue;

      unawaited(precacheImage(provider, context, size: estimatedSize));
    }
  }

  Future<void> _openClipsEditor({
    required VideoEditorMainBloc mainBloc,
  }) async {
    // Pause playback while the clip editor is open.
    mainBloc
      ..add(const VideoEditorMainOpenSubEditor(.clips))
      ..add(const VideoEditorExternalPauseRequested(isPaused: true));
    final initialClips = ref.read(clipManagerProvider).clips;

    final clips = await Navigator.push<List<DivineVideoClip>>(
      context,
      _FadeUpPageRoute<List<DivineVideoClip>>(
        child: VideoClipEditorScreen(
          initialClips: initialClips.map((e) => e.copyWith()).toList(),
        ),
      ),
    );

    mainBloc.add(const VideoEditorMainSubEditorClosed());

    if (clips != null) {
      Log.info(
        '🎬 Clips changed after clip editor',
        name: 'VideoEditorScreen',
        category: LogCategory.video,
      );

      final clipManager = ref.read(clipManagerProvider.notifier);
      clipManager.replaceClips(clips);
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
      // TODO(l10n): Replace with context.l10n when localization is added.
      title: const Text('Stickers'),
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

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => VideoEditorMainBloc()),
        BlocProvider.value(value: _stickerBloc),
        BlocProvider(create: (_) => VideoEditorFilterBloc()),
        BlocProvider(create: (_) => VideoEditorDrawBloc()),
        BlocProvider(create: (_) => VideoEditorTextBloc()),
      ],
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
              _openClipsEditor(mainBloc: mainBloc);
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
            child: ValueListenableBuilder<bool>(
              valueListenable: _isLoadingDraft,
              builder: (_, isLoading, _) =>
                  VideoEditorScaffold(isLoading: isLoading),
            ),
          );
        },
      ),
    );
  }
}

class _FadeUpPageRoute<T> extends PageRoute<T> {
  _FadeUpPageRoute({required this.child});

  final Widget child;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const FadeUpwardsPageTransitionsBuilder().buildTransitions(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

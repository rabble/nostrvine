// ABOUTME: Main screen for the video editor with layer editing capabilities.
// ABOUTME: Orchestrates BLoC providers, sticker precaching, and editor canvas.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/screens/video_editor/video_text_editor_screen.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_scaffold.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The main video editor screen for adding layers (text, stickers, effects).
///
/// Manages the [VideoEditorMainBloc] and [VideoEditorStickerBloc] lifecycle,
/// precaches sticker images, and coordinates the editor canvas with toolbars.
class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'video-editor';

  /// Path for this route.
  static const path = '/video-editor';

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  final _editorKey = GlobalKey<ProImageEditorState>();

  /// Manually managed instead of using [BlocProvider.create] so we can reuse
  /// it in contexts outside the widget tree (e.g., bottom sheets opened via
  /// [VineBottomSheet.show]).
  late final VideoEditorStickerBloc _stickerBloc;

  ProImageEditorState? get _editor => _editorKey.currentState;

  @override
  void initState() {
    super.initState();
    _stickerBloc = VideoEditorStickerBloc(onPrecacheStickers: _precacheStickers)
      ..add(const VideoEditorStickerLoad());
  }

  @override
  void dispose() {
    _stickerBloc.close();
    super.dispose();
  }

  /// Precaches stickers for faster display.
  void _precacheStickers(List<StickerData> stickers) {
    if (!mounted) return;

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
      scrollable: false,
      isScrollControlled: true,
      body: BlocProvider.value(
        value: _stickerBloc,
        child: const VideoEditorStickerSheet(),
      ),
    );

    if (sticker != null) {
      final layer = WidgetLayer(
        width: 120,
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
    mainBloc.add(const VideoEditorMainOpenSubEditor(.text));

    final result = await Navigator.push<TextLayer>(
      context,
      PageRouteBuilder<TextLayer>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
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

    return result;
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
          return VideoEditorScope(
            editorKey: _editorKey,
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
            child: const VideoEditorScaffold(),
          );
        },
      ),
    );
  }
}

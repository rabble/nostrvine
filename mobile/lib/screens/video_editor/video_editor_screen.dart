// ABOUTME: Main screen for the video editor with layer editing capabilities.
// ABOUTME: Orchestrates BLoC providers, sticker precaching, and editor canvas.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_top_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker_sheet.dart';
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
      );
      _editor!.addLayer(layer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => VideoEditorMainBloc()),
        BlocProvider.value(value: _stickerBloc),
      ],
      child: VideoEditorScope(
        editorKey: _editorKey,
        onAddStickers: _addStickers,
        child: Material(
          color: VineTheme.surfaceContainerHigh,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    return ClipRRect(
                      borderRadius: const .vertical(bottom: .circular(32)),
                      child: Stack(
                        clipBehavior: .none,
                        fit: .expand,
                        children: [
                          VideoEditorCanvas(
                            editorKey: _editorKey,
                            constraints: constraints,
                          ),
                          const VideoEditorMainTopBar(),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const _BottomActions(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom section that switches between the toolbar and layer remove area.
///
/// Hides the [VideoEditorMainBottomBar] when the user is interacting with
/// a layer (scaling/rotating) to show a remove area instead.
class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: BlocSelector<VideoEditorMainBloc, VideoEditorMainState, bool>(
          selector: (state) => state.isLayerInteractionActive,
          builder: (context, isLayerInteractionActive) {
            return AnimatedSwitcher(
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: .expand,
                alignment: .center,
                children: <Widget>[...previousChildren, ?currentChild],
              ),
              duration: const Duration(milliseconds: 200),
              child: isLayerInteractionActive
                  ? const SizedBox() // TODO(@hm21): implement external layer remove area
                  : const VideoEditorMainBottomBar(),
            );
          },
        ),
      ),
    );
  }
}

// ABOUTME: Main screen for the video editor with layer editing capabilities.
// ABOUTME: Orchestrates BLoC providers, sticker precaching, and editor canvas.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_top_bar.dart';
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
        BlocProvider(create: (_) => VideoEditorFilterBloc()),
      ],
      child: VideoEditorScope(
        editorKey: _editorKey,
        onAddStickers: _addStickers,
        child: const VideoEditorScaffold(
          overlayControls: _OverlayControls(),
          bottomBar: _BottomActions(),
          editor: VideoEditorCanvas(),
        ),
      ),
    );
  }
}

class _OverlayControls extends StatelessWidget {
  const _OverlayControls();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
        buildWhen: (previous, current) =>
            previous.isLayerInteractionActive !=
                current.isLayerInteractionActive ||
            previous.openSubEditor != current.openSubEditor,
        builder: (context, state) {
          final child = switch (state) {
            _ when state.isLayerInteractionActive => const SizedBox(),
            // Main-Editor
            VideoEditorMainState(openSubEditor: null) =>
              const VideoEditorMainTopBar(),
            // Filter-Editor
            VideoEditorMainState(openSubEditor: .filter) =>
              const VideoEditorFilterOverlayControls(
                key: ValueKey('Filter-Overlay-Controls'),
              ),
            // Fallback
            _ => const SizedBox(),
          };

          return AnimatedSwitcher(
            layoutBuilder: (currentChild, previousChildren) => Stack(
              fit: .expand,
              alignment: .center,
              children: <Widget>[...previousChildren, ?currentChild],
            ),
            duration: const Duration(milliseconds: 200),
            child: child,
          );
        },
      ),
    );
  }
}

/// Bottom section that switches between different toolbars based on context.
///
/// Shows [VideoEditorFilterBottomBar] when filter editor is open, hides the
/// bar during layer interaction, and falls back to [VideoEditorMainBottomBar].
class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
          buildWhen: (previous, current) =>
              previous.isLayerInteractionActive !=
                  current.isLayerInteractionActive ||
              previous.openSubEditor != current.openSubEditor,
          builder: (context, state) {
            final child = switch (state) {
              // TODO(@hm21) Implement Remove-Area
              _ when state.isLayerInteractionActive => const SizedBox(),
              // Filter-Bar
              VideoEditorMainState(openSubEditor: .filter) =>
                const VideoEditorFilterBottomBar(
                  key: ValueKey('Filter-Editor-Bottom-Bar'),
                ),
              // Main-Bar
              _ => const VideoEditorMainBottomBar(),
            };

            return AnimatedSwitcher(
              switchInCurve: Curves.easeInOut,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                clipBehavior: .none,
                alignment: .bottomCenter,
                children: <Widget>[...previousChildren, ?currentChild],
              ),
              duration: const Duration(milliseconds: 200),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

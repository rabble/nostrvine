import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// A bottom sheet that displays the video editor's layers in a
/// reorderable list.
///
/// Each layer type (text, emoji, paint, widget) is rendered with a
/// type-specific preview. Users can drag layers via a handle to reorder them.
class VideoEditorLayerReorderSheet extends StatefulWidget {
  const VideoEditorLayerReorderSheet({
    super.key,
    required this.layers,
    required this.onReorder,
  });

  /// The current list of editor layers to display.
  final List<Layer> layers;

  /// Called when the user reorders a layer.
  final ReorderCallback onReorder;

  @override
  State<VideoEditorLayerReorderSheet> createState() =>
      _VideoEditorLayerReorderSheetState();
}

class _VideoEditorLayerReorderSheetState
    extends State<VideoEditorLayerReorderSheet> {
  late final List<Layer> _layers = List.from(widget.layers);

  /// Reorders the local layer list and forwards the callback to the parent.
  void _onReorder(int oldIndex, int newIndex) {
    Log.debug(
      '🔀 Layer reordered: $oldIndex → $newIndex',
      name: 'LayerReorderSheet',
      category: LogCategory.video,
    );
    setState(() {
      if (oldIndex < newIndex) newIndex--;
      final layer = _layers.removeAt(oldIndex);
      _layers.insert(newIndex, layer);
    });
    widget.onReorder(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableList(
      reverse: true,
      primary: false,
      shrinkWrap: true,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final elevation = lerpDouble(0, 6, animation.value) ?? 0;
          return Material(
            elevation: elevation,
            color: VineTheme.containerLow,
            borderRadius: .circular(12),
            child: child,
          );
        },
        child: child,
      ),
      itemBuilder: (context, index) {
        return _LayerTile(
          key: ValueKey(_layers[index]),
          layer: _layers[index],
          index: index,
        );
      },
      itemCount: _layers.length,
      onReorder: _onReorder,
    );
  }
}

/// A single row in the reorder list with a drag handle and layer preview.
class _LayerTile extends StatelessWidget {
  const _LayerTile({super.key, required this.layer, required this.index});

  final Layer layer;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      tileColor: VineTheme.surfaceContainer,
      leading: ReorderableDragStartListener(
        index: index,
        child: SvgPicture.asset(
          'assets/icon/menu.svg',
          width: 24,
          height: 24,
          colorFilter: const .mode(VineTheme.primary, .srcIn),
        ),
      ),
      title: switch (layer) {
        final TextLayer layer => _TextLayerPreview(layer: layer),
        final EmojiLayer layer => _EmojiLayerPreview(layer: layer),
        final PaintLayer layer => _PaintLayerPreview(layer: layer),
        final WidgetLayer layer => _WidgetLayerPreview(layer: layer),
        _ => Text(layer.id),
      },
    );
  }
}

/// Displays a [TextLayer]'s content using its original style.
class _TextLayerPreview extends StatelessWidget {
  const _TextLayerPreview({required this.layer});

  final TextLayer layer;

  @override
  Widget build(BuildContext context) {
    return Text(
      layer.text,
      style:
          layer.textStyle?.copyWith(fontSize: 18) ??
          VineTheme.bodyFont(fontSize: 18),
    );
  }
}

/// Displays an [EmojiLayer]'s emoji character.
class _EmojiLayerPreview extends StatelessWidget {
  const _EmojiLayerPreview({required this.layer});

  final EmojiLayer layer;

  @override
  Widget build(BuildContext context) {
    return Text(layer.emoji, style: const TextStyle(fontSize: 24));
  }
}

/// Displays a [WidgetLayer]'s content scaled to fit the row.
class _WidgetLayerPreview extends StatelessWidget {
  const _WidgetLayerPreview({required this.layer});

  final WidgetLayer layer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FittedBox(alignment: .centerLeft, child: layer.widget),
    );
  }
}

/// Displays a [PaintLayer] preview, showing a blur icon for censor layers
/// or the actual paint strokes via [CustomPaint].
class _PaintLayerPreview extends StatelessWidget {
  const _PaintLayerPreview({required this.layer});

  final PaintLayer layer;

  @override
  Widget build(BuildContext context) {
    final isCensorLayer = layer.item.isCensorArea;

    return SizedBox(
      height: 36,
      child: FittedBox(
        alignment: .centerLeft,
        child: isCensorLayer
            ? const Icon(Icons.blur_circular)
            : CustomPaint(
                size: layer.size,
                painter: DrawPaintItem(item: layer.item, scale: layer.scale),
              ),
      ),
    );
  }
}

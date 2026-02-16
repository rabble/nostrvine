// ABOUTME: InheritedWidget providing access to the ProImageEditor instance.
// ABOUTME: Allows child widgets to call editor methods directly without callbacks.

import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Provides access to the [ProImageEditorState] for descendant widgets.
///
/// This allows toolbar widgets to directly call editor methods (undo, redo,
/// openTextEditor, etc.) without needing callbacks through a BLoC.
///
/// Usage:
/// ```dart
/// VideoEditorScope.of(context).undo();
/// ```
class VideoEditorScope extends InheritedWidget {
  /// Creates a [VideoEditorScope].
  const VideoEditorScope({
    required this.editorKey,
    required this.removeAreaKey,
    required this.onAddStickers,
    required this.onAddEditTextLayer,
    required this.originalClipAspectRatio,
    required this.bodySizeNotifier,
    super.child = const SizedBox.shrink(),
    super.key,
  });

  /// Global key to access the [ProImageEditorState].
  final GlobalKey<ProImageEditorState> editorKey;

  /// Global key to access the remove area widget.
  final GlobalKey removeAreaKey;

  /// Callback to open the sticker picker.
  final VoidCallback onAddStickers;

  /// Original aspect ratio of the clip being edited.
  final double originalClipAspectRatio;

  /// Notifier for the body size, updated by [_CanvasFitter].
  final ValueNotifier<Size> bodySizeNotifier;

  /// Callback to open the text editor.
  final Future<TextLayer?> Function([TextLayer? layer]) onAddEditTextLayer;

  /// FittedBox scale factor between bodySize and renderSize.
  double get fittedBoxScale =>
      calculateFittedBoxScale(bodySizeNotifier.value, originalClipAspectRatio);

  /// Calculates the FittedBox scale factor for a given body size and aspect ratio.
  static double calculateFittedBoxScale(Size bodySize, double aspectRatio) {
    if (bodySize == Size.zero) return 1.0;
    final height = bodySize.shortestSide;
    final renderSize = Size(height * aspectRatio, height);
    return max(
      bodySize.width / renderSize.width,
      bodySize.height / renderSize.height,
    );
  }

  /// Returns the [ProImageEditorState] if available.
  ProImageEditorState? get editor => editorKey.currentState;

  /// Returns the [FilterEditorState] if available.
  FilterEditorState? get filterEditor => editor?.filterEditor.currentState;

  /// Returns the [PaintEditorState] if available.
  PaintEditorState? get paintEditor => editor?.paintEditor.currentState;

  /// Gets the nearest [VideoEditorScope] from the widget tree.
  ///
  /// Throws if no [VideoEditorScope] is found.
  static VideoEditorScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<VideoEditorScope>();
    assert(scope != null, 'No VideoEditorScope found in context');
    return scope!;
  }

  /// Checks if the given position is over the remove area.
  bool isOverRemoveArea(Offset globalPosition) {
    final renderBox =
        removeAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    return rect.contains(globalPosition);
  }

  @override
  bool updateShouldNotify(VideoEditorScope oldWidget) =>
      editorKey != oldWidget.editorKey ||
      removeAreaKey != oldWidget.removeAreaKey;
}

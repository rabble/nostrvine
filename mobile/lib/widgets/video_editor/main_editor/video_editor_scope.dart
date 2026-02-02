// ABOUTME: InheritedWidget providing access to the ProImageEditor instance.
// ABOUTME: Allows child widgets to call editor methods directly without callbacks.

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
    required this.onAddStickers,
    required super.child,
    super.key,
  });

  /// Global key to access the [ProImageEditorState].
  final GlobalKey<ProImageEditorState> editorKey;

  /// Callback to open the sticker picker.
  final VoidCallback onAddStickers;

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

  @override
  bool updateShouldNotify(VideoEditorScope oldWidget) =>
      editorKey != oldWidget.editorKey;
}

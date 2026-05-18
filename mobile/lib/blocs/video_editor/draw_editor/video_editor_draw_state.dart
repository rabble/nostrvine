part of 'video_editor_draw_bloc.dart';

/// Available drawing tool types.
enum DrawToolType {
  /// Pencil with thin line.
  pencil,

  /// Marker with medium line and a bit transparent.
  marker,

  /// Pencil line with a arrow on the end.
  arrow,

  /// Eraser tool.
  eraser;

  /// Returns the paint configuration (mode, opacity, stroke width) for this tool.
  DrawToolConfig get config => switch (this) {
    .pencil => (mode: .freeStyle, opacity: 1.0, strokeWidth: 6.0),
    .marker => (mode: .freeStyle, opacity: 0.7, strokeWidth: 12.0),
    .arrow => (mode: .freeStyleArrowEnd, opacity: 1.0, strokeWidth: 8.0),
    .eraser => (mode: .eraser, opacity: 1.0, strokeWidth: 12.0),
  };
}

/// Paint configuration for a drawing tool.
typedef DrawToolConfig = ({PaintMode mode, double opacity, double strokeWidth});

/// State for the video editor draw/paint screen.
class VideoEditorDrawState extends Equatable {
  const VideoEditorDrawState({
    this.canUndo = false,
    this.canRedo = false,
    this.strokeWidth = 8.0,
    this.opacity = 1.0,
    this.selectedColor = VideoEditorConstants.primaryColor,
    this.selectedTool = .pencil,
    this.mode = .freeStyle,
  });

  /// Whether the undo action is available.
  final bool canUndo;

  /// Whether the redo action is available.
  final bool canRedo;

  /// The currently selected drawing tool.
  final DrawToolType selectedTool;

  /// The stroke width for drawing.
  final double strokeWidth;

  /// The opacity for drawing.
  final double opacity;

  /// The currently selected drawing color.
  final Color selectedColor;

  /// The current paint mode.
  final PaintMode mode;

  /// Creates a copy with the given fields replaced.
  VideoEditorDrawState copyWith({
    bool? canUndo,
    bool? canRedo,
    DrawToolType? selectedTool,
    double? strokeWidth,
    double? opacity,
    Color? selectedColor,
    PaintMode? mode,
  }) {
    return VideoEditorDrawState(
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      selectedTool: selectedTool ?? this.selectedTool,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      selectedColor: selectedColor ?? this.selectedColor,
      mode: mode ?? this.mode,
    );
  }

  @override
  List<Object?> get props => [
    canUndo,
    canRedo,
    selectedTool,
    strokeWidth,
    opacity,
    selectedColor,
    mode,
  ];
}

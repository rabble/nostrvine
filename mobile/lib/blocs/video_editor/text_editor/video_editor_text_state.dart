part of 'video_editor_text_bloc.dart';

/// State for the video editor text overlay screen.
class VideoEditorTextState extends Equatable {
  const VideoEditorTextState({
    this.text = '',
    this.selectedFontIndex = 3, // IBM Plex Mono
    this.alignment = TextAlign.center,
    this.textColor = Colors.white,
    this.backgroundStyle = LayerBackgroundMode.backgroundAndColor,
    this.fontSize = 0.5,
    this.showFontSelector = false,
    this.showColorPicker = false,
  });

  /// The current text content.
  final String text;

  /// The index of the selected font in [textFonts].
  final int selectedFontIndex;

  /// Returns the selected font getter.
  TextFont get selectedFont =>
      VideoEditorConstants.textFonts[selectedFontIndex];

  /// Returns the display name of the selected font.
  String get selectedFontName {
    final fontFamily = selectedFont().fontFamily;
    if (fontFamily == null) return 'Unknown';
    // Remove common suffixes and convert underscores to spaces
    return fontFamily
        .replaceAll(RegExp(r'_regular$', caseSensitive: false), '')
        .replaceAll('_', ' ');
  }

  /// The text alignment.
  final TextAlign alignment;

  /// The text color.
  final Color textColor;

  /// The background style.
  final LayerBackgroundMode backgroundStyle;

  /// The font size as a normalized value (0.0 - 1.0).
  /// Maps to actual font sizes in the text layer.
  final double fontSize;

  /// Whether the font selector is currently shown (replaces keyboard).
  final bool showFontSelector;

  /// Whether the color picker is currently shown (replaces keyboard).
  final bool showColorPicker;

  /// Creates a copy with the given fields replaced.
  VideoEditorTextState copyWith({
    String? text,
    int? selectedFontIndex,
    TextAlign? alignment,
    Color? textColor,
    LayerBackgroundMode? backgroundStyle,
    double? fontSize,
    bool? showFontSelector,
    bool? showColorPicker,
  }) {
    return VideoEditorTextState(
      text: text ?? this.text,
      selectedFontIndex: selectedFontIndex ?? this.selectedFontIndex,
      alignment: alignment ?? this.alignment,
      textColor: textColor ?? this.textColor,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      fontSize: fontSize ?? this.fontSize,
      showFontSelector: showFontSelector ?? this.showFontSelector,
      showColorPicker: showColorPicker ?? this.showColorPicker,
    );
  }

  @override
  List<Object?> get props => [
    text,
    selectedFontIndex,
    alignment,
    textColor,
    backgroundStyle,
    fontSize,
    showFontSelector,
    showColorPicker,
  ];
}

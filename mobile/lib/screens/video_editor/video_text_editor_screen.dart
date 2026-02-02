import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_inline_font_selector.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class VideoTextEditorScreen extends StatefulWidget {
  const VideoTextEditorScreen({super.key, this.layer});

  final TextLayer? layer;

  @override
  State<VideoTextEditorScreen> createState() => _VideoTextEditorScreenState();
}

class _VideoTextEditorScreenState extends State<VideoTextEditorScreen> {
  final _textEditorKey = GlobalKey<TextEditorState>();
  late final VideoEditorTextBloc _textBloc;

  /// Base font size in pixels.
  static const double _baseFontSize = 24;

  /// Minimum font scale multiplier.
  static const double _minFontScale = 0.5;

  /// Maximum font scale multiplier.
  static const double _maxFontScale = 4.0;

  /// Background color for the text editor.
  static const Color _backgroundColor = Color(0x9B000000);

  @override
  void initState() {
    super.initState();
    _textBloc = VideoEditorTextBloc();
  }

  @override
  void dispose() {
    _textBloc.close();
    super.dispose();
  }

  /// Maps [TextAlign] to [Alignment] for the input text field position.
  Alignment _getInputAlignment(TextAlign textAlign) {
    return switch (textAlign) {
      .left || .start => .centerLeft,
      .right || .end => .centerRight,
      _ => .center,
    };
  }

  /// Converts normalized font size (0.0-1.0) to font scale (0.3-3.0).
  double _getFontScale(double normalizedValue) {
    return _minFontScale + (normalizedValue * (_maxFontScale - _minFontScale));
  }

  @override
  Widget build(BuildContext context) {
    final (alignment, fontSize, backgroundStyle) = context.select(
      (VideoEditorTextBloc bloc) => (
        bloc.state.alignment,
        bloc.state.fontSize,
        bloc.state.backgroundStyle,
      ),
    );

    return BlocBuilder<VideoEditorTextBloc, VideoEditorTextState>(
      buildWhen: (previous, current) =>
          previous.showFontSelector != current.showFontSelector ||
          previous.showColorPicker != current.showColorPicker ||
          previous.textColor != current.textColor,
      builder: (context, state) {
        final showBottomPanel = state.showFontSelector || state.showColorPicker;
        const panelHeight = 300.0;

        return Stack(
          children: [
            // TextEditor with padding when panel is shown
            Padding(
              padding: EdgeInsets.only(
                bottom: showBottomPanel ? panelHeight : 0,
              ),
              child: TextEditor(
                key: _textEditorKey,
                layer: widget.layer,
                theme: Theme.of(context),
                heroTag: widget.layer?.id,
                callbacks: ProImageEditorCallbacks(
                  textEditorCallbacks: TextEditorCallbacks(
                    onBackgroundModeChanged: (value) {
                      context.read<VideoEditorTextBloc>().add(
                        VideoEditorTextBackgroundStyleChanged(value),
                      );
                    },
                    onTextAlignChanged: (value) {
                      context.read<VideoEditorTextBloc>().add(
                        VideoEditorTextAlignmentChanged(value),
                      );
                    },
                  ),
                ),
                configs: ProImageEditorConfigs(
                  i18n: I18n(textEditor: I18nTextEditor(inputHintText: '')),
                  textEditor: TextEditorConfigs(
                    style: const TextEditorStyle(
                      inputCursorColor: VineTheme.whiteText,
                      inputTextFieldPadding: .only(left: 16, right: 48),
                      background: _backgroundColor,
                    ),
                    minFontScale: _minFontScale,
                    maxFontScale: _maxFontScale,
                    initFontSize: _baseFontSize,
                    initFontScale: _getFontScale(fontSize),
                    initialBackgroundColorMode: backgroundStyle,
                    initialTextAlign: alignment,
                    inputTextFieldAlign: _getInputAlignment(alignment),
                    enableAutoOverflow: false,
                    widgets: TextEditorWidgets(
                      appBar: (_, _) => null,
                      bottomBar: (_, _) => null,
                      colorPicker: (_, _, _, _) => null,
                      bodyItemsOverlay: (editor, rebuildStream) => [
                        ReactiveWidget(
                          stream: rebuildStream,
                          builder: (_) => VideoTextEditorScope(
                            editor: editor,
                            child: const VideoEditorTextOverlayControls(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom panels (font selector / color picker)
            if (showBottomPanel)
              Align(
                alignment: .bottomCenter,
                child: Material(
                  color: _backgroundColor,
                  child: state.showFontSelector
                      ? VideoEditorTextInlineFontSelector(
                          height: panelHeight,
                          onFontSelected: (textStyle) {
                            _textEditorKey.currentState?.setTextStyle(
                              textStyle,
                            );
                          },
                        )
                      : VideoEditorColorPickerSheet(
                          height: panelHeight,
                          selectedColor: state.textColor,
                          onColorSelected: (color) {
                            _textEditorKey.currentState?.primaryColor = color;
                            context.read<VideoEditorTextBloc>().add(
                              VideoEditorTextColorSelected(color),
                            );
                          },
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

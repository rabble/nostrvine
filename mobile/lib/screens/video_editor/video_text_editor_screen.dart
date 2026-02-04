import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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

        return Column(
          children: [
            // TextEditor with padding when panel is shown
            Expanded(
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
                    resizeToAvoidBottomInset: false,
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
            _KeyboardHeightPanel(
              showBottomPanel: showBottomPanel,
              backgroundColor: _backgroundColor,
              onKeyboardClosedWithoutPanel: () {
                if (mounted) context.pop();
              },
              builder: (height) => state.showFontSelector
                  ? VideoEditorTextInlineFontSelector(
                      onFontSelected: (textStyle) {
                        _textEditorKey.currentState?.setTextStyle(textStyle);
                      },
                    )
                  : VideoEditorColorPickerSheet(
                      height: height,
                      selectedColor: state.textColor,
                      onColorSelected: (color) {
                        _textEditorKey.currentState?.primaryColor = color;
                        context.read<VideoEditorTextBloc>().add(
                          VideoEditorTextColorSelected(color),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _KeyboardHeightPanel extends StatefulWidget {
  const _KeyboardHeightPanel({
    required this.showBottomPanel,
    required this.backgroundColor,
    required this.builder,
    this.onKeyboardClosedWithoutPanel,
  });

  final bool showBottomPanel;
  final Color backgroundColor;
  final Widget Function(double height) builder;
  final VoidCallback? onKeyboardClosedWithoutPanel;

  @override
  State<_KeyboardHeightPanel> createState() => _KeyboardHeightPanelState();
}

class _KeyboardHeightPanelState extends State<_KeyboardHeightPanel> {
  /// Minimum fallback height for the panel.
  static const double _minPanelHeight = 200.0;

  /// Threshold to consider keyboard as "open".
  static const double _keyboardThreshold = 100.0;

  /// Stores the last known keyboard height for smooth transitions.
  double _lastKeyboardHeight = 0.0;

  /// Previous keyboard height to detect closing.
  double _previousKeyboardHeight = 0.0;

  /// Tracks if we already triggered the pop callback.
  bool _hasPopped = false;

  /// Schedules a pop callback with delay if not already popped.
  void _schedulePopIfNeeded() {
    if (_hasPopped) return;
    _hasPopped = true;

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        widget.onKeyboardClosedWithoutPanel?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    // Detect keyboard closing (was open, now closed) without a open panel.
    // That handle the case when android users press the hardware back-button.
    if (_previousKeyboardHeight > _keyboardThreshold &&
        keyboardHeight < _keyboardThreshold &&
        !widget.showBottomPanel) {
      _schedulePopIfNeeded();
    }

    _previousKeyboardHeight = keyboardHeight;

    // Update last known keyboard height when keyboard is visible
    if (keyboardHeight > _lastKeyboardHeight) {
      _lastKeyboardHeight = keyboardHeight;
    }

    // Ensure minimum height when panel should be shown
    if (widget.showBottomPanel && _lastKeyboardHeight < _minPanelHeight) {
      _lastKeyboardHeight = _minPanelHeight;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: _lastKeyboardHeight,
      color: widget.backgroundColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
        child: widget.showBottomPanel
            ? Material(
                type: .transparency,
                child: widget.builder(_lastKeyboardHeight),
              )
            : const SizedBox(width: .infinity),
      ),
    );
  }
}

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_font_selector.dart';
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

  @override
  void initState() {
    super.initState();
    _initFromLayer();
  }

  /// Initialize the bloc from layer if editing an existing text layer.
  void _initFromLayer() {
    final layer = widget.layer;
    final bloc = context.read<VideoEditorTextBloc>();

    if (layer == null) {
      return;
    }

    // Get the primary color based on the layer's color mode.
    final primaryColor = layer.colorMode == .background
        ? layer.background
        : layer.color;

    final fontIndex = VideoEditorConstants.textFonts.indexWhere(
      (el) => el() == layer.textStyle,
    );

    bloc.add(
      VideoEditorTextInitFromLayer(
        text: layer.text,
        alignment: layer.align,
        color: primaryColor,
        backgroundStyle: layer.colorMode,
        fontSize: _normalizeFontScale(layer.fontScale),
        selectedFontIndex: max(0, fontIndex),
      ),
    );
  }

  /// Converts font scale (0.5-4.0) to normalized value (0.0-1.0).
  double _normalizeFontScale(double fontScale) {
    return ((fontScale - VideoEditorConstants.minFontScale) /
            (VideoEditorConstants.maxFontScale -
                VideoEditorConstants.minFontScale))
        .clamp(0.0, 1.0);
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
    return VideoEditorConstants.minFontScale +
        (normalizedValue *
            (VideoEditorConstants.maxFontScale -
                VideoEditorConstants.minFontScale));
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
          previous.color != current.color,
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
                    style: TextEditorStyle(
                      inputCursorColor: VineTheme.whiteText,
                      inputTextFieldPadding: .only(left: 16, right: 48),
                      background: VideoEditorConstants.textEditorBackground,
                    ),
                    resizeToAvoidBottomInset: false,
                    minFontScale: VideoEditorConstants.minFontScale,
                    maxFontScale: VideoEditorConstants.maxFontScale,
                    initFontSize: VideoEditorConstants.baseFontSize,
                    initFontScale: _getFontScale(fontSize),
                    initialBackgroundColorMode: backgroundStyle,
                    initialTextAlign: alignment,
                    initialPrimaryColor: state.color,
                    defaultTextStyle: VideoEditorConstants
                        .textFonts[state.selectedFontIndex](),
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
              backgroundColor: VideoEditorConstants.textEditorBackground,
              onKeyboardClosedWithoutPanel: () {
                if (mounted) context.pop();
              },
              builder: (height) => state.showFontSelector
                  ? VideoEditorTextInlineFontSelector.VideoEditorTextFontSelector(
                      onFontSelected: (textStyle) {
                        _textEditorKey.currentState?.setTextStyle(textStyle);
                      },
                    )
                  : VideoEditorColorPickerSheet(
                      height: height,
                      selectedColor: state.color,
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

    /// The 150ms delay prevents double-pop issues: when close is triggered
    /// elsewhere (e.g., a button), the keyboard also closes and could trigger
    /// this callback. The delay combined with the `mounted` check ensures we
    /// don't pop twice. Using `WidgetsBinding.instance.addPostFrameCallback`
    /// was not reliable enough for this timing issue.
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

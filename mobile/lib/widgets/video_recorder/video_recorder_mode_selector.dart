import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';

/// Horizontal picker-wheel mode selector.
///
/// Items scroll horizontally. A fixed pill is always centered — its width
/// animates to fit the selected label. The centered item shows
/// [VineTheme.primary] text; all others show [VineTheme.whiteText].
class VideoRecorderModeSelectorWheel extends StatefulWidget {
  const VideoRecorderModeSelectorWheel({
    required this.selectedMode,
    required this.onModeChanged,
    super.key,
  });

  final VideoRecorderMode selectedMode;
  final ValueChanged<VideoRecorderMode> onModeChanged;

  @override
  State<VideoRecorderModeSelectorWheel> createState() =>
      _VideoRecorderModeSelectorWheelState();
}

class _VideoRecorderModeSelectorWheelState
    extends State<VideoRecorderModeSelectorWheel> {
  late final ScrollController _scrollController;
  late int _selectedIndex;
  bool _isSnapping = false;
  double _lastScrollDelta = 0.0;

  static const double _itemExtent = 96.0;
  static const double _pillHeight = 34.0;
  static const double _pillHPadding = 16.0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = VideoRecorderMode.values.indexOf(widget.selectedMode);
    _scrollController = ScrollController(
      initialScrollOffset: _selectedIndex * _itemExtent,
    );
  }

  @override
  void didUpdateWidget(VideoRecorderModeSelectorWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMode != widget.selectedMode) {
      final index = VideoRecorderMode.values.indexOf(widget.selectedMode);
      setState(() => _selectedIndex = index);
      _animateTo(index);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _animateTo(int index) async {
    if (!_scrollController.hasClients) return;
    _isSnapping = true;

    await _scrollController.animateTo(
      index * _itemExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
    _isSnapping = false;
  }

  void _snapToNearest() {
    if (_isSnapping || !_scrollController.hasClients) return;
    final fractional = _scrollController.offset / _itemExtent;
    int targetIndex;
    if (_lastScrollDelta > 0.5) {
      targetIndex = fractional.ceil();
    } else if (_lastScrollDelta < -0.5) {
      targetIndex = fractional.floor();
    } else {
      targetIndex = fractional.round();
    }
    targetIndex = targetIndex.clamp(0, VideoRecorderMode.values.length - 1);
    _lastScrollDelta = 0;
    // Defer to the next frame — animateTo called directly inside a scroll
    // notification callback is silently ignored by Flutter's scroll system.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _selectIndex(targetIndex, animate: true);
    });
  }

  void _selectIndex(int index, {bool animate = false}) {
    if (animate) _animateTo(index);
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    HapticFeedback.selectionClick();
    widget.onModeChanged(VideoRecorderMode.values[index]);
  }

  /// Measures the width the pill needs for the given label text.
  double _pillWidth(String label, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: VineTheme.titleSmallFont()),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    return painter.width + _pillHPadding * 2;
  }

  @override
  Widget build(BuildContext context) {
    const modes = VideoRecorderMode.values;
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.3);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = (constraints.maxWidth - _itemExtent) / 2;
        return SizedBox(
          height: _pillHeight,
          child: Stack(
            alignment: .center,
            children: [
              // Fixed pill — always centered, width follows selected label.
              IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  height: _pillHeight,
                  width: _pillWidth(modes[_selectedIndex].label, textScaler),
                  decoration: BoxDecoration(
                    color: VineTheme.surfaceContainer,
                    borderRadius: .circular(_pillHeight / 2),
                  ),
                ),
              ),
              // Scrollable labels with left/right fade-out edges.
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.18, 0.82, 1.0],
                ).createShader(bounds),
                blendMode: .dstIn,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      _lastScrollDelta = notification.scrollDelta ?? 0;
                    } else if (notification is ScrollEndNotification) {
                      _snapToNearest();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    controller: _scrollController,
                    padding: .symmetric(horizontal: sidePadding),
                    itemCount: modes.length,
                    itemExtent: _itemExtent,
                    itemBuilder: (context, i) {
                      final isSelected = i == _selectedIndex;
                      return Semantics(
                        label: modes[i].label,
                        selected: isSelected,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _selectIndex(i, animate: true);
                            if (!_isSnapping) _animateTo(i);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: VineTheme.titleSmallFont(
                                color: isSelected
                                    ? VineTheme.primary
                                    : VineTheme.whiteText,
                              ),
                              child: Text(
                                modes[i].label,
                                textScaler: textScaler,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

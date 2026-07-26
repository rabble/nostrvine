import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/constants/semantic_ids.dart';
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
  bool _userScrolling = false;
  double _lastScrollDelta = 0.0;

  /// Scroll offset that centers each item, indexed by mode. Recomputed on
  /// every build from the measured label widths.
  List<double> _snapOffsets = const [];

  static const double _pillHeight = 34.0;
  static const double _pillHPadding = 16.0;

  /// Constant gap kept between adjacent labels. Half sits on each side of a
  /// label, so consecutive labels stay [_labelGap] apart no matter how much
  /// their text widths differ.
  static const double _labelGap = 44.0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = VideoRecorderMode.values.indexOf(widget.selectedMode);
    _snapOffsets = _snapOffsetsFor(_itemWidths(TextScaler.noScaling));
    _scrollController = ScrollController(
      initialScrollOffset: _snapOffsets[_selectedIndex],
    );
    // The initial offset is measured at noScaling; the first build recomputes
    // _snapOffsets from the actual (clamped) text scaler. Under a larger system
    // font those widths differ, leaving the pre-selected mode off-centre until
    // the user scrolls — recenter once the scaled offsets are known.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _snapOffsets[_selectedIndex];
      if ((_scrollController.offset - target).abs() > 0.5) {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  void didUpdateWidget(VideoRecorderModeSelectorWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMode != widget.selectedMode) {
      final index = VideoRecorderMode.values.indexOf(widget.selectedMode);
      // Self-originated changes (tap/snap) already animated to this index.
      if (index == _selectedIndex) return;
      setState(() => _selectedIndex = index);
      // External changes (persisted-mode restore right after open,
      // editor-driven switches) reposition instantly — a visible scroll
      // animation on a screen the user just opened feels broken.
      _jumpTo(index);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpTo(int index) {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_snapOffsets[index]);
  }

  Future<void> _animateTo(int index) async {
    if (!_scrollController.hasClients) return;
    _isSnapping = true;

    await _scrollController.animateTo(
      _snapOffsets[index],
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
    _isSnapping = false;
  }

  void _snapToNearest() {
    if (_isSnapping || !_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    var floorIndex = 0;
    var ceilIndex = _snapOffsets.length - 1;
    for (var i = 0; i < _snapOffsets.length; i++) {
      if (_snapOffsets[i] <= offset) floorIndex = i;
    }
    for (var i = _snapOffsets.length - 1; i >= 0; i--) {
      if (_snapOffsets[i] >= offset) ceilIndex = i;
    }
    int targetIndex;
    if (_lastScrollDelta > 0.5) {
      targetIndex = ceilIndex;
    } else if (_lastScrollDelta < -0.5) {
      targetIndex = floorIndex;
    } else {
      final floorDist = (offset - _snapOffsets[floorIndex]).abs();
      final ceilDist = (offset - _snapOffsets[ceilIndex]).abs();
      targetIndex = floorDist <= ceilDist ? floorIndex : ceilIndex;
    }
    // One gesture advances at most one slot. An over-fling matches no snap
    // offset, so floorIndex/ceilIndex keep their initial values — 0 and the
    // last index — and the wheel selects a mode the user never scrolled onto.
    // Both end slots are hazards: `upload` renders a blank metadata screen and
    // `classic` pins capture to square, and the choice is persisted (#6200).
    // Tap-to-select does not come through here, so it can still jump anywhere.
    final lastIndex = _snapOffsets.length - 1;
    targetIndex = targetIndex.clamp(
      (_selectedIndex - 1).clamp(0, lastIndex),
      (_selectedIndex + 1).clamp(0, lastIndex),
    );
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

  /// Rendered width of [label] at [textScaler].
  double _textWidth(String label, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: VineTheme.titleSmallFont()),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Width of each item — its label plus a constant [_labelGap] — so the
  /// spacing between adjacent labels stays uniform regardless of text width.
  List<double> _itemWidths(TextScaler textScaler) => [
    for (final mode in VideoRecorderMode.values)
      _textWidth(mode.label, textScaler) + _labelGap,
  ];

  /// Scroll offset that centers each item, derived from [itemWidths]. The
  /// result is viewport-independent; the leading/trailing scroll padding in
  /// [build] takes care of centering the first and last items.
  List<double> _snapOffsetsFor(List<double> itemWidths) {
    final firstHalf = itemWidths.first / 2;
    final offsets = <double>[];
    var acc = 0.0;
    for (final width in itemWidths) {
      offsets.add(acc + width / 2 - firstHalf);
      acc += width;
    }
    return offsets;
  }

  /// Width the centered pill needs to wrap [label].
  double _pillWidth(String label, TextScaler textScaler) =>
      _textWidth(label, textScaler) + _pillHPadding * 2;

  @override
  Widget build(BuildContext context) {
    const modes = VideoRecorderMode.values;
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.3);
    final itemWidths = _itemWidths(textScaler);
    _snapOffsets = _snapOffsetsFor(itemWidths);
    return LayoutBuilder(
      builder: (context, constraints) {
        final leadingPadding = (constraints.maxWidth - itemWidths.first) / 2;
        final trailingPadding = (constraints.maxWidth - itemWidths.last) / 2;
        return SizedBox(
          height: kMinInteractiveDimension,
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
                    if (notification is ScrollStartNotification) {
                      // Only user drags/flings should snap. A programmatic
                      // animateTo scroll has null drag details; letting its
                      // end re-trigger snapping made the wheel keep advancing
                      // to the last item.
                      _userScrolling = notification.dragDetails != null;
                    } else if (notification is ScrollUpdateNotification) {
                      _lastScrollDelta = notification.scrollDelta ?? 0;
                    } else if (notification is ScrollEndNotification &&
                        _userScrolling) {
                      _userScrolling = false;
                      _snapToNearest();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      left: leadingPadding,
                      right: trailingPadding,
                    ),
                    itemCount: modes.length,
                    itemBuilder: (context, i) {
                      final isSelected = i == _selectedIndex;
                      return SizedBox(
                        width: itemWidths[i],
                        child: Semantics(
                          identifier: SemanticIds.cameraMode(modes[i].name),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  softWrap: false,
                                  textScaler: textScaler,
                                ),
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

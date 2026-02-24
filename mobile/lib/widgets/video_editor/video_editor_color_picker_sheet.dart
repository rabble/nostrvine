// ABOUTME: Bottom sheet for color selection in the video editor.
// ABOUTME: Shows a grid of colors with iOS-style blurred background.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/video_editor_blurred_panel.dart';

/// Bottom sheet for color selection with iOS-style blurred background.
class VideoEditorColorPickerSheet extends StatelessWidget {
  const VideoEditorColorPickerSheet({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    this.height,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  /// Optional height constraint for inline display (e.g., replacing keyboard).
  final double? height;

  /// Minimum size for color buttons. Items may grow larger to fill space.
  static const double _minItemSize = 40;

  /// Spacing between items.
  static const double _crossAxisSpacing = 10;

  /// Spacing between rows.
  static const double _mainAxisSpacing = 22;

  /// Horizontal padding.
  static const double _horizontalPadding = 20;

  void _openColorPicker() {
    // TODO(@hm21): implement color-picker when the design is ready.
  }

  /// Finds the best crossAxisCount that evenly divides [itemCount].
  ///
  /// Searches from [maxCount] down to [minCount] to find an even divisor.
  /// This prefers more items per row (closer to min size) while ensuring
  /// all rows have equal item counts.
  int _findBestCrossAxisCount({
    required int itemCount,
    required double width,
    int minCount = 4,
  }) {
    // Calculate max items that fit per row at minimum size
    final availableWidth = width - (_horizontalPadding * 2);
    final itemWithSpacing = _minItemSize + _crossAxisSpacing;
    final maxCount = ((availableWidth + _crossAxisSpacing) / itemWithSpacing)
        .floor()
        .clamp(1, 10);

    for (int count = maxCount; count >= minCount; count--) {
      if (itemCount % count == 0) return count;
    }
    // No even divisor found - use maxCount (last row will be partial)
    return maxCount;
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = VideoEditorConstants.colors.length + 1;

    Widget content = VideoEditorBlurredPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Find best count that evenly divides items (items grow to fill)
          final crossAxisCount = _findBestCrossAxisCount(
            itemCount: itemCount,
            width: constraints.maxWidth,
          );

          return SingleChildScrollView(
            child: GridView.builder(
              padding: const .fromLTRB(
                _horizontalPadding,
                25,
                _horizontalPadding,
                32,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: _mainAxisSpacing,
                crossAxisSpacing: _crossAxisSpacing,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final isColorPicker = index == 0;
                final color = isColorPicker
                    ? Colors.white
                    : VideoEditorConstants.colors[index - 1];
                final isSelected = color == selectedColor;

                return _ColorButton(
                  color: color,
                  isSelected: isSelected,
                  isColorPicker: isColorPicker,
                  onTap: () => isColorPicker
                      ? _openColorPicker()
                      : onColorSelected(color),
                );
              },
              itemCount: itemCount,
            ),
          );
        },
      ),
    );

    // Wrap with SizedBox if height is specified (inline mode)
    if (height != null) {
      content = SizedBox(height: height, child: content);
    }

    return content;
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.isColorPicker,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final bool isColorPicker;
  final VoidCallback onTap;

  String _getColorName(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return 'RGB $r, $g, $b';
  }

  @override
  Widget build(BuildContext context) {
    final String label;
    if (isColorPicker) {
      label = 'Color picker';
    } else {
      final colorName = _getColorName(color);
      label = isSelected ? '$colorName, selected' : colorName;
    }

    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: .circular(16),
            border: isSelected
                ? .all(
                    strokeAlign: BorderSide.strokeAlignOutside,
                    color: Colors.white,
                    width: 4,
                  )
                : null,
          ),
          child: Padding(
            padding: isSelected ? const EdgeInsets.all(2) : EdgeInsets.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(isSelected ? 14 : 16),
                border: isSelected
                    ? null
                    : Border.all(color: VineTheme.onSurface, width: 2),
              ),
              child: isColorPicker
                  ? Center(
                      child: DivineIcon(
                        icon: .paintBrush,
                        color: VineTheme.inverseOnSurface,
                        size: 28,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

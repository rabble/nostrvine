// ABOUTME: Bottom sheet for color selection in the video editor.
// ABOUTME: Shows a grid of colors with iOS-style blurred background.
// ABOUTME: Persists recently picked custom colors in SharedPreferences.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/divine_secondary_button.dart';
import 'package:openvine/widgets/video_editor/video_editor_blurred_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bottom sheet for color selection with iOS-style blurred background.
class VideoEditorColorPickerSheet extends ConsumerStatefulWidget {
  const VideoEditorColorPickerSheet({
    required this.selectedColor,
    required this.onColorSelected,
    super.key,
    this.height,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  /// Optional height constraint for inline display (e.g., replacing keyboard).
  final double? height;

  @override
  ConsumerState<VideoEditorColorPickerSheet> createState() =>
      _VideoEditorColorPickerSheetState();
}

class _VideoEditorColorPickerSheetState
    extends ConsumerState<VideoEditorColorPickerSheet> {
  /// Minimum size for color buttons. Items may grow larger to fill space.
  static const double _minItemSize = 40;

  /// Spacing between items.
  static const double _crossAxisSpacing = 10;

  /// Spacing between rows.
  static const double _mainAxisSpacing = 22;

  /// Horizontal padding.
  static const double _horizontalPadding = 20;

  /// SharedPreferences key for storing recent custom colors.
  static const _recentColorsKey = 'video_editor_recent_colors';

  late List<Color> _recentColors;

  @override
  void initState() {
    super.initState();
    _recentColors = _loadRecentColors(ref.read(sharedPreferencesProvider));
  }

  List<Color> _loadRecentColors(SharedPreferences prefs) {
    final stored = prefs.getStringList(_recentColorsKey);
    if (stored == null) return [];
    return stored.map((hex) => Color(int.tryParse(hex) ?? 0)).toList();
  }

  void _saveRecentColor(Color color, {required int maxCount}) {
    final prefs = ref.read(sharedPreferencesProvider);
    // Remove if already present, then add to front
    _recentColors
      ..remove(color)
      ..insert(0, color);
    // Limit to one row worth of items
    if (_recentColors.length > maxCount) {
      _recentColors = _recentColors.sublist(0, maxCount);
    }
    prefs.setStringList(
      _recentColorsKey,
      _recentColors.map((c) => c.toARGB32().toString()).toList(),
    );
    setState(() {});
  }

  void _openColorPicker(BuildContext context, {required int maxCount}) {
    VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: _FullColorPickerSheet(
        initialColor: VineTheme.primary,
        onColorSelected: (color) {
          _saveRecentColor(color, maxCount: maxCount);
          widget.onColorSelected(color);
        },
      ),
    );
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
    const itemWithSpacing = _minItemSize + _crossAxisSpacing;
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
    final presetCount = VideoEditorConstants.colors.length + 1;
    final totalCount = presetCount + _recentColors.length;

    Widget content = VideoEditorBlurredPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Find best count that evenly divides items (items grow to fill)
          final crossAxisCount = _findBestCrossAxisCount(
            itemCount: presetCount,
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
              ),
              itemBuilder: (context, index) {
                if (index < presetCount) {
                  final isColorPicker = index == 0;
                  final color = isColorPicker
                      ? VineTheme.whiteText
                      : VideoEditorConstants.colors[index - 1];
                  final isSelected = color == widget.selectedColor;

                  return _ColorButton(
                    color: color,
                    isSelected: isSelected,
                    isColorPicker: isColorPicker,
                    onTap: () => isColorPicker
                        ? _openColorPicker(
                            context,
                            maxCount: crossAxisCount,
                          )
                        : widget.onColorSelected(color),
                  );
                }

                // Recent custom colors appended after preset colors
                final color = _recentColors[index - presetCount];
                return _ColorButton(
                  color: color,
                  isSelected: color == widget.selectedColor,
                  isColorPicker: false,
                  onTap: () => widget.onColorSelected(color),
                );
              },
              itemCount: totalCount,
            ),
          );
        },
      ),
    );

    // Wrap with SizedBox if height is specified (inline mode)
    if (widget.height != null) {
      content = SizedBox(height: widget.height, child: content);
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
                    color: VineTheme.whiteText,
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
                  ? const Center(
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

class _FullColorPickerSheet extends StatefulWidget {
  const _FullColorPickerSheet({
    required this.initialColor,
    required this.onColorSelected,
  });

  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  @override
  State<_FullColorPickerSheet> createState() => _FullColorPickerSheetState();
}

class _FullColorPickerSheetState extends State<_FullColorPickerSheet> {
  late Color _pickerColor = widget.initialColor;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        spacing: 16,
        children: [
          ColorPicker(
            pickerColor: _pickerColor,
            onColorChanged: (color) => setState(() {
              _pickerColor = color;
            }),
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.7,
            pickerAreaBorderRadius: .circular(16),
          ),
          DivineSecondaryButton(
            onPressed: () {
              widget.onColorSelected(_pickerColor);
              context.pop();
            },
            label: 'Select',
          ),
        ],
      ),
    );
  }
}

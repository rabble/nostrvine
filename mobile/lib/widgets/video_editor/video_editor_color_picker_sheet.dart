// ABOUTME: Bottom sheet for color selection in the video editor.
// ABOUTME: Shows a grid of colors with iOS-style blurred background.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/constants/video_editor_constants.dart';

/// Bottom sheet for color selection with iOS-style blurred background.
class VideoEditorColorPickerSheet extends StatelessWidget {
  const VideoEditorColorPickerSheet({
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  void _openColorPicker() {
    // TODO(@hm21): implement color-picker when the design is ready.
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const .vertical(top: .circular(27)),
      child: BackdropFilter(
        filter: .blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0D),
            backgroundBlendMode: .lighten,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(38, 38, 38, .9),
              backgroundBlendMode: .luminosity,
            ),
            child: Padding(
              padding: const .fromLTRB(20, 25, 20, 32),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 44,
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 14,
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
                itemCount: VideoEditorConstants.colors.length + 1,
              ),
            ),
          ),
        ),
      ),
    );
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
        child: Container(
          width: 44,
          height: 44,
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
          padding: isSelected ? const .all(2) : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: .circular(isSelected ? 14 : 16),
              border: isSelected
                  ? null
                  : .all(color: VineTheme.onSurface, width: 2),
            ),
            child: isColorPicker
                ? Center(
                    child: SvgPicture.asset(
                      'assets/icon/paint_brush.svg',
                      colorFilter: const .mode(Color(0xFF00452D), .srcIn),
                      width: 28,
                      height: 28,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

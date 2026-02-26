// ABOUTME: Button for selecting the arrow drawing tool.
// ABOUTME: Displays a white squiggle line with arrow head icon.

import 'package:flutter/material.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_item_button.dart';

/// Button for selecting the arrow drawing tool.
///
/// Displays a white squiggle line with an arrow head icon.
class DrawToolArrow extends StatelessWidget {
  /// Creates an arrow tool button.
  const DrawToolArrow({
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  /// Whether this tool is currently selected.
  final bool isSelected;

  /// Callback invoked when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VideoEditorDrawItemButton(
      onTap: onTap,
      isSelected: isSelected,
      // TODO(l10n): Replace with context.l10n when localization is added.
      semanticLabel: 'Arrow tool',
      painter: const _ArrowPainter(),
    );
  }
}

/// Custom painter that draws a white squiggle line with arrow head.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;

    final paint = Paint()
      ..color = Colors.white
      ..style = .stroke
      ..strokeWidth = 6
      ..strokeCap = .round
      ..strokeJoin = .round;

    // Arrow head at top
    const arrowWidth = 22;
    const arrowHeight = 10.0;

    // Squiggle line with arrow
    const amplitude = 6.0;
    const waveHeight = 22.0;
    const straightStart = 22.0;

    final path = Path()
      // Arrow head - left side
      ..moveTo(centerX - arrowWidth / 2, arrowHeight)
      ..lineTo(centerX, 0)
      // Arrow head - right side
      ..lineTo(centerX + arrowWidth / 2, arrowHeight)
      // Move back to arrow tip for the line
      ..moveTo(centerX, 0)
      // Start with a straight line segment before the squiggle
      ..lineTo(centerX, 11)
      ..quadraticBezierTo(centerX, 11, centerX - 2, straightStart);

    // Create squiggle waves continuing from where we left off
    double y = straightStart;
    int direction = -1; // Start right since the intro went left

    for (int i = 0; i < 3; i++) {
      final nextY = y + waveHeight;
      final controlY = y + waveHeight / 2;

      path.quadraticBezierTo(
        centerX + (amplitude * direction),
        controlY,
        centerX,
        nextY,
      );

      y = nextY;
      direction *= -1;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return false;
  }
}

// ABOUTME: Character counter widget for text inputs with visual feedback
// ABOUTME: Shows current/max characters with color coding for limits and warnings

import 'package:flutter/material.dart';

class CharacterCounterWidget extends StatelessWidget {
  final int current;
  final int max;
  final int? warningThreshold;
  final TextStyle? style;

  const CharacterCounterWidget({
    super.key,
    required this.current,
    required this.max,
    this.warningThreshold,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final threshold = warningThreshold ?? (max * 0.8).round();
    final isNearLimit = current >= threshold;
    final isOverLimit = current > max;
    
    Color textColor;
    if (isOverLimit) {
      textColor = Colors.red;
    } else if (isNearLimit) {
      textColor = Colors.orange;
    } else {
      textColor = Colors.grey;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isNearLimit) ...[
          Icon(
            isOverLimit ? Icons.error : Icons.warning,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          '$current/$max',
          style: style?.copyWith(color: textColor) ?? TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
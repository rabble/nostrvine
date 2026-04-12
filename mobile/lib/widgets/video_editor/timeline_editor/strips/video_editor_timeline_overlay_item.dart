import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';

/// Visual representation of a single overlay item.
class TimelineOverlayItemTile extends StatelessWidget {
  const TimelineOverlayItemTile({
    required this.item,
    required this.width,
    required this.height,
    required this.color,
    super.key,
    this.isDragging = false,
  });

  final TimelineOverlayItem item;
  final double width;
  final double height;
  final Color color;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final radius = BorderRadius.circular(
      TimelineConstants.thumbnailRadius,
    );
    final animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return SizedBox(
      width: width,
      height: height - TimelineConstants.overlayRowGap,
      child: AnimatedContainer(
        duration: animDuration,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDragging ? 0.85 : 0.7),
          borderRadius: radius,
          boxShadow: isDragging
              ? const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        foregroundDecoration: isDragging
            ? BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.white, width: 1.5),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

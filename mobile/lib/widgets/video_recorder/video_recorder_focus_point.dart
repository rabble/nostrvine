// ABOUTME: Animated focus point indicator widget for camera tap-to-focus
// ABOUTME: Shows a circular indicator at tap location with scale and fade animations

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

/// Animated focus point indicator for tap-to-focus functionality.
class VideoRecorderFocusPoint extends ConsumerStatefulWidget {
  /// Creates a focus point indicator widget.
  const VideoRecorderFocusPoint({super.key});

  /// Size of the focus indicator in pixels.
  static const indicatorSize = 36.0;

  @override
  ConsumerState<VideoRecorderFocusPoint> createState() =>
      _VideoRecorderFocusPointState();
}

class _VideoRecorderFocusPointState
    extends ConsumerState<VideoRecorderFocusPoint> {
  Offset _lastVisiblePosition = .zero;

  /// Transform camera coordinates to display coordinates based on
  /// FittedBox.cover
  Offset _cameraToDisplayCoordinates({
    required double cropAspectRatio,
    required double sensorAspectRatio,
    required Offset cameraPoint,
  }) {
    // SizedBox aspect ratio = (100/sensorAR) / 100 = 1/sensorAR
    // arRatio compares display to sizedbox aspect ratios
    final arRatio = cropAspectRatio * sensorAspectRatio;

    double displayX;
    double displayY;

    if (arRatio > 1) {
      // Display is wider relative to camera - height is cropped
      final visibleHeight = 1 / arRatio;
      final cropY = (1 - visibleHeight) / 2;
      displayX = cameraPoint.dx;
      displayY = (cameraPoint.dy - cropY) * arRatio;
    } else {
      // Display is taller relative to camera - width is cropped
      final visibleWidth = arRatio;
      final cropX = (1 - visibleWidth) / 2;
      displayX = (cameraPoint.dx - cropX) / arRatio;
      displayY = cameraPoint.dy;
    }

    return Offset(displayX.clamp(0, 1), displayY.clamp(0, 1));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      videoRecorderProvider.select(
        (s) => (
          aspectRatio: s.aspectRatio.value,
          sensorAspectRatio: s.cameraSensorAspectRatio,
          focusPoint: s.focusPoint,
        ),
      ),
    );

    final isVisible = state.focusPoint != .zero;

    // Remember the last visible position for smooth fade out
    if (isVisible) {
      _lastVisiblePosition = state.focusPoint;
    }

    // Transform camera coordinates to display coordinates
    final cameraPoint = isVisible ? state.focusPoint : _lastVisiblePosition;
    final displayPosition = _cameraToDisplayCoordinates(
      cropAspectRatio: state.aspectRatio,
      sensorAspectRatio: state.sensorAspectRatio,
      cameraPoint: cameraPoint,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Convert normalized coordinates (0.0-1.0) to pixel coordinates
        final x = displayPosition.dx * constraints.maxWidth;
        final y = displayPosition.dy * constraints.maxHeight;

        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                left: x - VideoRecorderFocusPoint.indicatorSize / 2,
                top: y - VideoRecorderFocusPoint.indicatorSize / 2,
                child: AnimatedOpacity(
                  opacity: isVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('Focus-Point-${state.focusPoint}'),
                    duration: const Duration(milliseconds: 300),
                    tween: Tween(
                      begin: isVisible ? 1.2 : 1.0,
                      end: isVisible ? 1.0 : 0.8,
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: const _FocusPoint(),
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

class _FocusPoint extends StatelessWidget {
  const _FocusPoint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: VideoRecorderFocusPoint.indicatorSize,
      height: VideoRecorderFocusPoint.indicatorSize,
      decoration: BoxDecoration(
        border: .all(
          color: const Color(0xFFFFFFFF),
          width: VideoRecorderFocusPoint.indicatorSize * 0.025,
        ),
        shape: .circle,
      ),
      child: Center(
        child: Container(
          width: VideoRecorderFocusPoint.indicatorSize * 0.05,
          height: VideoRecorderFocusPoint.indicatorSize * 0.05,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            shape: .circle,
          ),
        ),
      ),
    );
  }
}

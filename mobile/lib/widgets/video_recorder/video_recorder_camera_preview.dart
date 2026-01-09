// ABOUTME: Camera preview widget with animated aspect ratio transitions and grid overlay
// ABOUTME: Handles tap-to-focus and displays rule-of-thirds grid during non-recording state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_placeholder.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_focus_point.dart';

/// Displays the camera preview with animated aspect ratio changes.
///
/// Includes a grid overlay for composition guidance and tap-to-focus
/// functionality.
class VideoRecorderCameraPreview extends ConsumerStatefulWidget {
  /// Creates a camera preview widget.
  const VideoRecorderCameraPreview({
    required this.previewWidgetRadius,
    super.key,
  });

  /// Radius for rounded corners of the preview widget.
  final double previewWidgetRadius;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _VideoRecorderCameraPreviewState();
}

class _VideoRecorderCameraPreviewState
    extends ConsumerState<VideoRecorderCameraPreview> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      videoRecorderProvider.select(
        (s) => (
          aspectRatio: s.aspectRatio.value,
          sensorAspectRatio: s.cameraSensorAspectRatio,
          showGrid: !s.isRecording,
          isCameraInitialized: s.isCameraInitialized,
          cameraRebuildCount: s.cameraRebuildCount,
        ),
      ),
    );

    return Center(
      child: Padding(
        padding: const .symmetric(horizontal: 4),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          tween: Tween(begin: state.aspectRatio, end: state.aspectRatio),
          builder: (context, aspectRatio, _) {
            return AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                clipBehavior: .hardEdge,
                borderRadius: .circular(widget.previewWidgetRadius),
                child: Stack(
                  fit: .expand,
                  key: ValueKey('Camera-Count-${state.cameraRebuildCount}'),
                  children: _buildStackItems(
                    showGrid: state.showGrid,
                    isCameraInitialized: state.isCameraInitialized,
                    sensorAspectRatio: state.sensorAspectRatio,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildStackItems({
    required bool isCameraInitialized,
    required bool showGrid,
    required double sensorAspectRatio,
  }) {
    final previewWidget = ref
        .read(videoRecorderProvider.notifier)
        .previewWidget;

    return [
      if (isCameraInitialized && previewWidget != null)
        _buildCameraPreview(
          previewWidget: previewWidget,
          sensorAspectRatio: sensorAspectRatio,
        )
      else
        const VideoRecorderCameraPlaceholder(),
      _buildOverlayGrid(showGrid),
      const VideoRecorderFocusPoint(),
    ];
  }

  Widget _buildCameraPreview({
    required Widget previewWidget,
    required double sensorAspectRatio,
  }) {
    return FittedBox(
      fit: .cover,
      child: SizedBox(
        width: 100 / sensorAspectRatio,
        height: 100,
        child: Stack(
          children: [
            /// Skeleton when switching camera
            Container(color: const Color(0xFF141414)),

            /// Preview widget
            previewWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayGrid(bool showGrid) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: showGrid ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: CustomPaint(painter: _GridPainter()),
      ),
    );
  }
}

/// Custom painter for grid overlay (rule of thirds)
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xBEFFFFFF)
      ..strokeWidth = 1;

    // Vertical lines
    canvas
      ..drawLine(
        Offset(size.width / 3, 0),
        Offset(size.width / 3, size.height),
        paint,
      )
      ..drawLine(
        Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height),
        paint,
      )
      // Horizontal lines
      ..drawLine(
        Offset(0, size.height / 3),
        Offset(size.width, size.height / 3),
        paint,
      )
      ..drawLine(
        Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

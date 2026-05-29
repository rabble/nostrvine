// ABOUTME: Camera preview widget with animated aspect ratio transitions and grid overlay
// ABOUTME: Handles tap-to-focus and displays rule-of-thirds grid during non-recording state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/utils/platform_helpers.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_mobile_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_placeholder.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_focus_point.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_ghost_frame.dart';

/// Displays the camera preview with animated aspect ratio changes.
///
/// Includes a grid overlay for composition guidance and tap-to-focus
/// functionality.
class VideoRecorderCameraPreview extends StatelessWidget {
  /// Creates a camera preview widget.
  const VideoRecorderCameraPreview({
    this.enableTapToFocus = true,
    this.borderRadius = .zero,
    super.key,
  });

  final BorderRadius borderRadius;
  final bool enableTapToFocus;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = context.select(
          (VideoRecorderBloc b) => b.state.aspectRatio,
        );
        // In vertical mode, we use the full available screen size,
        // even if it's not exactly 16:9.
        final aspectRatioValue = aspectRatio == .vertical
            ? isDesktopPlatform
                  ? 9 / 16
                  : constraints.biggest.aspectRatio
            : 1.0;

        return Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            tween: Tween(begin: aspectRatioValue, end: aspectRatioValue),
            builder: (context, aspectRatio, _) {
              return AspectRatio(
                aspectRatio: aspectRatio,
                child: ClipRRect(
                  clipBehavior: .hardEdge,
                  borderRadius: borderRadius,
                  child: _StackItems(enableTapToFocus: enableTapToFocus),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StackItems extends StatelessWidget {
  const _StackItems({required this.enableTapToFocus});

  final bool enableTapToFocus;

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        isCameraInitialized: b.state.isCameraInitialized,
        cameraRebuildCount: b.state.cameraRebuildCount,
        initializationErrorMessage: b.state.initializationErrorMessage,
      ),
    );
    return Stack(
      fit: .expand,
      key: ValueKey('Camera-Count-${state.cameraRebuildCount}'),
      children: [
        if (state.isCameraInitialized)
          _CameraPreview(enableTapToFocus: enableTapToFocus)
        else
          VideoRecorderCameraPlaceholder(
            errorMessage: state.initializationErrorMessage,
          ),
        const VideoRecorderGhostFrame(),
        const _OverlayGrid(),
        if (enableTapToFocus) const VideoRecorderFocusPoint(),
      ],
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.enableTapToFocus});

  final bool enableTapToFocus;

  @override
  Widget build(BuildContext context) {
    final sensorAspectRatio = context.select(
      (VideoRecorderBloc b) => b.state.cameraSensorAspectRatio,
    );

    return FittedBox(
      fit: .cover,
      child: SizedBox(
        width: 1000 * sensorAspectRatio,
        height: 1000,
        child: Stack(
          children: [
            Container(color: const Color(0xFF141414)),

            /// Preview widget
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux)
              const SizedBox.shrink()
            else
              VideoRecorderMobilePreview(enableTapToFocus: enableTapToFocus),
          ],
        ),
      ),
    );
  }
}

class _OverlayGrid extends StatelessWidget {
  const _OverlayGrid();

  @override
  Widget build(BuildContext context) {
    final (:isRecording, :showGridLines) = context.select(
      (VideoRecorderBloc b) => (
        isRecording: b.state.isRecording,
        showGridLines: b.state.showGridLines,
      ),
    );

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: (isRecording || !showGridLines) ? 0.0 : 1.0,
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
      ..color = VineTheme.onSurfaceVariant
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

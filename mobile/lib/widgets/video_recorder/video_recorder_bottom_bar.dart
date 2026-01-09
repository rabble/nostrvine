// ABOUTME: Bottom bar widget for video recorder screen
// ABOUTME: Contains flash, timer, record button, camera flip, and more options

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_more_sheet.dart';

/// Bottom bar with record button and camera controls.
class VideoRecorderBottomBar extends ConsumerWidget {
  /// Creates a video recorder bottom bar widget.
  const VideoRecorderBottomBar({required this.previewWidgetRadius, super.key});

  /// Radius for the preview widget's inverted corners.
  final double previewWidgetRadius;
  static const double _bottomBarHeight = 64;

  /// Show more options menu
  Future<void> _showMoreOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101111),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: .vertical(top: .circular(32)),
      ),
      builder: (context) => const VideoRecorderMoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref.watch(
      videoRecorderProvider.select((p) => p.isRecording),
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Stack(
          alignment: .bottomCenter,
          children: [
            /// Record button
            _buildRecordButton(ref, isRecording),

            /// BottomBar
            Stack(
              alignment: .bottomCenter,
              clipBehavior: .none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: child,
                    ),
                  ),
                  child: isRecording
                      ? const SizedBox.shrink()
                      : _buildActionButtons(context, ref),
                ),

                /// Helper widget which create a inner radius for the camera
                /// preview so long it's not recording.
                Positioned(
                  top: -previewWidgetRadius,
                  left: 4,
                  right: 4,
                  child: CustomPaint(
                    painter: _InvertedRadiusPainter(
                      color: Colors.black,
                      radius: previewWidgetRadius,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build record button
  Widget _buildRecordButton(WidgetRef ref, bool isRecording) {
    final notifier = ref.read(videoRecorderProvider.notifier);
    final timerDuration = ref.watch(
      videoRecorderProvider.select((p) => p.timerDuration),
    );
    final isLongPressSupported = timerDuration == .off;

    return Semantics(
      button: true,
      label: isRecording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        key: const ValueKey('divine-camera-record-button'),
        onTap: notifier.toggleRecording,
        onLongPressStart: isLongPressSupported
            ? (_) => notifier.startRecording()
            : null,
        onLongPressMoveUpdate: isRecording && isLongPressSupported
            ? (details) =>
                  notifier.zoomByLongPressMove(details.localOffsetFromOrigin)
            : null,
        onLongPressUp: isLongPressSupported ? notifier.stopRecording : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const .only(bottom: _bottomBarHeight + 20),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            border: .all(color: Colors.white, width: 4),
            borderRadius: .circular(36),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              width: isRecording ? 32 : 64,
              height: isRecording ? 32 : 64,
              decoration: ShapeDecoration(
                color: const Color(0xFFF44336),
                shape: RoundedRectangleBorder(
                  borderRadius: .circular(isRecording ? 6 : 20),
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 1,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the action buttons
  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoRecorderProvider.notifier);

    final state = ref.watch(
      videoRecorderProvider.select(
        (p) => (
          flashMode: p.flashMode,
          timer: p.timerDuration,
          aspectRatio: p.aspectRatio,
          canSwitchCamera: p.canSwitchCamera,
          hasFlash: p.hasFlash,
        ),
      ),
    );

    return Container(
      color: Colors.black,
      height: _bottomBarHeight,
      child: Row(
        mainAxisAlignment: .spaceAround,
        children: [
          // Flash toggle
          _buildControlButton(
            iconPath: state.flashMode.iconPath,
            label: 'Toggle flash',
            onPressed: state.hasFlash ? notifier.toggleFlash : null,
          ),

          // Timer toggle
          _buildControlButton(
            iconPath: state.timer.iconPath,
            label: 'Cycle timer',
            onPressed: notifier.cycleTimer,
          ),

          // Aspect-Ratio
          _buildControlButton(
            iconPath: state.aspectRatio == .square
                ? 'assets/icon/crop_square.svg'
                : 'assets/icon/crop_portrait.svg',
            label: 'Toggle aspect ratio',
            onPressed: notifier.toggleAspectRatio,
          ),

          // Flip camera
          _buildControlButton(
            iconPath: 'assets/icon/refresh.svg',
            label: 'Switch camera',
            onPressed: state.canSwitchCamera ? notifier.switchCamera : null,
          ),

          // More options
          _buildControlButton(
            iconPath: 'assets/icon/more_horiz.svg',
            label: 'More options',
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
    );
  }

  /// Build control button with optional label
  Widget _buildControlButton({
    required String iconPath,
    required VoidCallback? onPressed,
    String? label,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      icon: SizedBox(
        height: 32,
        width: 32,
        child: SvgPicture.asset(
          iconPath,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}

/// Custom painter for inverted radius at top-left and top-right corners
class _InvertedRadiusPainter extends CustomPainter {
  /// Creates an inverted radius painter.
  _InvertedRadiusPainter({required this.radius, required this.color});

  /// Radius of the inverted corners.
  final double radius;

  /// Color to paint with.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      // Start from left side
      ..moveTo(0, 0)
      ..lineTo(0, radius)
      ..lineTo(radius, radius)
      // Draw left inverted corner (concave inward)
      ..quadraticBezierTo(0, radius, 0, 0);

    canvas.drawPath(path, paint);

    // Right side path
    final rightPath = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, radius)
      ..lineTo(size.width - radius, radius)
      // Draw right inverted corner (concave inward)
      ..quadraticBezierTo(size.width, radius, size.width, 0);

    canvas.drawPath(rightPath, paint);

    // Important to draw bottom 2px black rectangle which ensure there is no gap
    // to the bottom bar.
    final bottomRect = Rect.fromLTWH(0, radius, size.width, 2);
    canvas.drawRect(bottomRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ABOUTME: Fallback placeholder widget displayed when camera is unavailable
// ABOUTME: Shows different icons and text for idle and recording states

import 'package:flutter/material.dart';

/// Fallback preview widget for when camera is not available
class VideoRecorderCameraPlaceholder extends StatelessWidget {
  /// Creates a camera placeholder widget.
  const VideoRecorderCameraPlaceholder({super.key, this.isRecording = false});

  /// Whether the camera is currently recording.
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: .min,
            children: [
              Icon(
                isRecording ? Icons.fiber_manual_record : Icons.videocam,
                size: 64,
                color: isRecording ? Colors.red : Colors.white54,
              ),
              const SizedBox(height: 8),
              Text(
                isRecording ? 'Recording...' : 'Camera Preview',
                style: TextStyle(
                  color: isRecording ? Colors.red : Colors.white54,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

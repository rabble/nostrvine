// ABOUTME: Fallback placeholder widget displayed when camera is unavailable
// ABOUTME: Shows idle icon or error message when camera initialization fails

import 'package:flutter/material.dart';

/// Fallback preview widget for when camera is not available
class VideoRecorderCameraPlaceholder extends StatelessWidget {
  /// Creates a camera placeholder widget.
  const VideoRecorderCameraPlaceholder({super.key, this.errorMessage});

  /// Optional error message to display when camera initialization fails.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF141414),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              errorMessage != null
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              size: 56,
              color: const Color(0xB3FFFFFF),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

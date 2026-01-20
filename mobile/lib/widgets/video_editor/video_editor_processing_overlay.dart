// ABOUTME: Processing overlay with mascot and progress indicator.
// ABOUTME: Displays during video export operations.

import 'package:flutter/material.dart';

/// Overlay widget displayed during video processing operations.
///
/// Shows the Divine mascot with wings and a "Processing..." message
/// with a progress bar animation.
class VideoEditorProcessingOverlay extends StatelessWidget {
  /// Creates a processing overlay.
  const VideoEditorProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xA4000000),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: const Color(0xFF151616),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x51000000),
                blurRadius: 3,
                offset: Offset(0, 1),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Color(0x28000000),
                blurRadius: 8,
                offset: Offset(0, 4),
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: .min,
            children: [
              Image.asset(
                'assets/icon/divine_icon_transparent.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),

              // Processing text
              const Text(
                'Processing...',
                textAlign: .center,
                style: TextStyle(
                  fontFamily: 'BricolageGrotesque',
                  fontWeight: .w800,
                  fontSize: 14,
                  height: 1.43,
                  letterSpacing: 0.1,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

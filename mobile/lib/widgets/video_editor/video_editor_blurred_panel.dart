// ABOUTME: Reusable blurred panel with iOS-style frosted glass effect.
// ABOUTME: Used for font selector, color picker, and other overlay panels.

import 'package:flutter/material.dart';

/// A reusable panel with iOS-style frosted glass blur effect.
///
/// Used for overlay panels like font selector, color picker, etc.
class VideoEditorBlurredPanel extends StatelessWidget {
  const VideoEditorBlurredPanel({super.key, required this.child, this.height});

  /// The content to display inside the blurred panel.
  final Widget child;

  /// Optional fixed height. If null, the panel sizes to its content.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const .vertical(top: .circular(28)),
      child: GestureDetector(
        onTap: () {}, // Important to absorb events here.
        behavior: .opaque,
        child: BackdropFilter(
          filter: .blur(sigmaX: 30, sigmaY: 30),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D0D),
              backgroundBlendMode: .lighten,
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color.fromARGB(228, 20, 20, 20),
                backgroundBlendMode: .luminosity,
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(height: height, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

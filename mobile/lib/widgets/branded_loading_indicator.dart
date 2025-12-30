// ABOUTME: Branded loading indicator widget using the divine logo GIF animation
// ABOUTME: Replaces generic CircularProgressIndicator with branded experience

import 'package:flutter/material.dart';

/// A branded loading indicator that displays the animated divine logo.
///
/// This widget shows the divine wings flapping animation as a GIF.
class BrandedLoadingIndicator extends StatelessWidget {
  const BrandedLoadingIndicator({super.key, this.size = 80.0});

  /// The size (width and height) of the loading indicator.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/loading-brand.gif',
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Use gaplessPlayback to prevent flash when GIF restarts
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Failed to load loading-brand.gif: $error\n$stackTrace');
          return Container(
            width: size,
            height: size,
            color: const Color.fromRGBO(255, 0, 0, 0.3),
            child: const Center(
              child: Text(
                'GIF error',
                style: TextStyle(fontSize: 10, color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}

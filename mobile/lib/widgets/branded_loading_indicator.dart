// ABOUTME: Branded loading indicator widget using the divine logo with rotation
// ABOUTME: Replaces generic CircularProgressIndicator with branded experience

import 'package:flutter/material.dart';

/// A branded loading indicator that displays the animated divine logo.
///
/// This widget shows the divine play button logo with a smooth rotation
/// animation to indicate loading state.
class BrandedLoadingIndicator extends StatefulWidget {
  const BrandedLoadingIndicator({super.key, this.size = 80.0});

  /// The size (width and height) of the loading indicator.
  final double size;

  @override
  State<BrandedLoadingIndicator> createState() =>
      _BrandedLoadingIndicatorState();
}

class _BrandedLoadingIndicatorState extends State<BrandedLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: Image.asset(
          'assets/icon/divine_icon_transparent.png',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

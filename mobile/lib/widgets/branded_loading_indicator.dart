// ABOUTME: Branded loading indicator widget using the divine logo GIF animation
// ABOUTME: Replaces generic CircularProgressIndicator with branded experience

import 'package:flutter/material.dart';

/// A branded loading indicator that displays the animated divine logo.
///
/// This widget shows the divine wings flapping animation as a GIF.
/// It fades in after a delay to avoid flashing on quick loads.
class BrandedLoadingIndicator extends StatefulWidget {
  const BrandedLoadingIndicator({
    super.key,
    this.size = 80.0,
    this.delay = const Duration(milliseconds: 1500),
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  /// The size (width and height) of the loading indicator.
  final double size;

  /// Delay before showing the loading indicator.
  /// Prevents flashing on quick loads.
  final Duration delay;

  /// Duration of the fade-in animation.
  final Duration fadeInDuration;

  @override
  State<BrandedLoadingIndicator> createState() =>
      _BrandedLoadingIndicatorState();
}

class _BrandedLoadingIndicatorState extends State<BrandedLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start showing after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() {
          _showIndicator = true;
        });
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showIndicator) {
      // Return empty SizedBox to preserve layout during delay
      return SizedBox(width: widget.size, height: widget.size);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Image.asset(
          'assets/loading-brand.gif',
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Failed to load loading-brand.gif: $error\n$stackTrace');
            // Fallback to a simple colored box with error text for debugging
            return Container(
              width: widget.size,
              height: widget.size,
              color: const Color.fromRGBO(255, 0, 0, 0.3),
              child: const Center(
                child: Text(
                  'GIF load failed',
                  style: TextStyle(fontSize: 10, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

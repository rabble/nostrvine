// ABOUTME: Branded loading indicator widget using the divine logo SVG animation
// ABOUTME: Replaces generic CircularProgressIndicator with branded experience

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A branded loading indicator that displays the animated divine logo.
///
/// This widget renders the loading-brand.svg which contains a 27-frame
/// animation of the divine play button logo with a rotating halo effect.
class BrandedLoadingIndicator extends StatelessWidget {
  const BrandedLoadingIndicator({super.key, this.size = 80.0});

  /// The size (width and height) of the loading indicator.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/loading-brand.svg',
        width: size,
        height: size,
      ),
    );
  }
}

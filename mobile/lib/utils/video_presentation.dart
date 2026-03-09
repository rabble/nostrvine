import 'package:flutter/material.dart';

const double _squareAspectRatioTolerance = 0.1;

/// Returns true when the dimensions are close enough to 1:1 to treat as square.
bool isSquareVideoDimensions(
  num? width,
  num? height, {
  double tolerance = _squareAspectRatioTolerance,
}) {
  if (width == null || height == null) return false;
  if (width <= 0 || height <= 0) return false;

  final aspectRatio = width / height;
  return aspectRatio >= 1 - tolerance && aspectRatio <= 1 + tolerance;
}

/// Square clips should sit at the top of the stage instead of being centered.
Alignment videoAlignmentForDimensions(num? width, num? height) {
  return isSquareVideoDimensions(width, height)
      ? Alignment.topCenter
      : Alignment.center;
}

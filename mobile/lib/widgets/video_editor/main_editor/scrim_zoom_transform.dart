// ABOUTME: Maps the editor's pinch-zoom matrix into body-space for the
// ABOUTME: letterbox scrim so the dark bars track the magnified video.

import 'dart:math';

import 'package:flutter/widgets.dart';

/// Maps the editor's zoom [editorMatrix] (expressed in the editor's
/// render-space, where pinch translation is in render pixels) into the
/// body-space transform for the letterbox scrim, so the bars track the
/// magnified video instead of lagging behind it.
///
/// The editor content is cover-fitted from its render size into
/// [targetSize] and centered in [boxSize]. With that fit+centre affine
/// `A`, the on-screen effect of `editorMatrix` (`M`) in body coordinates is
/// `A · M · A⁻¹`. For a zoom-only `M` (uniform scale `k`, translation `t`),
/// that reduces to: same scale `k`, translation `coverScale·t + (1-k)·d`,
/// where `d` is the body-space offset of the render origin. Without the
/// `coverScale` factor the bars move too little.
///
/// Assumes a scale+translate matrix (pinch zoom on the canvas); any
/// rotation/skew is collapsed to a uniform scale by
/// [Matrix4.getMaxScaleOnAxis]. Returns the identity transform for a
/// degenerate (zero-area) box so the scrim renders untransformed.
Matrix4 scrimZoomTransform({
  required Matrix4 editorMatrix,
  required Size boxSize,
  required Size targetSize,
  required double originalAspectRatio,
}) {
  final renderHeight = boxSize.shortestSide;
  final renderWidth = renderHeight * originalAspectRatio;
  if (renderWidth <= 0 || renderHeight <= 0) return Matrix4.identity();

  final coverScale = max(
    targetSize.width / renderWidth,
    targetSize.height / renderHeight,
  );
  final dx = (boxSize.width - coverScale * renderWidth) / 2;
  final dy = (boxSize.height - coverScale * renderHeight) / 2;

  final k = editorMatrix.getMaxScaleOnAxis();
  final t = editorMatrix.getTranslation();

  return Matrix4.identity()
    ..setEntry(0, 0, k)
    ..setEntry(1, 1, k)
    ..setEntry(0, 3, coverScale * t.x + (1 - k) * dx)
    ..setEntry(1, 3, coverScale * t.y + (1 - k) * dy);
}

import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';

/// Calculates scale and offset values for gallery items.
///
/// Provides depth effect by scaling and offsetting clips based on
/// their distance from the center of the viewport.
class GalleryTransformCalculator {
  const GalleryTransformCalculator({
    required this.pageController,
    required this.constraints,
    required this.clips,
    required this.activeClipIndex,
    required this.selectedClipIndex,
    required this.isReordering,
  });

  /// Controller for page scrolling state.
  final PageController pageController;

  /// Layout constraints of the gallery container.
  final BoxConstraints constraints;

  /// List of clips to calculate transforms for.
  final List<RecordingClip> clips;

  /// Index of the currently active clip.
  final int activeClipIndex;

  /// Index of the selected clip.
  final int selectedClipIndex;

  /// Whether clips are being reordered.
  final bool isReordering;

  /// Gets the current page value from controller or selected index.
  double _getCurrentPage() {
    if (!pageController.hasClients) {
      return selectedClipIndex.toDouble();
    }
    return pageController.page ?? selectedClipIndex.toDouble();
  }

  /// Calculates the scale factor for a clip based on its distance from center.
  ///
  /// Returns 1.0 for the centered clip and 0.85 for clips far from center,
  /// with linear interpolation in between.
  double calculateScale(int index) {
    if (isReordering || !pageController.hasClients) {
      return index == activeClipIndex
          ? VideoEditorGalleryConstants.maxScale
          : VideoEditorGalleryConstants.minScale;
    }

    final page = pageController.page ?? selectedClipIndex.toDouble();
    final difference = (page - index).abs();

    if (difference >= 1) {
      return VideoEditorGalleryConstants.minScale;
    }

    return VideoEditorGalleryConstants.maxScale -
        (difference *
            (VideoEditorGalleryConstants.maxScale -
                VideoEditorGalleryConstants.minScale));
  }

  /// Calculates the effect strength based on distance from center.
  ///
  /// The effect has three zones:
  /// - [0, offsetStart]: no offset (clips wait)
  /// - [offsetStart, 1.0]: offset increases cubically to max
  /// - [1.0, falloffEnd]: gradual linear falloff
  double _calculateEffectStrength(double absDifference, double falloffEnd) {
    final falloffRange = falloffEnd - 1.0;

    if (absDifference < VideoEditorGalleryConstants.offsetStart) {
      return 0;
    } else if (absDifference <= 1.0) {
      final remapped =
          (absDifference - VideoEditorGalleryConstants.offsetStart) /
          (1.0 - VideoEditorGalleryConstants.offsetStart);
      return remapped * remapped * remapped;
    } else {
      return (falloffEnd - absDifference) / falloffRange;
    }
  }

  /// Calculates the horizontal offset for a clip to create depth effect.
  double calculateXOffset(int index) {
    if (isReordering) return 0;

    final clipRatio = clips.first.aspectRatio.value;
    final containerWidth =
        constraints.maxWidth * VideoEditorGalleryConstants.viewportFraction;
    final actualWidth = (constraints.maxHeight * clipRatio).clamp(
      0.0,
      containerWidth,
    );
    final emptySpace = containerWidth - actualWidth;
    final fillRatio = actualWidth / containerWidth;

    final maxOffset =
        (constraints.maxWidth *
            (1 - VideoEditorGalleryConstants.viewportFraction)) +
        emptySpace;

    final page = _getCurrentPage();
    final difference = index - page;
    final absDifference = difference.abs();

    // Dynamic falloff values based on fillRatio
    final falloffRange =
        VideoEditorGalleryConstants.falloffRangeMultiplier * fillRatio;
    final falloffEnd = 1.0 + falloffRange;

    // Offset is 0 for clips beyond falloffEnd
    if (absDifference > falloffEnd) return 0;

    final effectStrength = _calculateEffectStrength(absDifference, falloffEnd);
    final scaledEased =
        effectStrength * VideoEditorGalleryConstants.viewportFraction;

    return -(difference.sign * scaledEased * maxOffset);
  }
}

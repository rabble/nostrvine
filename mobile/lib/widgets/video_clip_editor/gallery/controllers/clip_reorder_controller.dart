// ABOUTME: Controller for clip reorder state and drag tracking
// ABOUTME: Manages drag offsets, target indices, threshold detection and animations

import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_constants.dart';

/// Controller that manages clip reorder state during drag operations.
///
/// This controller encapsulates all state related to reordering clips
/// in the video editor gallery, including:
/// - Drag offset tracking for visual feedback
/// - Target index calculation during drag
/// - Animation values for drag reset
/// - Threshold detection for page switching
/// - Delete zone tracking
class ClipReorderController extends ChangeNotifier {
  /// The index where the drag operation started.
  int get startIndex => _startIndex;
  int _startIndex = 0;

  /// The current target index during reordering.
  int get targetIndex => _targetIndex;
  int _targetIndex = 0;

  /// The most recently updated index during drag.
  int get updatedIndex => _updatedIndex;
  int _updatedIndex = 0;

  /// Accumulated horizontal drag offset for threshold detection.
  double get accumulatedDragOffset => _accumulatedDragOffset;
  double _accumulatedDragOffset = 0;

  /// The drag offset value when reset animation started.
  double get dragResetStartValue => _dragResetStartValue;
  double _dragResetStartValue = 0;

  /// Whether tween animations should be enabled for offsets.
  bool get enableTweenOffset => _enableTweenOffset;
  bool _enableTweenOffset = false;

  /// Notifier for visual drag offset (used for rotation effect).
  final dragOffsetNotifier = ValueNotifier<double>(0);

  /// Notifier for vertical drag offset (used for follow-finger effect).
  final dragYOffsetNotifier = ValueNotifier<double>(0);

  /// The Y offset value when reset animation started.
  double _dragYResetStartValue = 0;

  /// Initializes the controller for a new reorder operation.
  ///
  /// Call this when the user starts dragging a clip (long press).
  void startReorder(int clipIndex) {
    _startIndex = clipIndex;
    _targetIndex = clipIndex;
    _updatedIndex = clipIndex;
    _accumulatedDragOffset = 0;
    _enableTweenOffset = true;
    dragOffsetNotifier.value = 0;
    dragYOffsetNotifier.value = 0;
    notifyListeners();
  }

  /// Updates the accumulated drag offset.
  void addDragOffset(double delta) {
    _accumulatedDragOffset += delta;
  }

  /// Resets the accumulated drag offset.
  void resetAccumulatedOffset() {
    _accumulatedDragOffset = 0;
  }

  /// Updates the target index during reorder.
  void updateTargetIndex(int newIndex) {
    _targetIndex = newIndex;
    _updatedIndex = newIndex;
    _accumulatedDragOffset = 0;
    notifyListeners();
  }

  /// Prepares for drag reset animation (X only).
  ///
  /// Used when entering the delete zone — only X resets,
  /// the clip stays at its current Y position.
  void prepareForDragReset() {
    _dragResetStartValue = dragOffsetNotifier.value;
    _dragYResetStartValue = 0;
  }

  /// Prepares for a full drag reset animation (both X and Y).
  ///
  /// Used when the user releases the drag without deleting.
  void prepareForFullDragReset() {
    _dragResetStartValue = dragOffsetNotifier.value;
    _dragYResetStartValue = dragYOffsetNotifier.value;
  }

  /// Updates the visual drag offset during animation reset.
  ///
  /// Resets Y only when [prepareForFullDragReset] was called — i.e., when
  /// [_dragYResetStartValue] is non-zero.
  void updateDragOffsetFromAnimation(double progress) {
    dragOffsetNotifier.value = _dragResetStartValue * (1 - progress);
    if (_dragYResetStartValue != 0) {
      dragYOffsetNotifier.value = _dragYResetStartValue * (1 - progress);
    }
  }

  /// Completes the reorder operation and resets state.
  void completeReorder() {
    dragOffsetNotifier.value = 0;
    dragYOffsetNotifier.value = 0;
    _dragYResetStartValue = 0;
    _accumulatedDragOffset = 0;
  }

  /// Disables tween animations after reorder completes.
  void disableTweenOffset() {
    _enableTweenOffset = false;
    notifyListeners();
  }

  /// Whether the X drag offset should trigger a reset animation.
  bool get shouldAnimateXReset => dragOffsetNotifier.value.abs() > 0.1;

  /// Whether the drag offset should trigger a reset animation.
  bool get shouldAnimateReset =>
      dragOffsetNotifier.value.abs() > 0.1 ||
      dragYOffsetNotifier.value.abs() > 0.1;

  // ─────────────────────────────────────────────────────────────────────────
  // Threshold and Delete Zone Logic
  // ─────────────────────────────────────────────────────────────────────────

  /// Checks if pointer is leaving the clip area vertically.
  bool isLeavingClipArea(double localY, double maxHeight) {
    return localY > maxHeight + VideoEditorGalleryConstants.clipAreaPadding;
  }

  /// Updates the visual drag offset (for rotation effect), clamped to bounds.
  ///
  /// [contentScale] compensates for the outer `AnimatedScale` so the clip
  /// follows the finger 1:1 in screen space.
  void updateVisualDragOffset(
    double deltaX,
    double maxWidth, {
    double contentScale = 1.0,
  }) {
    final maxDragOffset =
        maxWidth * VideoEditorGalleryConstants.dragClampFactor / contentScale;
    dragOffsetNotifier.value =
        (dragOffsetNotifier.value + deltaX / contentScale).clamp(
          -maxDragOffset,
          maxDragOffset,
        );
  }

  /// Updates the vertical drag offset so the clip follows the finger downward.
  ///
  /// Clamps upward movement to prevent the clip from leaving upward,
  /// but allows free downward movement toward the delete zone.
  ///
  /// [contentScale] compensates for the outer `AnimatedScale` so the clip
  /// follows the finger 1:1 in screen space.
  void updateVisualDragY(double deltaY, {double contentScale = 1.0}) {
    final compensatedClampUp =
        VideoEditorGalleryConstants.dragYClampUp / contentScale;
    final compensatedClampDown =
        VideoEditorGalleryConstants.dragYClampDown / contentScale;
    dragYOffsetNotifier.value =
        (dragYOffsetNotifier.value + deltaY / contentScale).clamp(
          -compensatedClampUp,
          compensatedClampDown,
        );
  }

  /// Calculates the reorder threshold based on viewport and clip count.
  double calculateReorderThreshold(double viewportWidth, int clipCount) {
    return (viewportWidth *
            VideoEditorGalleryConstants.viewportFraction /
            clipCount /
            2)
        .clamp(
          VideoEditorGalleryConstants.reorderThresholdMin,
          VideoEditorGalleryConstants.reorderThresholdMax,
        );
  }

  /// Determines the new target index based on drag direction.
  ///
  /// Returns null if no index change is needed.
  int? calculateNewTargetIndex(int clipCount) {
    if (_accumulatedDragOffset > 0 && _targetIndex < clipCount - 1) {
      return _targetIndex + 1;
    } else if (_accumulatedDragOffset < 0 && _targetIndex > 0) {
      return _targetIndex - 1;
    }
    return null;
  }

  /// Resets drag offset if needed when entering delete zone.
  ///
  /// Only resets the X offset — the clip stays at its current Y position
  /// so it remains visually near the delete zone.
  /// Returns true if a reset animation should be started.
  bool handleEnterDeleteZone() {
    final shouldAnimate = shouldAnimateXReset;
    if (shouldAnimate) {
      prepareForDragReset();
    }
    resetAccumulatedOffset();
    return shouldAnimate;
  }

  /// Calculates the new index after deletion.
  int calculateIndexAfterDeletion(int remainingClipCount) {
    return startIndex >= remainingClipCount
        ? remainingClipCount - 1
        : startIndex;
  }

  @override
  void dispose() {
    dragOffsetNotifier.dispose();
    dragYOffsetNotifier.dispose();
    super.dispose();
  }
}

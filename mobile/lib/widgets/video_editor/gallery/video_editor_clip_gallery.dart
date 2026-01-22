// ABOUTME: Horizontal scrolling clip selector with depth animations
// ABOUTME: PageView with scale, offset transforms and center overlay for z-ordering

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/gallery/controllers/clip_reorder_controller.dart';
import 'package:openvine/widgets/video_editor/gallery/scopes/gallery_calculations.dart';
import 'package:openvine/widgets/video_editor/gallery/scopes/gallery_callbacks.dart';
import 'package:openvine/widgets/video_editor/gallery/utils/gallery_transform_calculator.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_center_clip_overlay.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_edge_gradients.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_instruction_text.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_page_view.dart';

/// Horizontal scrolling clip selector with animated transitions.
class VideoEditorClipGallery extends ConsumerStatefulWidget {
  /// Creates a video editor clips widget.
  const VideoEditorClipGallery({super.key});

  @override
  ConsumerState<VideoEditorClipGallery> createState() =>
      _VideoEditorClipsState();
}

class _VideoEditorClipsState extends ConsumerState<VideoEditorClipGallery>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _dragResetController;
  final _reorderController = ClipReorderController();
  int _lastClipIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: VideoEditorGalleryConstants.viewportFraction,
    );
    _dragResetController = AnimationController(
      vsync: this,
      duration: VideoEditorGalleryConstants.dragResetDuration,
    )..addListener(_onDragResetTick);

    // Listen to currentClipIndex changes
    ref.listenManual(
      videoEditorProvider.select((state) => state.currentClipIndex),
      (previous, next) {
        if (previous != next && next != _lastClipIndex) {
          _lastClipIndex = next;
          unawaited(_navigateToClip(next));
        }
      },
    );
  }

  @override
  void dispose() {
    _dragResetController.dispose();
    _pageController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  /// Animates the page controller to display the clip at [index].
  ///
  /// Uses [Curves.easeOutCubic] for a smooth deceleration effect.
  Future<void> _navigateToClip(int index) async {
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        index,
        duration: VideoEditorGalleryConstants.pageAnimationDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Animation tick handler that smoothly resets the drag offset to zero.
  ///
  /// Called on each frame during the drag reset animation.
  void _onDragResetTick() {
    if (mounted) {
      final progress = Curves.easeOut.transform(_dragResetController.value);
      _reorderController.updateDragOffsetFromAnimation(progress);
    }
  }

  /// Performs a hit test to check if the pointer is over the delete button.
  bool _isPointerOverDeleteButton(Offset globalPosition) {
    final deleteButtonKey = ref.read(videoEditorProvider).deleteButtonKey;

    if (deleteButtonKey.currentContext == null) {
      return false;
    }

    final renderBox =
        deleteButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return false;
    }

    // Convert global position to local coordinates
    final localPosition = renderBox.globalToLocal(globalPosition);

    // Check if the local position is within the bounds
    return renderBox.paintBounds.contains(localPosition);
  }

  /// Initiates clip reorder mode for the currently selected clip.
  ///
  /// Resets drag tracking state and notifies the video editor provider.
  void _handleStartReordering() {
    final currentClipIndex = ref.read(videoEditorProvider).currentClipIndex;

    _reorderController.startReorder(currentClipIndex);
    ref.read(videoEditorProvider.notifier).startClipReordering();
    setState(() {});
  }

  /// Checks if pointer is in delete zone and updates state accordingly.
  ///
  /// Returns true if the pointer is over delete zone or leaving clip area.
  bool _updateDeleteZoneState(
    PointerMoveEvent event,
    BoxConstraints constraints,
  ) {
    final isLeavingClipArea = _reorderController.isLeavingClipArea(
      event.localPosition.dy,
      constraints.maxHeight,
    );

    final isOverDeleteZone = _isPointerOverDeleteButton(event.position);
    ref.read(videoEditorProvider.notifier).setOverDeleteZone(isOverDeleteZone);

    return isLeavingClipArea || isOverDeleteZone;
  }

  /// Animates drag offset back to zero when entering delete zone.
  void _resetDragOffsetIfNeeded() {
    if (_reorderController.handleEnterDeleteZone() &&
        !_dragResetController.isAnimating) {
      unawaited(_dragResetController.forward(from: 0));
    }
  }

  /// Calculates the reorder threshold based on viewport and clip count.
  double _calculateReorderThreshold(double viewportWidth, int clipCount) {
    return _reorderController.calculateReorderThreshold(
      viewportWidth,
      clipCount,
    );
  }

  /// Applies the reorder to the new target index.
  void _applyReorderToIndex(int newTargetIndex) {
    _reorderController.updateTargetIndex(newTargetIndex);

    ref.read(videoEditorProvider.notifier).selectClipByIndex(newTargetIndex);
    unawaited(_navigateToClip(newTargetIndex));
    setState(() {});
  }

  /// Handles pointer movement during clip reorder mode.
  ///
  /// Updates the visual drag offset for rotation effect and triggers
  /// clip reordering when the accumulated drag exceeds the threshold.
  /// Also detects when the pointer is over the delete zone.
  Future<void> _handleReorderEvent(
    PointerMoveEvent event,
    BoxConstraints constraints,
  ) async {
    // Check delete zone and exit early if needed
    if (_updateDeleteZoneState(event, constraints)) {
      _resetDragOffsetIfNeeded();
      return;
    }

    // Update visual drag offset (for rotation effect)
    _reorderController.updateVisualDragOffset(
      event.delta.dx,
      constraints.maxWidth,
    );

    // Accumulate drag offset for page switching
    _reorderController.addDragOffset(event.delta.dx);

    // Check if threshold exceeded for page switch
    final clips = ref.read(clipManagerProvider).clips;
    final threshold = _calculateReorderThreshold(
      constraints.maxWidth,
      clips.length,
    );

    if (_reorderController.accumulatedDragOffset.abs() >= threshold) {
      final newTargetIndex = _reorderController.calculateNewTargetIndex(
        clips.length,
      );
      if (newTargetIndex != null &&
          newTargetIndex != _reorderController.targetIndex) {
        _applyReorderToIndex(newTargetIndex);
      }
    }
  }

  /// Completes or cancels the reorder operation.
  ///
  /// If the clip was released over the delete zone, it will be removed.
  /// Otherwise, the drag offset animates back to zero and reorder mode ends.
  Future<void> _handleReorderCancel() async {
    final isOverDeleteZone = ref.read(videoEditorProvider).isOverDeleteZone;
    final targetIndex = _reorderController.targetIndex;

    if (isOverDeleteZone) {
      // Delete the clip if released over delete zone
      final clips = ref.read(clipManagerProvider).clips;
      if (targetIndex >= 0 && targetIndex < clips.length) {
        final clipToDelete = clips[targetIndex];
        ref.read(clipManagerProvider.notifier).removeClipById(clipToDelete.id);

        if (ref.read(clipManagerProvider.notifier).clips.isEmpty) {
          context.pop();
          return;
        }

        // Update selected index after deletion
        final remainingClips = ref.read(clipManagerProvider).clips;
        final newIndex = _reorderController.calculateIndexAfterDeletion(
          remainingClips.length,
        );
        _reorderController.updateTargetIndex(newIndex);
        ref.read(videoEditorProvider.notifier).selectClipByIndex(newIndex);
      }
    }

    // Animate drag offset back to 0 and wait for completion
    _reorderController.prepareForDragReset();
    if (_reorderController.shouldAnimateReset) {
      await _dragResetController.forward(from: 0).orCancel;
    }
    _reorderController.completeReorder();

    ref
        .read(clipManagerProvider.notifier)
        .reorderClip(
          _reorderController.startIndex,
          _reorderController.updatedIndex,
        );

    // Exit reorder mode (after animation completes)
    ref.read(videoEditorProvider.notifier).stopClipReordering();

    Future.delayed(VideoEditorGalleryConstants.scaleAnimationDuration, () {
      if (mounted) _reorderController.disableTweenOffset();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));

    if (clips.isEmpty) {
      return const SizedBox.shrink();
    }

    return GalleryCallbacksScope(
      callbacks: GalleryCallbacks(
        onStartReordering: _handleStartReordering,
        onReorderCancel: _handleReorderCancel,
        onReorderEvent: _handleReorderEvent,
        onPageChanged: (page) {
          _lastClipIndex = page;
          ref.read(videoEditorProvider.notifier).selectClipByIndex(page);
        },
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: _GalleryViewer(
              pageController: _pageController,
              clips: clips,
              reorderController: _reorderController,
            ),
          ),
          const ClipGalleryInstructionText(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _GalleryViewer extends ConsumerWidget {
  const _GalleryViewer({
    required this.pageController,
    required this.clips,
    required this.reorderController,
  });

  final PageController pageController;
  final List<RecordingClip> clips;
  final ClipReorderController reorderController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callbacks = GalleryCallbacksScope.of(context);
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          currentClipIndex: s.currentClipIndex,
          isEditing: s.isEditing,
          isReordering: s.isReordering,
        ),
      ),
    );
    final currentClipIndex = state.isReordering
        ? reorderController.startIndex
        : state.currentClipIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerMove: state.isReordering
              ? (event) => callbacks.onReorderEvent(event, constraints)
              : null,
          onPointerUp: state.isReordering
              ? (_) => callbacks.onReorderCancel()
              : null,
          onPointerCancel: state.isReordering
              ? (_) => callbacks.onReorderCancel()
              : null,
          child: AnimatedBuilder(
            animation: pageController,
            builder: (context, child) {
              // Calculate common values once
              final page = !state.isReordering && pageController.hasClients
                  ? (pageController.page ?? currentClipIndex.toDouble())
                  : currentClipIndex.toDouble();
              final centerIndex = page.round();
              final difference = (centerIndex - page).abs();
              final showCenterOverlay =
                  difference <
                      VideoEditorGalleryConstants.centerOverlayThreshold &&
                  centerIndex < clips.length;
              final shadowOpacity = showCenterOverlay
                  ? 1.0 -
                        (difference /
                            VideoEditorGalleryConstants.centerOverlayThreshold)
                  : 0.0;

              return _GalleryStack(
                pageController: pageController,
                clips: clips,
                reorderController: reorderController,
                isEditing: state.isEditing,
                isReordering: state.isReordering,
                selectedClipIndex: state.currentClipIndex,
                activeClipIndex: state.isReordering
                    ? reorderController.startIndex
                    : centerIndex,
                constraints: constraints,
                page: page,
                showCenterOverlay: showCenterOverlay,
                shadowOpacity: shadowOpacity,
              );
            },
          ),
        );
      },
    );
  }
}

class _GalleryStack extends ConsumerStatefulWidget {
  const _GalleryStack({
    required this.pageController,
    required this.clips,
    required this.reorderController,
    required this.isEditing,
    required this.isReordering,
    required this.activeClipIndex,
    required this.selectedClipIndex,
    required this.constraints,
    required this.page,
    required this.showCenterOverlay,
    required this.shadowOpacity,
  });

  final PageController pageController;
  final ClipReorderController reorderController;
  final BoxConstraints constraints;

  final List<RecordingClip> clips;

  final int activeClipIndex;
  final int selectedClipIndex;

  final double page;
  final double shadowOpacity;

  final bool isEditing;
  final bool isReordering;
  final bool showCenterOverlay;

  @override
  ConsumerState<_GalleryStack> createState() => _GalleryStackState();
}

class _GalleryStackState extends ConsumerState<_GalleryStack> {
  Offset? _lastTapDownPosition;

  /// Calculator for scale and offset values.
  GalleryTransformCalculator get _calculator => GalleryTransformCalculator(
    pageController: widget.pageController,
    constraints: widget.constraints,
    clips: widget.clips,
    activeClipIndex: widget.activeClipIndex,
    selectedClipIndex: widget.selectedClipIndex,
    isReordering: widget.isReordering,
  );

  /// Handles tap on the gallery background to navigate between clips.
  ///
  /// This is necessary because [PageView] with `viewportFraction: 0.8` only
  /// registers gestures within the current page bounds, leaving the outer 20%
  /// on each side unresponsive. This handler captures taps in those dead zones.
  ///
  /// Tapping on the left half navigates to the previous clip,
  /// tapping on the right half navigates to the next clip.
  void _handleBackgroundTap() {
    final tapPosition = _lastTapDownPosition;
    if (tapPosition == null) return;

    final tappedLeft = tapPosition.dx < widget.constraints.maxWidth / 2;
    final newIndex = widget.selectedClipIndex + (tappedLeft ? -1 : 1);

    // Bounds check to prevent invalid index selection
    if (newIndex >= 0 && newIndex < widget.clips.length) {
      ref.read(videoEditorProvider.notifier).selectClipByIndex(newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageWidth =
        widget.constraints.maxWidth *
        VideoEditorGalleryConstants.viewportFraction;
    final contentScale = widget.isReordering
        ? VideoEditorGalleryConstants.reorderScale
        : 1.0;

    return Stack(
      clipBehavior: .none,
      children: [
        GestureDetector(
          behavior: .opaque,
          onTapDown: (details) => _lastTapDownPosition = details.localPosition,
          onTap: _handleBackgroundTap,
        ),

        AnimatedScale(
          scale: contentScale,
          duration: VideoEditorGalleryConstants.scaleAnimationDuration,
          curve: Curves.easeInOut,
          child: GalleryCalculationsScope(
            calculations: GalleryCalculations(
              calculateScale: _calculator.calculateScale,
              calculateXOffset: _calculator.calculateXOffset,
            ),
            child: VideoEditorGalleryPageView(
              page: widget.page,
              pageWidth: pageWidth,
              clips: widget.clips,
              reorderController: widget.reorderController,
              isEditing: widget.isEditing,
              isReordering: widget.isReordering,
              selectedClipIndex: widget.activeClipIndex,
              pageController: widget.pageController,
            ),
          ),
        ),

        // Gradient overlays on sides
        ClipGalleryEdgeGradients(
          opacity: widget.shadowOpacity,
          isReordering: widget.isReordering,
        ),

        // Center clip overlay which rendered on top,
        // which imitate a higher z-index.
        if (widget.showCenterOverlay)
          AnimatedScale(
            scale: contentScale,
            duration: VideoEditorGalleryConstants.scaleAnimationDuration,
            curve: Curves.easeInOut,
            child: VideoEditorCenterClipOverlay(
              clip: widget.clips[widget.activeClipIndex],
              currentClipIndex: widget.activeClipIndex,
              page: widget.page,
              shadowOpacity: widget.shadowOpacity,
              pageWidth: pageWidth,
              isReordering: widget.isReordering,
              dragOffsetNotifier: widget.reorderController.dragOffsetNotifier,
              scale: _calculator.calculateScale(widget.activeClipIndex),
              xOffset: _calculator.calculateXOffset(widget.activeClipIndex),
            ),
          ),
      ],
    );
  }
}

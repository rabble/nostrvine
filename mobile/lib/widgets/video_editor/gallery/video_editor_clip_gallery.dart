// ABOUTME: Horizontal scrolling clip selector with depth animations
// ABOUTME: PageView with scale, offset transforms and center overlay for z-ordering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_center_clip_overlay.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_edge_gradients.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_instruction_text.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_item.dart';

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
  late ScrollController _scrollController;
  late AnimationController _dragResetController;
  final _dragOffsetNotifier = ValueNotifier<double>(0);
  int _reorderTargetIndex = 0;
  double _accumulatedDragOffset = 0;
  double _dragResetStartValue = 0;
  int _lastClipIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
    _scrollController = ScrollController();
    _dragResetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(_onDragResetTick);

    // Listen to currentClipIndex changes
    ref.listenManual(
      videoEditorProvider.select((state) => state.currentClipIndex),
      (previous, next) {
        if (previous != next && next != _lastClipIndex) {
          _lastClipIndex = next;
          _navigateToClip(next);
        }
      },
    );
  }

  void _navigateToClip(int index) {
    final isReordering = ref.read(videoEditorProvider).isReordering;

    final duration = const Duration(milliseconds: 300);
    // Decelerate strongly at the end for a smooth landing effect
    final curve = Curves.easeOutCubic;

    if (isReordering && _scrollController.hasClients) {
      // In reorder mode, animate the scroll controller
      _scrollController.animateTo(
        index * MediaQuery.sizeOf(context).width * 0.8,
        duration: duration,
        curve: curve,
      );
    } else if (!isReordering && _pageController.hasClients) {
      // In swipe mode, animate the page controller
      _pageController.animateToPage(index, duration: duration, curve: curve);
    }
  }

  void _onDragResetTick() {
    final progress = Curves.easeOut.transform(_dragResetController.value);
    _dragOffsetNotifier.value = _dragResetStartValue * (1 - progress);
  }

  @override
  void dispose() {
    _dragResetController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  /// Performs a hit test to check if the pointer is over the delete button.
  bool _isPointerOverDeleteButton(Offset globalPosition) {
    final deleteButtonKey = ref.read(videoEditorProvider).deleteButtonKey;

    if (deleteButtonKey.currentContext == null) {
      return false;
    }

    final renderBox =
        deleteButtonKey.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return false;
    }

    // Convert global position to local coordinates
    final localPosition = renderBox.globalToLocal(globalPosition);

    // Check if the local position is within the bounds
    return renderBox.paintBounds.contains(localPosition);
  }

  Future<void> _handleReorderEvent(
    PointerMoveEvent event,
    BoxConstraints constraints,
  ) async {
    final isLeavingClipArea =
        event.localPosition.dy > constraints.maxHeight + 20;

    final clips = ref.read(clipManagerProvider).clips;
    // Perform hit test on delete button
    final isOverDeleteZone = _isPointerOverDeleteButton(event.position);
    ref.read(videoEditorProvider.notifier).setOverDeleteZone(isOverDeleteZone);

    // If over delete zone, animate drag offset back and skip reorder logic
    if (isLeavingClipArea || isOverDeleteZone) {
      if (_dragOffsetNotifier.value.abs() > 0.1 &&
          !_dragResetController.isAnimating) {
        _dragResetStartValue = _dragOffsetNotifier.value;
        _dragResetController.forward(from: 0);
      }
      _accumulatedDragOffset = 0;
      return;
    }

    // Update visual drag offset (for rotation effect)
    _dragOffsetNotifier.value = (_dragOffsetNotifier.value + event.delta.dx)
        .clamp(-constraints.maxWidth * 0.3, constraints.maxWidth * 0.3);

    // Accumulate drag offset for page switching
    _accumulatedDragOffset += event.delta.dx;

    // Calculate threshold: 10% of screen width per clip
    final threshold = (constraints.maxWidth * 0.8 / clips.length / 2).clamp(
      30,
      120,
    );

    // Check if we should switch pages
    if (_accumulatedDragOffset.abs() >= threshold) {
      var newTargetIndex = _reorderTargetIndex;

      if (_accumulatedDragOffset > 0 &&
          _reorderTargetIndex < clips.length - 1) {
        // Dragged right -> move to next clip (right)
        newTargetIndex = _reorderTargetIndex + 1;
      } else if (_accumulatedDragOffset < 0 && _reorderTargetIndex > 0) {
        // Dragged left -> move to previous clip (left)
        newTargetIndex = _reorderTargetIndex - 1;
      }

      if (newTargetIndex != _reorderTargetIndex) {
        // Reorder the clip in the manager
        ref
            .read(clipManagerProvider.notifier)
            .reorderClip(_reorderTargetIndex, newTargetIndex);

        _reorderTargetIndex = newTargetIndex;
        _accumulatedDragOffset = 0; // Reset accumulator

        // Update selected clip index to follow the clip
        ref
            .read(videoEditorProvider.notifier)
            .selectClipByIndex(newTargetIndex);

        // Scroll the SingleChildScrollView to the new position
        if (_scrollController.hasClients) {
          await _scrollController.animateTo(
            newTargetIndex * constraints.maxWidth * 0.8,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  Future<void> _handleReorderCancel() async {
    // Check if clip should be deleted
    final isOverDeleteZone = ref.read(videoEditorProvider).isOverDeleteZone;

    if (isOverDeleteZone) {
      // Delete the clip if released over delete zone
      final clips = ref.read(clipManagerProvider).clips;
      if (_reorderTargetIndex >= 0 && _reorderTargetIndex < clips.length) {
        final clipToDelete = clips[_reorderTargetIndex];
        ref.read(clipManagerProvider.notifier).removeClipById(clipToDelete.id);

        if (ref.read(clipManagerProvider.notifier).clips.isEmpty) {
          context.pop();
          return;
        }

        // Update selected index after deletion
        final remainingClips = ref.read(clipManagerProvider).clips;
        final newIndex = _reorderTargetIndex >= remainingClips.length
            ? remainingClips.length - 1
            : _reorderTargetIndex;
        _reorderTargetIndex = newIndex;
        ref.read(videoEditorProvider.notifier).selectClipByIndex(newIndex);
      }
    }

    // Animate drag offset back to 0 and wait for completion
    _dragResetStartValue = _dragOffsetNotifier.value;
    if (_dragResetStartValue.abs() > 0.1) {
      await _dragResetController.forward(from: 0).orCancel;
    }
    _dragOffsetNotifier.value = 0;
    _accumulatedDragOffset = 0;

    // Exit reorder mode (after animation completes)
    ref.read(videoEditorProvider.notifier).stopClipReordering();

    // Recreate the PageController with the new position and trigger rebuild
    setState(() {
      _pageController.dispose();
      _pageController = PageController(
        initialPage: _reorderTargetIndex,
        viewportFraction: 0.8,
      );
    });
  }

  void _startReordering() {
    final currentClipIndex = ref.read(videoEditorProvider).currentClipIndex;

    _reorderTargetIndex = currentClipIndex;
    _accumulatedDragOffset = 0;

    // Store the current PageView offset
    final currentOffset = _pageController.hasClients
        ? _pageController.offset
        : 0.0;

    // Switch to reorder mode
    ref.read(videoEditorProvider.notifier).startClipReordering();

    // Recreate ScrollController and trigger rebuild
    setState(() {
      _scrollController.dispose();
      _scrollController = ScrollController(initialScrollOffset: currentOffset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));

    if (clips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: .center,
      crossAxisAlignment: .stretch,
      children: [
        Flexible(
          child: _GalleryViewer(
            scrollController: _scrollController,
            pageController: _pageController,
            clips: clips,
            dragOffsetNotifier: _dragOffsetNotifier,
            onStartReordering: _startReordering,
            onReorderCancel: _handleReorderCancel,
            onReorderEvent: _handleReorderEvent,
            onPageChanged: (page) {
              _lastClipIndex = page;
              ref.read(videoEditorProvider.notifier).selectClipByIndex(page);
            },
          ),
        ),
        const ClipGalleryInstructionText(),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _GalleryViewer extends ConsumerWidget {
  const _GalleryViewer({
    required this.scrollController,
    required this.pageController,
    required this.clips,
    required this.onStartReordering,
    required this.onReorderCancel,
    required this.onPageChanged,
    required this.onReorderEvent,
    required this.dragOffsetNotifier,
  });

  final ScrollController scrollController;
  final PageController pageController;
  final List<RecordingClip> clips;
  final VoidCallback onStartReordering;
  final VoidCallback onReorderCancel;
  final ValueChanged<int> onPageChanged;
  final void Function(PointerMoveEvent event, BoxConstraints constraints)
  onReorderEvent;
  final ValueNotifier<double> dragOffsetNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          currentClipIndex: s.currentClipIndex,
          isEditing: s.isEditing,
          isReordering: s.isReordering,
          isOverDeleteZone: s.isOverDeleteZone,
        ),
      ),
    );
    final currentClipIndex = state.currentClipIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerMove: (event) async {
            if (state.isReordering) onReorderEvent(event, constraints);
          },
          onPointerUp: (event) async {
            if (state.isReordering) onReorderCancel();
          },
          onPointerCancel: (event) async {
            if (state.isReordering) onReorderCancel();
          },
          child: AnimatedBuilder(
            animation: pageController,
            builder: (context, child) {
              // Calculate common values once
              final hasClients =
                  pageController.hasClients &&
                  pageController.position.haveDimensions;
              final page = hasClients
                  ? (pageController.page ?? currentClipIndex.toDouble())
                  : currentClipIndex.toDouble();
              final centerIndex = page.round();
              final difference = (centerIndex - page).abs();
              final showCenterOverlay =
                  difference < 0.2 && centerIndex < clips.length;
              final shadowOpacity = showCenterOverlay
                  ? 1.0 - (difference / 0.2)
                  : 0.0;

              return _ScrollStack(
                scrollController: scrollController,
                pageController: pageController,
                clips: clips,
                isEditing: state.isEditing,
                currentClipIndex: currentClipIndex,
                constraints: constraints,
                page: page,
                centerIndex: centerIndex,
                showCenterOverlay: showCenterOverlay,
                shadowOpacity: shadowOpacity,
                dragOffsetNotifier: dragOffsetNotifier,
                onStartReordering: onStartReordering,
                onPageChanged: onPageChanged,
              );
            },
          ),
        );
      },
    );
  }
}

class _ScrollStack extends ConsumerStatefulWidget {
  const _ScrollStack({
    required this.scrollController,
    required this.pageController,
    required this.clips,
    required this.onPageChanged,
    required this.onStartReordering,
    required this.dragOffsetNotifier,
    required this.isEditing,
    required this.currentClipIndex,
    required this.constraints,
    required this.page,
    required this.centerIndex,
    required this.showCenterOverlay,
    required this.shadowOpacity,
  });

  final ScrollController scrollController;
  final PageController pageController;

  final ValueNotifier<double> dragOffsetNotifier;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onStartReordering;
  final BoxConstraints constraints;

  final List<RecordingClip> clips;

  final int currentClipIndex;
  final int centerIndex;

  final double page;
  final double shadowOpacity;

  final bool isEditing;
  final bool showCenterOverlay;

  @override
  ConsumerState<_ScrollStack> createState() => _ScrollStackState();
}

class _ScrollStackState extends ConsumerState<_ScrollStack> {
  Offset? _lastTapDownPosition;

  /// Calculates the scale factor for a clip based on its distance from center.
  ///
  /// Returns 1.0 for the centered clip and 0.85 for clips far from center,
  /// with linear interpolation in between.
  double _calculateScale(int index) {
    if (!widget.pageController.hasClients ||
        !widget.pageController.position.haveDimensions) {
      return index == widget.currentClipIndex ? 1 : 0.85;
    }

    final page =
        widget.pageController.page ?? widget.currentClipIndex.toDouble();
    final difference = (page - index).abs();
    // Scale from 1.0 (center) to 0.85 (far away)
    // difference 0.0 = scale 1.0
    // difference 1.0+ = scale 0.85
    const minScale = 0.85;
    const maxScale = 1;

    if (difference >= 1) {
      return minScale;
    }

    return maxScale - (difference * (maxScale - minScale));
  }

  /// Calculates the horizontal offset for a clip to create depth effect.
  double _calculateXOffset(int index) {
    // Get clip aspect ratio (e.g., 9/16 = 0.5625 for vertical, 1.0 for square)
    final clipRatio = widget.clips.first.aspectRatio.value;

    // Each clip sits in a container that is 80% of screen width
    final clipContainerWidth = widget.constraints.maxWidth * 0.8;

    // Calculate actual clip width: height * aspectRatio, clamped to container
    final actualClipWidth = (widget.constraints.maxHeight * clipRatio).clamp(
      0.0,
      clipContainerWidth,
    );

    // Empty space per side when clip doesn't fill container width
    final emptySpace = (clipContainerWidth - actualClipWidth);

    // Ratio of how much the clip fills the container (1.0 = full, less = smaller)
    final fillRatio = actualClipWidth / clipContainerWidth;

    // Base offset + extra offset to pull clips closer over the empty space
    final maxOffset = (widget.constraints.maxWidth * 0.2) + emptySpace;

    // During reordering, use fixed currentClipIndex (clips move discretely)
    // During normal swiping, use pageController for smooth animation
    final double page;
    if (widget.pageController.hasClients &&
        widget.pageController.position.haveDimensions) {
      page = widget.pageController.page ?? widget.currentClipIndex.toDouble();
    } else {
      page = widget.currentClipIndex.toDouble();
    }

    final difference = index - page;
    final absDifference = difference.abs();

    // Dynamic falloff values based on fillRatio
    final falloffRange = 0.25 * fillRatio;
    final falloffEnd = 1.0 + falloffRange;

    // Offset is 0 for clips beyond falloffEnd
    if (absDifference > falloffEnd) return 0;

    const offsetStart = 0.4;
    // X-Offset only applies from [offsetStart] to 1.0 distance
    // From 0.0 to [offsetStart]: no offset (clips wait)
    // From [offsetStart] to 1.0: offset increases to max
    // From 1.0 to falloffEnd: gradual falloff
    double effectStrength;
    if (absDifference < offsetStart) {
      // No offset until clip is almost at edge
      effectStrength = 0;
    } else if (absDifference <= 1.0) {
      // Remap [offsetStart, 1.0] to [0.0, 1.0]
      final remapped = (absDifference - offsetStart) / (1.0 - offsetStart);
      effectStrength = remapped * remapped * remapped;
    } else {
      // Gradual falloff: 1.0→0.0 over distance 1.0→falloffEnd
      final falloff = (falloffEnd - absDifference) / falloffRange;
      effectStrength = falloff;
    }

    final scaledEased = effectStrength * 0.8;
    return -(difference.sign * scaledEased * maxOffset);
  }

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
    final newIndex = widget.currentClipIndex + (tappedLeft ? -1 : 1);

    // Bounds check to prevent invalid index selection
    if (newIndex >= 0 && newIndex < widget.clips.length) {
      ref.read(videoEditorProvider.notifier).selectClipByIndex(newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          currentClipIndex: s.currentClipIndex,
          isEditing: s.isEditing,
          isReordering: s.isReordering,
          isOverDeleteZone: s.isOverDeleteZone,
        ),
      ),
    );

    return Stack(
      clipBehavior: .none,
      children: [
        GestureDetector(
          behavior: .opaque,
          onTapDown: (details) => _lastTapDownPosition = details.localPosition,
          onTap: _handleBackgroundTap,
        ),

        // Use different scroll widget based on reorder state
        if (state.isReordering)
          _ReorderingView(
            clips: widget.clips,
            isEditing: widget.isEditing,
            constraints: widget.constraints,
            currentClipIndex: widget.currentClipIndex,
            scrollController: widget.scrollController,
            onStartReordering: widget.onStartReordering,
            calculateScale: _calculateScale,
            calculateXOffset: _calculateXOffset,
          )
        else
          _SwipeView(
            page: widget.page,
            clips: widget.clips,
            isEditing: widget.isEditing,
            currentClipIndex: widget.currentClipIndex,
            pageController: widget.pageController,
            onStartReordering: widget.onStartReordering,
            onPageChanged: widget.onPageChanged,
            calculateScale: _calculateScale,
            calculateXOffset: _calculateXOffset,
          ),

        if (widget.showCenterOverlay) ...[
          // Center clip overlay which rendered on top,
          // which imitate a higher z-index.
          AnimatedScale(
            scale: state.isReordering ? 0.7 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: VideoEditorCenterClipOverlay(
              clip: widget.clips[widget.centerIndex],
              centerIndex: widget.centerIndex,
              currentClipIndex: widget.currentClipIndex,
              page: widget.page,
              shadowOpacity: widget.shadowOpacity,
              maxWidth: widget.constraints.maxWidth,
              isReordering: state.isReordering,
              isOverDeleteZone: state.isOverDeleteZone,
              dragOffsetNotifier: widget.dragOffsetNotifier,
              scale: _calculateScale(widget.centerIndex),
              xOffset: _calculateXOffset(widget.centerIndex),
            ),
          ),

          // Gradient overlays on sides
          ClipGalleryEdgeGradients(
            opacity: widget.shadowOpacity,
            gradientWidth: widget.constraints.maxWidth * 0.1,
          ),
        ],
      ],
    );
  }
}

// TODO(@hm21): Improve reorder animation which feels wrong.
class _ReorderingView extends ConsumerWidget {
  const _ReorderingView({
    required this.clips,
    required this.isEditing,
    required this.currentClipIndex,
    required this.constraints,
    required this.onStartReordering,
    required this.scrollController,
    required this.calculateScale,
    required this.calculateXOffset,
  });

  final List<RecordingClip> clips;
  final bool isEditing;
  final int currentClipIndex;
  final BoxConstraints constraints;
  final VoidCallback onStartReordering;
  final ScrollController scrollController;
  final double Function(int index) calculateScale;
  final double Function(int index) calculateXOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      controller: scrollController,
      scrollDirection: .horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: .symmetric(horizontal: constraints.maxWidth * 0.1),
        child: Row(
          children: List.generate(clips.length, (index) {
            final scale = calculateScale(index);
            final xOffset = calculateXOffset(index);

            return SizedBox(
              width: constraints.maxWidth * 0.8,
              child: VideoEditorGalleryItem(
                clip: clips[index],
                index: index,
                page: currentClipIndex.toDouble(),
                scale: scale,
                xOffset: xOffset,
                onTap: () {
                  final notifier = ref.read(videoEditorProvider.notifier);

                  if (index == currentClipIndex) {
                    notifier.toggleClipEditing();
                  } else {
                    notifier.selectClipByIndex(index);
                  }
                },
                onLongPress: index == currentClipIndex && !isEditing
                    ? onStartReordering
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SwipeView extends ConsumerWidget {
  const _SwipeView({
    required this.clips,
    required this.isEditing,
    required this.currentClipIndex,
    required this.page,
    required this.pageController,
    required this.onPageChanged,
    required this.onStartReordering,
    required this.calculateScale,
    required this.calculateXOffset,
  });

  final PageController pageController;
  final List<RecordingClip> clips;
  final bool isEditing;
  final int currentClipIndex;
  final double page;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onStartReordering;
  final double Function(int index) calculateScale;
  final double Function(int index) calculateXOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageView.builder(
      controller: pageController,
      onPageChanged: onPageChanged,
      hitTestBehavior: .translucent,
      physics: isEditing ? const NeverScrollableScrollPhysics() : null,
      itemCount: clips.length,
      itemBuilder: (context, index) {
        final scale = calculateScale(index);
        final xOffset = calculateXOffset(index);
        return VideoEditorGalleryItem(
          clip: clips[index],
          index: index,
          page: page,
          scale: scale,
          xOffset: xOffset,
          onTap: () async {
            final notifier = ref.read(videoEditorProvider.notifier);

            if (index == currentClipIndex) {
              notifier.toggleClipEditing();
            } else if (!isEditing) {
              notifier.selectClipByIndex(index);
            }
          },
          onLongPress: index == currentClipIndex && !isEditing
              ? onStartReordering
              : null,
        );
      },
    );
  }
}

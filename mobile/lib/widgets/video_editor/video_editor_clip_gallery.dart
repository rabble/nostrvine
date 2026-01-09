// ABOUTME: Horizontal scrolling clip selector with depth animations
// ABOUTME: PageView with scale, offset transforms and center overlay for z-ordering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_clip_preview.dart';

/// Horizontal scrolling clip selector with animated transitions.
class VideoEditorClipGallery extends ConsumerStatefulWidget {
  /// Creates a video editor clips widget.
  const VideoEditorClipGallery({super.key});

  @override
  ConsumerState<VideoEditorClipGallery> createState() =>
      _VideoEditorClipsState();
}

class _VideoEditorClipsState extends ConsumerState<VideoEditorClipGallery> {
  late PageController _pageController;
  late ScrollController _scrollController;
  final _dragOffsetNotifier = ValueNotifier<double>(0);
  int _reorderTargetIndex = 0;
  double _accumulatedDragOffset = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  /// Calculates the scale factor for a clip based on its distance from center.
  ///
  /// Returns 1.0 for the centered clip and 0.85 for clips far from center,
  /// with linear interpolation in between.
  double _calculateScale(int index, int currentClipIndex) {
    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) {
      return index == currentClipIndex ? 1 : 0.85;
    }

    final page = _pageController.page ?? currentClipIndex.toDouble();
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
  ///
  /// Uses cubic easing to make the effect stronger as clips approach center.
  /// The offset is calculated as a percentage of screen width (20% max).
  /// Calculates the horizontal offset for a clip to create depth effect.
  ///
  /// Uses cubic easing to make the effect stronger as clips approach center.
  /// The offset is calculated as a percentage of screen width (20% max).
  double _calculateXOffset(
    int index,
    int currentClipIndex,
    double screenWidth,
  ) {
    // Calculate maxOffset as percentage of screen width (10%)
    final maxOffset = screenWidth * 0.2;

    if (!_pageController.hasClients ||
        !_pageController.position.haveDimensions) {
      if (index < currentClipIndex) return maxOffset;
      if (index > currentClipIndex) return -maxOffset;
      return 0;
    }

    final page = _pageController.page ?? currentClipIndex.toDouble();
    final difference = index - page;
    final absDifference = difference.abs();

    // Offset is 0 for clips beyond distance 1.3
    if (absDifference > 1.3) return 0;

    // From 0.0 to 1.0: cubic easing, offset increases
    // From 1.0 to 1.3: gradual falloff, offset decreases to 0
    double effectStrength;
    if (absDifference <= 1.0) {
      // Cubic easing: 0.0→1.0
      effectStrength = absDifference * absDifference * absDifference;
    } else {
      // Gradual falloff: 1.0→0.0 over distance 1.0→1.3
      final falloff =
          (1.3 - absDifference) / 0.3; // 1.0 at distance 1.0, 0.0 at 1.3
      effectStrength = falloff;
    }

    final scaledEased = effectStrength * 0.8;
    return -(difference.sign * scaledEased * maxOffset);
  }

  Future<void> _handleReorderEvent(
    PointerMoveEvent event,
    BoxConstraints constraints,
  ) async {
    final clips = ref.read(clipManagerProvider).clips;

    // Check if pointer is over delete zone (bottom 80px of screen)
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isOverDeleteZone = event.position.dy > screenHeight - 100;
    ref.read(videoEditorProvider.notifier).setOverDeleteZone(isOverDeleteZone);

    // If over delete zone, reset drag offset and skip reorder logic
    if (isOverDeleteZone) {
      _dragOffsetNotifier.value = 0;
      _accumulatedDragOffset = 0;
      return;
    }

    // Update visual drag offset (for rotation effect)
    _dragOffsetNotifier.value = (_dragOffsetNotifier.value + event.delta.dx)
        .clamp(-constraints.maxWidth * 0.3, constraints.maxWidth * 0.3);

    // Accumulate drag offset for page switching
    _accumulatedDragOffset += event.delta.dx;

    // Calculate threshold: 10% of screen width per clip
    final threshold = constraints.maxWidth * 0.10;

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
        ref.read(videoEditorProvider.notifier).selectClip(newTargetIndex);

        // Scroll the SingleChildScrollView to the new position
        if (_scrollController.hasClients) {
          await _scrollController.animateTo(
            newTargetIndex * constraints.maxWidth * 0.8,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
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
        ref.read(clipManagerProvider.notifier).deleteClip(clipToDelete.id);

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
        ref.read(videoEditorProvider.notifier).selectClip(newIndex);
      }
    }

    // Animate drag offset back to 0
    final startOffset = _dragOffsetNotifier.value;
    if (startOffset.abs() > 0.1) {
      const steps = 10;
      const duration = Duration(milliseconds: 200);
      final stepDuration = duration ~/ steps;

      for (var i = 1; i <= steps; i++) {
        final progress = Curves.easeOut.transform(i / steps);
        _dragOffsetNotifier.value = startOffset * (1 - progress);
        await Future<void>.delayed(stepDuration);
        if (!mounted) return;
      }
    }

    _dragOffsetNotifier.value = 0;
    _accumulatedDragOffset = 0;

    // Exit reorder mode
    ref.read(videoEditorProvider.notifier).stopClipReordering();

    _pageController = PageController(
      initialPage: _reorderTargetIndex,
      viewportFraction: 0.8,
    );
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

    _scrollController = ScrollController(initialScrollOffset: currentOffset);
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));
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
    final isEditing = state.isEditing;
    final currentClipIndex = state.currentClipIndex;

    if (clips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: .center,
      crossAxisAlignment: .stretch,
      children: [
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Listener(
                onPointerMove: (event) async {
                  if (state.isReordering) {
                    await _handleReorderEvent(event, constraints);
                  }
                },
                onPointerUp: (event) async {
                  if (state.isReordering) await _handleReorderCancel();
                },
                onPointerCancel: (event) async {
                  if (state.isReordering) await _handleReorderCancel();
                },
                child: AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    // Calculate common values once
                    final hasClients =
                        _pageController.hasClients &&
                        _pageController.position.haveDimensions;
                    final page = hasClients
                        ? (_pageController.page ?? currentClipIndex.toDouble())
                        : currentClipIndex.toDouble();
                    final centerIndex = page.round();
                    final difference = (centerIndex - page).abs();
                    final showCenterOverlay =
                        difference < 0.2 && centerIndex < clips.length;
                    final shadowOpacity = showCenterOverlay
                        ? 1.0 - (difference / 0.2)
                        : 0.0;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Use different scroll widget based on reorder state
                        if (state.isReordering)
                          // SingleChildScrollView during reordering -
                          // no auto-snapping
                          SingleChildScrollView(
                            controller: _scrollController,
                            scrollDirection: .horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: constraints.maxWidth * 0.1,
                              ),
                              child: Row(
                                children: List.generate(
                                  clips.length,
                                  (index) => SizedBox(
                                    width: constraints.maxWidth * 0.8,
                                    child: _buildPageViewItem(
                                      clip: clips[index],
                                      index: index,
                                      isEditing: isEditing,
                                      currentClipIndex: currentClipIndex,
                                      page: currentClipIndex.toDouble(),
                                      screenWidth: constraints.maxWidth,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          // PageView for smooth snap scrolling in normal mode
                          PageView.builder(
                            controller: _pageController,
                            onPageChanged: (page) {
                              ref
                                  .read(videoEditorProvider.notifier)
                                  .selectClip(page);
                            },
                            itemCount: clips.length,
                            itemBuilder: (context, index) => _buildPageViewItem(
                              clip: clips[index],
                              index: index,
                              isEditing: isEditing,
                              currentClipIndex: currentClipIndex,
                              page: page,
                              screenWidth: constraints.maxWidth,
                            ),
                          ),

                        // Center clip overlay - rendered on top
                        if (showCenterOverlay)
                          _buildCenterOverlay(
                            clip: clips[centerIndex],
                            centerIndex: centerIndex,
                            currentClipIndex: currentClipIndex,
                            page: page,
                            shadowOpacity: shadowOpacity,
                            maxWidth: constraints.maxWidth,
                            isReordering: state.isReordering,
                            isOverDeleteZone: state.isOverDeleteZone,
                          ),

                        // Gradient overlays on sides
                        if (showCenterOverlay)
                          ..._buildGradientOverlays(
                            shadowOpacity,
                            constraints.maxWidth,
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
        _buildInstructionText(isEditing, state.isReordering),
        const SizedBox(height: 20),
      ],
    );
  }

  /// Builds the instruction text that appears below the clips.
  ///
  /// Uses AnimatedSwitcher with size and fade transitions.
  /// Hidden when editing is active.
  Widget _buildInstructionText(bool isEditing, bool isReordering) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: 1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: isEditing
          ? const SizedBox(width: .infinity)
          : AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isReordering ? 0 : 1,
              child: Align(
                child: Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Text(
                    'Tap to edit. Drag to reorder.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      height: 1.33,
                      letterSpacing: 0.4,
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    textAlign: .center,
                  ),
                ),
              ),
            ),
    );
  }

  /// Builds a single clip item for the PageView.
  ///
  /// Applies scale, offset transformations and opacity based on distance
  /// from center.
  /// Clips near center (< 0.2 distance) are faded out to be replaced by the
  /// overlay.
  Widget _buildPageViewItem({
    required RecordingClip clip,
    required int index,
    required bool isEditing,
    required int currentClipIndex,
    required double page,
    required double screenWidth,
  }) {
    final scale = _calculateScale(index, currentClipIndex);
    final xOffset = _calculateXOffset(index, currentClipIndex, screenWidth);
    final clipDifference = (index - page).abs();
    final opacity = (clipDifference / 0.2).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(xOffset, 0),
          child: Transform.scale(
            scale: scale,
            child: VideoClipPreview(
              key: ValueKey('Video-Clip-Preview-${clip.id}'),
              clip: clip,
              isCurrentClip: index == currentClipIndex,
              onTap: () async {
                if (index != currentClipIndex) {
                  await _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                  );
                } else {
                  ref.read(videoEditorProvider.notifier).toggleClipEditing();
                }
              },
              onLongPress: index == currentClipIndex && !isEditing
                  ? _startReordering
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the center clip overlay that appears on top of the PageView.
  ///
  /// This overlay ensures the centered clip renders **above** adjacent clips.
  /// Includes animated shadows that fade in as the clip approaches center.
  Widget _buildCenterOverlay({
    required RecordingClip clip,
    required int centerIndex,
    required int currentClipIndex,
    required double page,
    required double shadowOpacity,
    required double maxWidth,
    required bool isReordering,
    required bool isOverDeleteZone,
  }) {
    final pageViewOffset = -(page - centerIndex) * maxWidth * 0.8;
    final scale = _calculateScale(centerIndex, currentClipIndex);
    final xOffset = _calculateXOffset(centerIndex, currentClipIndex, maxWidth);

    return ValueListenableBuilder(
      valueListenable: _dragOffsetNotifier,
      builder: (_, dragOffset, _) {
        // Calculate rotation based on drag offset (-15° to +15°)
        final rotationAngle = (dragOffset / maxWidth) * 0.26; // ~15° in radians
        return RepaintBoundary(
          child: IgnorePointer(
            ignoring: !isReordering,
            child: Center(
              child: Transform.translate(
                offset: Offset(
                  xOffset + pageViewOffset + (isReordering ? dragOffset : 0),
                  0,
                ),
                child: Transform.rotate(
                  angle: isReordering ? rotationAngle : 0,
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: maxWidth * 0.8,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(
                                0,
                                0,
                                0,
                                0.32 * shadowOpacity,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 1),
                            ),
                            BoxShadow(
                              color: Color.fromRGBO(
                                0,
                                0,
                                0,
                                0.16 * shadowOpacity,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: VideoClipPreview(
                          key: ValueKey('Video-Clip-Preview-${clip.id}'),
                          clip: clip,
                          isCurrentClip: true,
                          isReordering: isReordering,
                          isDeletionZone: isOverDeleteZone,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds left and right gradient overlays that darken the edges.
  ///
  /// These gradients are only visible when a clip is near center,
  /// helping to focus attention on the centered clip.
  List<Widget> _buildGradientOverlays(double opacity, double screenWidth) {
    // Calculate gradient width as 10% of screen width
    final gradientWidth = screenWidth * 0.1;

    return [
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: gradientWidth,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: gradientWidth,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: .centerRight,
                  end: .centerLeft,
                  colors: [
                    Colors.black.withValues(alpha: 1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/controllers/clip_reorder_controller.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/extended_sliver_fill_viewport.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/scopes/gallery_calculations.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/scopes/gallery_callbacks.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/video_editor_gallery_item.dart';

/// Horizontally scrollable page view for video clip gallery items.
class VideoEditorGalleryPageView extends ConsumerStatefulWidget {
  const VideoEditorGalleryPageView({
    required this.isEditing,
    required this.isReordering,
    required this.selectedClipIndex,
    required this.page,
    required this.pageWidth,
    required this.clips,
    required this.pageController,
    required this.reorderController,
    super.key,
  });

  /// Whether a clip is currently being edited.
  final bool isEditing;

  /// Whether clips are being reordered via drag.
  final bool isReordering;

  /// Index of the currently selected clip.
  final int selectedClipIndex;

  /// Current fractional page position.
  final double page;

  /// Width of each page in pixels.
  final double pageWidth;

  /// List of clips to display.
  final List<RecordingClip> clips;

  /// Controller for page scrolling.
  final PageController pageController;

  /// Controller for reorder state and drag tracking.
  final ClipReorderController reorderController;

  @override
  ConsumerState<VideoEditorGalleryPageView> createState() => _PageViewState();
}

class _PageViewState extends ConsumerState<VideoEditorGalleryPageView> {
  int _lastReportedPage = 0;

  /// Returns axis direction based on text directionality.
  AxisDirection _getDirection(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final textDirection = Directionality.of(context);

    return textDirectionToAxisDirection(textDirection);
  }

  /// Calculates the horizontal offset for clips during reordering.
  ///
  /// Returns the offset to shift clips that need to make room for
  /// the dragged clip at its new position.
  double _calculateReorderOffset(int index) {
    if (!widget.isReordering || index == widget.selectedClipIndex) {
      return 0;
    }

    final selected = widget.selectedClipIndex;
    final target = widget.reorderController.updatedIndex;

    // Dragged right: shift clips in between to the left
    if (selected < target && index > selected && index <= target) {
      return -widget.pageWidth;
    }
    // Dragged left: shift clips in between to the right
    if (selected > target && index >= target && index < selected) {
      return widget.pageWidth;
    }

    return 0;
  }

  /// Toggles editing or selects clip on tap.
  void _handleItemTap(int index) {
    final notifier = ref.read(videoEditorProvider.notifier);

    if (index == widget.selectedClipIndex) {
      notifier.toggleClipEditing();
    } else if (!widget.isEditing) {
      notifier.selectClipByIndex(index);
    }
  }

  /// Whether clip at [index] can initiate reordering.
  bool _canStartReorder(int index) {
    return index == widget.selectedClipIndex && !widget.isEditing;
  }

  /// Tracks page changes during scrolling.
  bool _handleScrollNotification(ScrollNotification notification) {
    if (widget.isReordering) return false;

    if (notification.depth == 0 && notification is ScrollUpdateNotification) {
      final metrics = notification.metrics as PageMetrics;
      final currentPage = metrics.page!.round();
      if (currentPage != _lastReportedPage) {
        _lastReportedPage = currentPage;
        GalleryCallbacksScope.read(context).onPageChanged(currentPage);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final axisDirection = _getDirection(context);
    final physics = widget.isEditing || widget.isReordering
        ? const NeverScrollableScrollPhysics()
        : const PageScrollPhysics();

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Scrollable(
        axisDirection: axisDirection,
        controller: widget.pageController,
        physics: physics,
        hitTestBehavior: .translucent,
        scrollBehavior: ScrollConfiguration.of(
          context,
        ).copyWith(scrollbars: false),
        clipBehavior: Clip.none,
        viewportBuilder: (context, position) {
          return Viewport(
            cacheExtent: widget.isReordering ? 2 : 1,
            cacheExtentStyle: .viewport,
            axisDirection: axisDirection,
            offset: position,
            clipBehavior: .none,
            slivers: <Widget>[
              ExtendedSliverFillViewport(
                viewportFraction: VideoEditorGalleryConstants.viewportFraction,
                preloadPaintCount: widget.isReordering ? 2 : 0,
                delegate: SliverChildBuilderDelegate((context, index) {
                  final calculations = GalleryCalculationsScope.of(context);
                  final reorderCtrl = widget.reorderController;

                  final scale = calculations.calculateScale(index);
                  final targetXOffset = widget.isReordering
                      ? 0.0
                      : calculations.calculateXOffset(index);
                  final reorderOffset = _calculateReorderOffset(index);
                  final targetOffset = Offset(targetXOffset + reorderOffset, 0);

                  return _AnimatedGalleryItem(
                    clip: widget.clips[index],
                    index: index,
                    page: widget.page,
                    scale: scale,
                    targetOffset: targetOffset,
                    enableTweenOffset: reorderCtrl.enableTweenOffset,
                    canStartReorder: _canStartReorder(index),
                    onTap: () => _handleItemTap(index),
                  );
                }, childCount: widget.clips.length),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Gallery item with animated offset transitions.
class _AnimatedGalleryItem extends StatelessWidget {
  const _AnimatedGalleryItem({
    required this.clip,
    required this.index,
    required this.page,
    required this.scale,
    required this.targetOffset,
    required this.enableTweenOffset,
    required this.canStartReorder,
    required this.onTap,
  });

  final RecordingClip clip;

  final bool enableTweenOffset;
  final bool canStartReorder;

  final int index;

  final double page;
  final double scale;

  final Offset targetOffset;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final callbacks = GalleryCallbacksScope.read(context);

    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(end: targetOffset),
      duration: enableTweenOffset
          ? VideoEditorGalleryConstants.scaleAnimationDuration
          : .zero,
      curve: Curves.easeInOut,
      builder: (context, offset, child) {
        return VideoEditorGalleryItem(
          clip: clip,
          index: index,
          page: page,
          scale: scale,
          xOffset: offset.dx,
          onTap: onTap,
          onLongPress: canStartReorder ? callbacks.onStartReordering : null,
        );
      },
    );
  }
}

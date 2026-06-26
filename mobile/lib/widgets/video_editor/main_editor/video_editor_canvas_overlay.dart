// ABOUTME: Letterbox/scrim rendering for the video editor canvas: aspect-ratio
// ABOUTME: fitting, the dark cut-area bars, and the setup loading indicator.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/hit_test_expander.dart';
import 'package:openvine/widgets/video_editor/main_editor/scrim_zoom_transform.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';

/// Thumbnail-backed placeholder shown while the editor's video player is
/// still warming up, sized to the contain-fitted visible canvas area.
class VideoSetupLoadingIndicator extends StatelessWidget {
  /// Creates a [VideoSetupLoadingIndicator].
  const VideoSetupLoadingIndicator({
    required this.renderSize,
    required this.bodySize,
    required this.targetAspectRatio,
    super.key,
  });

  /// The editor's full render rect, in body coordinates.
  final Size renderSize;

  /// The size of the canvas body the editor is laid out in.
  final Size bodySize;

  /// The aspect ratio the finished video will be cropped to.
  final model.AspectRatio targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    // Contain mode: the visible area is targetAspectRatio fitted in renderSize
    final containSize = Size(
      renderSize.height * targetAspectRatio.value,
      renderSize.height,
    );
    final containRadius = Radius.circular(
      VideoEditorConstants.canvasRadius * containSize.width / bodySize.width,
    );

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.all(containRadius),
        child: SizedBox.fromSize(
          size: containSize,
          child: VideoEditorThumbnail(contentSize: containSize),
        ),
      ),
    );
  }
}

/// Fits the editor content to the first clip's aspect ratio, publishes the
/// resolved body size to [VideoEditorScope], and wraps the content in the
/// letterbox scrim and [HitTestExpander].
class CanvasFitter extends ConsumerWidget {
  /// Creates a [CanvasFitter].
  const CanvasFitter({required this.builder, super.key});

  /// Builds the editor content given the resolved `bodySize` and
  /// `renderSize` for the active clip.
  final Widget Function(Size bodySize, Size renderSize) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull),
    );
    if (clip == null) return const SizedBox.shrink();
    final scope = VideoEditorScope.of(context);

    return LayoutBuilder(
      builder: (_, constraints) {
        final bodySize = constraints.biggest;

        // Height is constrained by maxWidth or maxHeight,
        // depending on which dimension is reached first
        final height = min(bodySize.width, bodySize.height);
        final renderSize = Size(height * clip.originalAspectRatio, height);

        // Notify parent about body size
        scope.bodySizeNotifier.value = bodySize;

        // Contain mode: fit targetAspectRatio within bodySize,
        // then cover that area with the original aspect ratio
        final Size targetSize;
        if (bodySize.aspectRatio > clip.targetAspectRatio.value) {
          // Body is wider, height is limiting
          targetSize = Size(
            bodySize.height * clip.targetAspectRatio.value,
            bodySize.height,
          );
        } else {
          // Body is narrower, width is limiting
          targetSize = Size(
            bodySize.width,
            bodySize.width / clip.targetAspectRatio.value,
          );
        }

        // The visual chain below (Center > SizedBox > FittedBox >
        // SizedBox > Navigator) is unchanged — it owns the aspect-ratio
        // mapping (cover-fit [renderSize] into [targetSize], centered
        // in [bodySize]).
        //
        // [HitTestExpander] wraps it so that taps in the scrim /
        // letterbox zone (outside [targetSize]) are clamped to the
        // nearest point inside [targetSize] and re-dispatched into the
        // chain. Without this, `Center.hitTestChildren` drops every
        // pointer event that falls outside its child rect, so the
        // editor's top-level GestureDetector never opens an arena and
        // [onScaleStart] / [onScaleUpdate] never fire.
        return _OverlayCutArea(
          child: HitTestExpander(
            visibleSize: targetSize,
            child: Center(
              child: SizedBox.fromSize(
                size: targetSize,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox.fromSize(
                    size: renderSize,
                    child: Navigator(
                      clipBehavior: Clip.none,
                      onGenerateRoute: (_) => PageRouteBuilder(
                        pageBuilder: (_, _, _) => builder(bodySize, renderSize),
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
}

class _OverlayCutArea extends ConsumerWidget {
  const _OverlayCutArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAspectRatio = ref.watch(
      clipManagerProvider.select((s) => s.firstClipOrNull?.targetAspectRatio),
    );
    if (targetAspectRatio == null) return const SizedBox.shrink();

    final overlayColor = VineTheme.backgroundCamera.withAlpha(166);
    final safeArea = MediaQuery.paddingOf(context);
    final scope = VideoEditorScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.biggest;
        // Compute the visible child size: largest rect with
        // targetAspectRatio that fits inside boxSize (BoxFit.contain).
        final double childWidth;
        final double childHeight;
        if (boxSize.width / boxSize.height > targetAspectRatio.value) {
          childHeight = boxSize.height;
          childWidth = boxSize.height * targetAspectRatio.value;
        } else {
          childWidth = boxSize.width;
          childHeight = boxSize.width / targetAspectRatio.value;
        }
        final verticalGap = (boxSize.height - childHeight) / 2;
        final horizontalGap = (boxSize.width - childWidth) / 2;

        final scrimBars = _ScrimBars(
          overlayColor: overlayColor,
          verticalGap: verticalGap,
          horizontalGap: horizontalGap,
          safeAreaTop: safeArea.top,
        );

        return Stack(
          fit: StackFit.expand,
          clipBehavior: .none,
          children: [
            child,

            ValueListenableBuilder<Matrix4>(
              valueListenable: scope.zoomMatrixNotifier,
              builder: (context, matrix, child) => Transform(
                transform: scrimZoomTransform(
                  editorMatrix: matrix,
                  boxSize: boxSize,
                  targetSize: Size(childWidth, childHeight),
                  originalAspectRatio: scope.originalClipAspectRatio,
                ),
                child: child,
              ),
              child: scrimBars,
            ),
          ],
        );
      },
    );
  }
}

/// The dark letterbox bars that frame the visible target rect. The bars sit
/// outside the [verticalGap] / [horizontalGap] cut area and are non-
/// interactive; [_OverlayCutArea] applies the zoom transform around them.
class _ScrimBars extends StatelessWidget {
  const _ScrimBars({
    required this.overlayColor,
    required this.verticalGap,
    required this.horizontalGap,
    required this.safeAreaTop,
  });

  final Color overlayColor;
  final double verticalGap;
  final double horizontalGap;
  final double safeAreaTop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: .none,
        children: [
          // Top bar — extends up into the safe area so there is no
          // uncovered strip above the scrim when the canvas is padded
          // below the status bar.
          if (verticalGap > 0 || safeAreaTop > 0)
            Positioned(
              top: -safeAreaTop,
              left: 0,
              right: 0,
              height: verticalGap + safeAreaTop,
              child: ColoredBox(color: overlayColor),
            ),
          // Bottom bar
          if (verticalGap > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: verticalGap,
              child: ColoredBox(color: overlayColor),
            ),
          // Left bar
          if (horizontalGap > 0)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: horizontalGap,
              child: ColoredBox(color: overlayColor),
            ),
          // Right bar
          if (horizontalGap > 0)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: horizontalGap,
              child: ColoredBox(color: overlayColor),
            ),
        ],
      ),
    );
  }
}

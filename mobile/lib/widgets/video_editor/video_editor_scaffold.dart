import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_overlay_actions.dart';

import 'package:openvine/widgets/video_editor/main_editor/video_editor_remove_area.dart';

/// A scaffold widget that provides the standard layout for the video editor.
///
/// This widget arranges the video editor UI into three main sections:
/// - A main editor area that displays the video with proper aspect ratio
/// - Overlay controls positioned on top of the video
/// - A bottom bar for additional controls (e.g., timeline, tools)
class VideoEditorScaffold extends ConsumerWidget {
  /// Creates a [VideoEditorScaffold].
  const VideoEditorScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyle,
      child: Scaffold(
        backgroundColor: VineTheme.surfaceContainerHigh,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: .expand,
          clipBehavior: .none,
          children: [
            VideoEditorCanvas(),
            _OverlayControls(),
            _BottomActions(),
          ],
        ),
      ),
    );
  }
}

class _OverlayControls extends StatelessWidget {
  const _OverlayControls();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const .only(bottom: VideoEditorConstants.bottomBarHeight),
        child: BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
          buildWhen: (previous, current) =>
              previous.isLayerInteractionActive !=
                  current.isLayerInteractionActive ||
              previous.openSubEditor != current.openSubEditor,
          builder: (context, state) {
            final child = switch (state) {
              _ when state.isLayerInteractionActive => const SizedBox(),
              // Text-Editor
              VideoEditorMainState(openSubEditor: .text) =>
                const SizedBox.shrink(),
              // Draw-Editor
              VideoEditorMainState(openSubEditor: .draw) =>
                const VideoEditorDrawOverlayControls(
                  key: ValueKey('Draw-Overlay-Controls'),
                ),
              // Filter-Editor
              VideoEditorMainState(openSubEditor: .filter) =>
                const VideoEditorFilterOverlayControls(
                  key: ValueKey('Filter-Overlay-Controls'),
                ),
              // Fallback
              _ => const VideoEditorMainOverlayActions(),
            };

            return AnimatedSwitcher(
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: .expand,
                alignment: .center,
                children: <Widget>[...previousChildren, ?currentChild],
              ),
              duration: const Duration(milliseconds: 200),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Bottom section that switches between different toolbars based on context.
///
/// Shows [VideoEditorFilterBottomBar] when filter editor is open, hides the
/// bar during layer interaction, and falls back to [VideoEditorMainBottomBar].
class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: .bottomCenter,
      child: SafeArea(
        top: false,
        left: false,
        child: SizedBox(
          height:
              VideoEditorConstants.bottomBarHeight +
              VideoEditorConstants.canvasRadius,
          child: BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
            buildWhen: (previous, current) =>
                previous.isLayerInteractionActive !=
                    current.isLayerInteractionActive ||
                previous.openSubEditor != current.openSubEditor,
            builder: (context, state) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: state.isLayerInteractionActive
                    ? const VideoEditorRemoveArea()
                    : Column(
                        children: [
                          const _BottomCornerArcs(),
                          AnimatedSwitcher(
                            switchInCurve: Curves.easeInOut,
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    axisAlignment: -1,
                                    child: child,
                                  ),
                                ),
                            layoutBuilder: (currentChild, previousChildren) =>
                                Container(
                                  height: VideoEditorConstants.bottomBarHeight,
                                  color: VineTheme.surfaceContainerHigh,
                                  child: Stack(
                                    clipBehavior: .none,
                                    alignment: .bottomCenter,
                                    children: <Widget>[?currentChild],
                                  ),
                                ),
                            child: switch (state.openSubEditor) {
                              // Text-Bar (no bottom bar for text editor)
                              .text => const SizedBox(),
                              // Draw-Bar
                              .draw => const VideoEditorDrawBottomBar(
                                key: ValueKey('Draw-Editor-Bottom-Bar'),
                              ),
                              // Filter-Bar
                              .filter => const VideoEditorFilterBottomBar(
                                key: ValueKey('Filter-Editor-Bottom-Bar'),
                              ),
                              // Audio-Bar (no bottom bar, timing screen has its own)
                              .music => const SizedBox(),
                              // Main-Bar
                              _ => const VideoEditorMainBottomBar(),
                            },
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomCornerArcs extends StatelessWidget {
  const _BottomCornerArcs();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: .infinity,
      height: VideoEditorConstants.canvasRadius,
      child: CustomPaint(
        painter: _BottomCornerArcsPainter(
          arcRadius: VideoEditorConstants.canvasRadius,
          color: VineTheme.surfaceContainerHigh,
        ),
      ),
    );
  }
}

class _BottomCornerArcsPainter extends CustomPainter {
  _BottomCornerArcsPainter({
    required this.arcRadius,
    required this.color,
  });

  final double arcRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = .fill;

    final double radius = arcRadius.clamp(
      0.0,
      math.min(size.width / 2, size.height),
    );

    // Bottom-left: quarter-circle hole curving into the video area
    final leftPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(radius, size.height)
      ..arcTo(
        Rect.fromCircle(center: Offset(radius, 0), radius: radius),
        math.pi / 2, // start: bottom (radius, radius)
        math.pi / 2, // sweep CW toward (0, 0)
        false,
      )
      ..close();
    canvas.drawPath(leftPath, paint);

    // Bottom-right: quarter-circle hole curving into the video area
    final rightPath = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width - radius, size.height)
      ..arcTo(
        Rect.fromCircle(
          center: Offset(size.width - radius, 0),
          radius: radius,
        ),
        math.pi / 2, // start: bottom (width - radius, radius)
        -math.pi / 2, // sweep CCW toward (width, 0)
        false,
      )
      ..close();
    canvas.drawPath(rightPath, paint);
  }

  @override
  bool shouldRepaint(covariant _BottomCornerArcsPainter oldDelegate) =>
      oldDelegate.arcRadius != arcRadius || oldDelegate.color != color;
}

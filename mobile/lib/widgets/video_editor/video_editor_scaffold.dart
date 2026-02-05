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
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_top_bar.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyle,
      child: Scaffold(
        backgroundColor: VineTheme.surfaceContainerHigh,
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                clipBehavior: .none,
                fit: .expand,
                children: [const VideoEditorCanvas(), const _OverlayControls()],
              ),
            ),
            const _BottomActions(),
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
      child: BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
        buildWhen: (previous, current) =>
            previous.isLayerInteractionActive !=
                current.isLayerInteractionActive ||
            previous.openSubEditor != current.openSubEditor,
        builder: (context, state) {
          final child = switch (state) {
            _ when state.isLayerInteractionActive => const SizedBox(),
            // Text-Editor
            VideoEditorMainState(openSubEditor: SubEditorType.text) =>
              const SizedBox.shrink(),
            // Draw-Editor
            VideoEditorMainState(openSubEditor: SubEditorType.draw) =>
              const VideoEditorDrawOverlayControls(
                key: ValueKey('Draw-Overlay-Controls'),
              ),
            // Filter-Editor
            VideoEditorMainState(openSubEditor: SubEditorType.filter) =>
              const VideoEditorFilterOverlayControls(
                key: ValueKey('Filter-Overlay-Controls'),
              ),
            // Fallback
            _ => const VideoEditorMainTopBar(),
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
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
          buildWhen: (previous, current) =>
              previous.isLayerInteractionActive !=
                  current.isLayerInteractionActive ||
              previous.openSubEditor != current.openSubEditor,
          builder: (context, state) {
            final child = switch (state) {
              // TODO(@hm21) Implement Remove-Area
              _ when state.isLayerInteractionActive => const SizedBox(),
              // Text-Bar (no bottom bar for text editor)
              VideoEditorMainState(openSubEditor: .text) => const SizedBox(),
              // Draw-Bar
              VideoEditorMainState(openSubEditor: .draw) =>
                const VideoEditorDrawBottomBar(
                  key: ValueKey('Draw-Editor-Bottom-Bar'),
                ),
              // Filter-Bar
              VideoEditorMainState(openSubEditor: .filter) =>
                const VideoEditorFilterBottomBar(
                  key: ValueKey('Filter-Editor-Bottom-Bar'),
                ),
              // Main-Bar
              _ => const VideoEditorMainBottomBar(),
            };

            return AnimatedSwitcher(
              switchInCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                clipBehavior: .none,
                alignment: .bottomCenter,
                children: <Widget>[?currentChild],
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

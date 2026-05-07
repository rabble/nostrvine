import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_actions_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_overlay_actions.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline.dart';

/// A scaffold widget that provides the standard layout for the video editor.
///
/// Duration for the timeline ↔ bottom-actions switch animation.
const _switchDuration = Duration(milliseconds: 240);

/// This widget arranges the video editor UI into three main sections:
/// - A main editor area that displays the video with proper aspect ratio
/// - Overlay controls positioned on top of the video
/// - A bottom bar for additional controls (e.g., timeline, tools)
class VideoEditorScaffold extends StatelessWidget {
  /// Creates a [VideoEditorScaffold].
  const VideoEditorScaffold({required this.isLoading, super.key});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyle,
      child: Scaffold(
        backgroundColor: VineTheme.backgroundCamera,
        resizeToAvoidBottomInset: false,
        floatingActionButton: const _AddElementFab(),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                fit: .expand,
                clipBehavior: .none,
                children: [
                  if (isLoading)
                    const BrandedLoadingScaffold()
                  else
                    const VideoEditorCanvas(),

                  const _OverlayControls(),
                ],
              ),
            ),
            const _TimelineSection(),
          ],
        ),
      ),
    );
  }
}

class _TimelineSection extends StatefulWidget {
  const _TimelineSection();

  @override
  State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  static bool _shouldHide(SubEditorType? type) =>
      type == .draw || type == .filter;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _switchDuration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
      listenWhen: (prev, curr) =>
          _shouldHide(prev.openSubEditor) != _shouldHide(curr.openSubEditor),
      listener: (context, state) {
        if (_shouldHide(state.openSubEditor)) {
          _controller.forward();
        } else {
          _controller.reverse();
        }
      },
      child: ColoredBox(
        color: VineTheme.backgroundCamera,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            // Keep timeline always in tree to preserve thumbnail
            // cache. SizeTransition clips without unmounting.
            SizeTransition(
              sizeFactor: ReverseAnimation(_animation),
              axisAlignment: -1,
              child: const Padding(
                padding: .only(top: 12),
                child: VideoEditorTimelineScaffold(),
              ),
            ),
            SizeTransition(
              sizeFactor: _animation,
              axisAlignment: -1,
              child: const _BottomActions(),
            ),
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
    return BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
      buildWhen: (previous, current) =>
          previous.isLayerInteractionActive !=
              current.isLayerInteractionActive ||
          previous.openSubEditor != current.openSubEditor,
      builder: (context, state) => switch (state) {
        _ when state.isLayerInteractionActive => const SizedBox(),
        // Text-Editor
        VideoEditorMainState(openSubEditor: .text) => const SizedBox.shrink(),
        // Draw-Editor
        VideoEditorMainState(openSubEditor: .draw) => const Padding(
          key: ValueKey('Draw-Overlay-Controls'),
          padding: .only(bottom: VideoEditorConstants.bottomBarHeight),
          child: VideoEditorDrawOverlayControls(),
        ),
        // Filter-Editor
        VideoEditorMainState(openSubEditor: .filter) => const Padding(
          key: ValueKey('Filter-Overlay-Controls'),
          padding: .only(bottom: VideoEditorConstants.bottomBarHeight),
          child: VideoEditorFilterOverlayControls(),
        ),
        // Fallback
        _ => const VideoEditorMainOverlayActions(),
      },
    );
  }
}

/// Bottom section that switches between different toolbars based on context.
///
/// Only visible when a sub-editor is open. When no sub-editor is open the
/// timeline is shown instead (see [_TimelineSection]).
class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final systemNavigationBarHeight = MediaQuery.viewPaddingOf(context).bottom;
    final openSubEditor = context.select(
      (VideoEditorMainBloc b) => b.state.openSubEditor,
    );

    return SizedBox(
      height: systemNavigationBarHeight + VideoEditorConstants.bottomBarHeight,
      child: switch (openSubEditor) {
        // Draw-Bar
        SubEditorType.draw => const VideoEditorDrawBottomBar(
          key: ValueKey('Draw-Editor-Bottom-Bar'),
        ),
        // Filter-Bar
        SubEditorType.filter => Padding(
          padding: .only(bottom: systemNavigationBarHeight),
          child: const VideoEditorFilterBottomBar(
            key: ValueKey('Filter-Editor-Bottom-Bar'),
          ),
        ),
        // Fallback — should not happen since _BottomActions is only
        // rendered for draw/filter, but handle gracefully.
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// Decides whether the FAB should be visible. Keeps the visibility check in
/// a dedicated widget so that [_AddElementFabContent] is only rebuilt when
/// it actually needs to render — not on every hide/show state change.
class _AddElementFab extends StatelessWidget {
  const _AddElementFab();

  @override
  Widget build(BuildContext context) {
    final shouldHide = context.select(
      (VideoEditorMainBloc b) =>
          b.state.isSubEditorOpen || b.state.isTimelineHiddenByUser,
    );
    final hasSelectedOverlay = context.select(
      (TimelineOverlayBloc b) => b.state.selectedItemId != null,
    );
    final isClipEditing = context.select(
      (ClipEditorBloc b) => b.state.isEditing,
    );

    if (shouldHide || hasSelectedOverlay || isClipEditing) {
      return const SizedBox.shrink();
    }

    return const _AddElementFabContent();
  }
}

class _AddElementFabContent extends StatelessWidget {
  const _AddElementFabContent();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.videoEditorAddElementSemanticLabel,
      child: GestureDetector(
        onTap: () => VideoEditorMainActionsSheet.show(context),
        child: Container(
          width: 56,
          height: 56,
          decoration: ShapeDecoration(
            color: VineTheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 2, color: VineTheme.outlineMuted),
              borderRadius: .circular(24),
            ),
          ),
          child: const Center(
            child: DivineIcon(icon: .plus, color: VineTheme.primary),
          ),
        ),
      ),
    );
  }
}

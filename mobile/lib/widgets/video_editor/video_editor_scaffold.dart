import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
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
class VideoEditorScaffold extends ConsumerWidget {
  /// Creates a [VideoEditorScaffold].
  const VideoEditorScaffold({required this.isLoading, super.key});

  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyle,
      child: BlocSelector<VideoEditorMainBloc, VideoEditorMainState, bool>(
        selector: (state) => state.isSubEditorOpen,
        builder: (context, isSubEditorOpen) {
          return Scaffold(
            backgroundColor: VineTheme.surfaceContainerHigh,
            resizeToAvoidBottomInset: false,
            floatingActionButton: Semantics(
              label: 'Add element',
              child: isSubEditorOpen
                  ? const SizedBox.shrink()
                  : FloatingActionButton(
                      backgroundColor: VineTheme.primary,
                      onPressed: () =>
                          VideoEditorMainActionsSheet.show(context),
                      child: const DivineIcon(
                        icon: .plus,
                        color: VineTheme.onPrimary,
                      ),
                    ),
            ),

            body: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: .expand,
                    clipBehavior: .none,
                    children: [
                      if (isLoading)
                        const BrandedLoadingScaffold()
                      else ...[
                        const VideoEditorCanvas(),
                        BlocSelector<
                          VideoEditorMainBloc,
                          VideoEditorMainState,
                          ({bool isOver, bool isReordering})
                        >(
                          selector: (state) => (
                            isOver:
                                state.currentPosition.inMilliseconds >
                                VideoEditorConstants.maxDuration.inMilliseconds,
                            isReordering: state.isReordering,
                          ),
                          builder: (context, record) {
                            if (!record.isOver ||
                                record.isReordering ||
                                isSubEditorOpen) {
                              return const SizedBox.shrink();
                            }
                            return IgnorePointer(
                              child: ColoredBox(
                                color: VineTheme.backgroundColor.withAlpha(128),
                                child: const SizedBox.expand(),
                              ),
                            );
                          },
                        ),
                      ],
                      const _OverlayControls(),
                    ],
                  ),
                ),
                const _TimelineSection(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TimelineSection extends StatefulWidget {
  const _TimelineSection();

  @override
  State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection> {
  bool _hasTransitioned = false;
  bool? _lastHideTimeline;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      VideoEditorMainBloc,
      VideoEditorMainState,
      SubEditorType?
    >(
      selector: (state) => state.openSubEditor,
      builder: (context, openSubEditor) {
        final hideTimeline = openSubEditor == .draw || openSubEditor == .filter;

        // Enable animation only after the first actual transition.
        if (_lastHideTimeline != null && _lastHideTimeline != hideTimeline) {
          _hasTransitioned = true;
        }
        _lastHideTimeline = hideTimeline;

        return AnimatedSize(
          duration: _hasTransitioned ? _switchDuration : .zero,
          curve: Curves.easeInOut,
          alignment: .bottomCenter,
          child: Column(
            mainAxisSize: .min,
            children: [
              // Keep timeline always in tree to preserve thumbnail cache.
              // Offstage hides without unmounting.
              Offstage(
                offstage: hideTimeline,
                child: const Padding(
                  padding: .only(top: 12),
                  child: VideoEditorTimeline(),
                ),
              ),
              if (hideTimeline) const _BottomActions(),
            ],
          ),
        );
      },
    );
  }
}

class _OverlayControls extends StatelessWidget {
  const _OverlayControls();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(bottom: VideoEditorConstants.bottomBarHeight),
      child: BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
        buildWhen: (previous, current) =>
            previous.isLayerInteractionActive !=
                current.isLayerInteractionActive ||
            previous.openSubEditor != current.openSubEditor,
        builder: (context, state) => switch (state) {
          _ when state.isLayerInteractionActive => const SizedBox(),
          // Text-Editor
          VideoEditorMainState(openSubEditor: .text) => const SizedBox.shrink(),
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
        },
      ),
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
    return SizedBox(
      height: systemNavigationBarHeight + VideoEditorConstants.bottomBarHeight,
      child:
          BlocSelector<
            VideoEditorMainBloc,
            VideoEditorMainState,
            SubEditorType?
          >(
            selector: (state) => state.openSubEditor,
            builder: (context, openSubEditor) {
              return switch (openSubEditor) {
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
              };
            },
          ),
    );
  }
}

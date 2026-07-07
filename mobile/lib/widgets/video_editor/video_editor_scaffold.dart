import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_actions_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_overlay_actions.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_overlay_controls.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

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
        body: _SplitFailureListener(
          child: _ClipReverseResultListener(
            child: _ClipTransformResultListener(
              child: _ClipMergeResultListener(
                child: _ClipsRemovedResultListener(
                  child: _AudioExtractionResultListener(
                    child: _ScaffoldBody(isLoading: isLoading),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaffoldBody extends StatelessWidget {
  const _ScaffoldBody({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      clipBehavior: .none,
      children: [
        Column(
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

        const _ReverseProgressOverlay(),
        const _TransformProgressOverlay(),
        const _MergeProgressOverlay(),
      ],
    );
  }
}

/// Listens to [ClipEditorBloc.state.lastSplitFailure] and shows an error
/// snackbar when a split rendering operation fails.
///
/// Kept at the scaffold level (always mounted) so the snackbar fires even
/// if the timeline controls are hidden while the render is in flight.
class _SplitFailureListener extends StatelessWidget {
  const _SplitFailureListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastSplitFailure, curr.lastSplitFailure) &&
          curr.lastSplitFailure != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(context.l10n.videoEditorSplitFailed),
        );
      },
      child: child,
    );
  }
}

/// Listens to [ClipEditorBloc.state.lastReverseResult] and surfaces a
/// snackbar when a reverse-render operation fails or the clip has no local
/// file. Success is handled by the canvas player-sync listener; this listener
/// only covers the failure outcomes so they aren't silent to the user.
///
/// Kept at the scaffold level (always mounted) so the snackbar fires even
/// if the timeline controls are hidden while the render is in flight.
class _ClipReverseResultListener extends StatelessWidget {
  const _ClipReverseResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastReverseResult, curr.lastReverseResult) &&
          curr.lastReverseResult != null,
      listener: _onReverseResult,
      child: child,
    );
  }

  void _onReverseResult(BuildContext context, ClipEditorState state) {
    final result = state.lastReverseResult;
    if (result == null) return;

    switch (result) {
      case ClipReverseNoLocalFile():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorReverseNoLocalFile,
          ),
        );
      case ClipReverseFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorReverseFailed,
          ),
        );
      case ClipReverseDiscarded():
        // Source clip was removed during the async gap — there is no clip to
        // attach the reversed render to and no user action that warrants a
        // snackbar.
        break;
      case ClipReverseSuccess():
        // Player sync is handled by the canvas listener; nothing to do here.
        break;
    }
  }
}

/// Listens to [ClipEditorBloc.state.lastTransformResult] and surfaces a
/// snackbar when a transform-render operation fails or the clip has no local
/// file. Success is handled by the canvas player-sync listener that reacts to
/// the swapped clip file; this listener only covers the failure outcomes so
/// they aren't silent to the user.
///
/// Kept at the scaffold level (always mounted) so the snackbar fires even
/// if the timeline controls are hidden while the render is in flight.
class _ClipTransformResultListener extends StatelessWidget {
  const _ClipTransformResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastTransformResult, curr.lastTransformResult) &&
          curr.lastTransformResult != null,
      listener: _onTransformResult,
      child: child,
    );
  }

  void _onTransformResult(BuildContext context, ClipEditorState state) {
    final result = state.lastTransformResult;
    if (result == null) return;

    switch (result) {
      case ClipTransformNoLocalFile():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorTransformNoLocalFile,
          ),
        );
      case ClipTransformFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorTransformFailed,
          ),
        );
      case ClipTransformDiscarded():
        // Source clip was removed during the async gap — nothing to attach
        // the transformed render to and no user action that warrants a
        // snackbar.
        break;
      case ClipTransformSuccess():
        // Player sync is handled by the canvas listener; nothing to do here.
        break;
    }
  }
}

/// Listens to [ClipEditorBloc.state.lastMergeResult] and commits a successful
/// merge to editor history (replacing the selected clips with the merged clip,
/// with timeline markers rebased) or surfaces a snackbar on failure.
///
/// The bloc has already swapped the clip list by the time this fires; this
/// listener persists that change plus the rebased markers as one history entry
/// so undo/redo restores a consistent timeline. Kept at the scaffold level
/// (always mounted) so it survives the multi-select controls unmounting when
/// the bloc exits multi-select mode on success.
class _ClipMergeResultListener extends StatelessWidget {
  const _ClipMergeResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastMergeResult, curr.lastMergeResult) &&
          curr.lastMergeResult != null,
      listener: _onMergeResult,
      child: child,
    );
  }

  void _onMergeResult(BuildContext context, ClipEditorState state) {
    final result = state.lastMergeResult;
    if (result == null) return;

    switch (result) {
      case ClipMergeSuccess(:final previousClips):
        _commitMerge(context, state, previousClips);
      case ClipMergeFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(context.l10n.videoEditorMergeFailed),
        );
      case ClipMergeDiscarded():
        // A selected clip was removed during the async render — nothing to
        // commit and no user action that warrants a snackbar.
        break;
    }
  }

  void _commitMerge(
    BuildContext context,
    ClipEditorState state,
    List<DivineVideoClip> previousClips,
  ) {
    final editor = VideoEditorScope.of(context).requireEditor;
    final overlayBloc = context.read<TimelineOverlayBloc>();

    final rebasedMarkers = rebaseTimelineMarkersForClipState(
      oldClips: previousClips,
      newClips: state.clips,
      markers: overlayBloc.state.timelineMarkers,
    );

    overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
    editor.setClipState(state.clips, timelineMarkers: rebasedMarkers);
  }
}

/// Listens to [ClipEditorBloc.state.lastClipsRemovedResult] and commits a
/// multi-select removal to editor history (the new clip list with timeline
/// markers rebased).
///
/// The bloc owns the clip-list mutation; this listener only persists it. Kept
/// at the scaffold level (always mounted) so it survives the multi-select
/// controls unmounting when the bloc exits multi-select mode on removal.
class _ClipsRemovedResultListener extends StatelessWidget {
  const _ClipsRemovedResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(
            prev.lastClipsRemovedResult,
            curr.lastClipsRemovedResult,
          ) &&
          curr.lastClipsRemovedResult != null,
      listener: _onClipsRemoved,
      child: child,
    );
  }

  void _onClipsRemoved(BuildContext context, ClipEditorState state) {
    final result = state.lastClipsRemovedResult;
    if (result == null) return;

    final editor = VideoEditorScope.of(context).requireEditor;
    final overlayBloc = context.read<TimelineOverlayBloc>();

    final rebasedMarkers = rebaseTimelineMarkersForClipState(
      oldClips: result.previousClips,
      newClips: state.clips,
      markers: overlayBloc.state.timelineMarkers,
    );

    overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
    editor.setClipState(state.clips, timelineMarkers: rebasedMarkers);
  }
}

/// Listens to [ClipEditorBloc.state.lastAudioExtraction] from a widget that
/// stays mounted for the entire editor session, so the success/failure
/// side effect (history write or snackbar) survives the user leaving edit
/// mode, switching clips, or unmounting the timeline-level controls while
/// extraction is in flight.
class _AudioExtractionResultListener extends StatelessWidget {
  const _AudioExtractionResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastAudioExtraction, curr.lastAudioExtraction) &&
          curr.lastAudioExtraction != null,
      listener: _onAudioExtractionResult,
      child: child,
    );
  }

  void _onAudioExtractionResult(BuildContext context, ClipEditorState state) {
    final result = state.lastAudioExtraction;
    if (result == null) return;

    switch (result) {
      case ClipAudioExtractionNoLocalFile():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorExtractAudioNoLocalFile,
          ),
        );
      case ClipAudioExtractionDiscarded():
        // Source clip was removed during the async gap — nothing to
        // attach the extracted track to and no user action that
        // warrants a snackbar.
        break;
      case ClipAudioExtractionSuccess(:final audioEvent):
        _writeAudioExtractionHistory(context, state, audioEvent);
      case ClipAudioExtractionFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorExtractAudioFailed,
          ),
        );
    }
  }

  void _writeAudioExtractionHistory(
    BuildContext context,
    ClipEditorState state,
    AudioEvent audioEvent,
  ) {
    final editor = VideoEditorScope.of(context).requireEditor;

    // state.clips already reflects the muted clip applied by the bloc;
    // combine with the new audio track for a single atomic history entry
    // so undo/redo reverts both the mute and the added track together.
    final updatedTracks = [...editor.stateManager.audioTracks, audioEvent];
    editor.setClipAndAudioState(clips: state.clips, audioTracks: updatedTracks);
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
      type == .draw || type == .filter || type == .tune;

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
              alignment: AlignmentDirectional.topStart,
              child: const Padding(
                padding: .only(top: 12),
                child: VideoEditorTimelineScaffold(),
              ),
            ),
            SizeTransition(
              sizeFactor: _animation,
              alignment: AlignmentDirectional.topStart,
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
        // Tune-Editor
        VideoEditorMainState(openSubEditor: .tune) => const Padding(
          key: ValueKey('Tune-Overlay-Controls'),
          padding: .only(bottom: VideoEditorConstants.bottomBarHeight),
          child: VideoEditorTuneOverlayControls(),
        ),
        // Fallback
        _ => const VideoEditorMainOverlayActions(),
      },
    );
  }
}

class _ReverseProgressOverlay extends StatelessWidget {
  const _ReverseProgressOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ClipEditorBloc,
      ClipEditorState,
      ({bool isReversing, String? renderId})
    >(
      selector: (state) => (
        isReversing: state.isReversing,
        renderId: state.reversingClipId,
      ),
      builder: (context, reverseState) {
        if (!reverseState.isReversing || reverseState.renderId == null) {
          return const SizedBox.shrink();
        }

        return ColoredBox(
          color: VineTheme.backgroundColor.withAlpha(210),
          child: Center(
            child: RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 24,
                children: [
                  // Transient render progress is read straight from the
                  // plugin stream (no service indirection) since it is purely
                  // ephemeral UI feedback that never outlives this overlay.
                  StreamBuilder<ProgressModel>(
                    stream: ProVideoEditor.instance.progressStreamById(
                      reverseState.renderId!,
                    ),
                    builder: (context, snapshot) {
                      final progress = snapshot.data?.progress ?? 0;
                      return PartialCircleSpinner(progress: progress);
                    },
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      context.l10n.videoEditorReverseProgressLabel,
                      textAlign: TextAlign.center,
                      style: VineTheme.bodyMediumFont(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen progress overlay shown while a transform (crop/rotate/flip) is
/// re-rendered into a new clip file. Absorbs input for the duration so the
/// timeline controls underneath can't start a competing edit (reverse, delete,
/// split) mid-render, and fades in/out via [AnimatedSwitcher] so it doesn't pop
/// on/off abruptly.
class _TransformProgressOverlay extends StatelessWidget {
  const _TransformProgressOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ClipEditorBloc,
      ClipEditorState,
      ({bool isTransforming, String? renderId})
    >(
      selector: (state) => (
        isTransforming: state.isTransforming,
        renderId: state.transformingClipId,
      ),
      builder: (context, transformState) {
        final renderId = transformState.isTransforming
            ? transformState.renderId
            : null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: renderId == null
              ? const SizedBox.shrink()
              : _TransformProgressContent(renderId: renderId),
        );
      },
    );
  }
}

class _TransformProgressContent extends StatelessWidget {
  const _TransformProgressContent({required this.renderId});

  final String renderId;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: VineTheme.backgroundColor.withAlpha(210),
        child: Center(
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 24,
              children: [
                StreamBuilder<ProgressModel>(
                  stream: ProVideoEditor.instance.progressStreamById(renderId),
                  builder: (context, snapshot) {
                    final progress = snapshot.data?.progress ?? 0;
                    return PartialCircleSpinner(progress: progress);
                  },
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    context.l10n.videoEditorTransformProgressLabel,
                    textAlign: TextAlign.center,
                    style: VineTheme.bodyMediumFont(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen progress overlay shown while the selected clips are concatenated
/// into a single new clip file. Absorbs input for the duration so the timeline
/// controls underneath can't start a competing edit mid-render, and fades
/// in/out via [AnimatedSwitcher].
class _MergeProgressOverlay extends StatelessWidget {
  const _MergeProgressOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ClipEditorBloc,
      ClipEditorState,
      ({bool isMerging, String? renderId})
    >(
      selector: (state) => (
        isMerging: state.isMerging,
        renderId: state.mergingRenderId,
      ),
      builder: (context, mergeState) {
        final renderId = mergeState.isMerging ? mergeState.renderId : null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: renderId == null
              ? const SizedBox.shrink()
              : _MergeProgressContent(renderId: renderId),
        );
      },
    );
  }
}

class _MergeProgressContent extends StatelessWidget {
  const _MergeProgressContent({required this.renderId});

  final String renderId;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: VineTheme.backgroundColor.withAlpha(210),
        child: Center(
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 24,
              children: [
                StreamBuilder<ProgressModel>(
                  stream: ProVideoEditor.instance.progressStreamById(renderId),
                  builder: (context, snapshot) {
                    final progress = snapshot.data?.progress ?? 0;
                    return PartialCircleSpinner(progress: progress);
                  },
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    context.l10n.videoEditorMergeProgressLabel,
                    textAlign: TextAlign.center,
                    style: VineTheme.bodyMediumFont(),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        // Tune-Bar
        SubEditorType.tune => Padding(
          padding: .only(bottom: systemNavigationBarHeight),
          child: const VideoEditorTuneBottomBar(
            key: ValueKey('Tune-Editor-Bottom-Bar'),
          ),
        ),
        // Fallback — should not happen since _BottomActions is only
        // rendered for draw/filter/tune, but handle gracefully.
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
          b.state.isSubEditorOpen ||
          b.state.isTimelineHiddenByUser ||
          b.state.isMarkerMode,
    );
    final isOverlayInteracting = context.select(
      (TimelineOverlayBloc b) =>
          b.state.selectedItemId != null || b.state.isLayerMultiSelectMode,
    );
    final isClipInteracting = context.select(
      (ClipEditorBloc b) => b.state.isEditing || b.state.isMultiSelectMode,
    );

    if (shouldHide || isOverlayInteracting || isClipInteracting) {
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

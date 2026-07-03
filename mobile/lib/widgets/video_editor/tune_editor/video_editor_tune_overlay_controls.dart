// ABOUTME: Overlay controls for the video editor tune adjustments.
// ABOUTME: Contains the top close/done toolbar over the video preview.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Overlay controls for the tune editor.
///
/// Shows the shared close/done toolbar over the video preview and forwards a
/// tap on the preview area to a play/pause toggle (the tune sub-editor doesn't
/// forward `onTap`).
class VideoEditorTuneOverlayControls extends StatelessWidget {
  const VideoEditorTuneOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.read<VideoEditorMainBloc>().add(
            const VideoEditorPlaybackToggleRequested(),
          ),
        ),
        const _TopBarContent(),
      ],
    );
  }
}

class _TopBarContent extends StatelessWidget {
  const _TopBarContent();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<VideoEditorTuneBloc>();
    final scope = VideoEditorScope.of(context);

    return Align(
      alignment: .topCenter,
      child: VideoEditorToolbar(
        onClose: () {
          bloc.add(const VideoEditorTuneCancelled());
          scope.tuneEditor?.close();
        },
        onDone: () => _commit(bloc, scope),
      ),
    );
  }

  /// Commits this session's non-neutral adjustments as a new timeline *set*.
  ///
  /// Each Adjust session bundles the adjustments the user changed into one set
  /// — grouped by [VideoEditorConstants.tuneSetIdMetaKey] and rendered as a
  /// single timeline bar sharing one time window — and appends it to any
  /// existing sets. Members get a unique per-instance id (so multiple sets, or
  /// multiple segments of the same kind, coexist) with the preset kind recorded
  /// in [VideoEditorConstants.tuneKindMetaKey].
  ///
  /// The editor's own `done()` (via `openTuneEditor`) instead appends its full
  /// returned matrix to `activeTuneAdjustments`, which both doubles adjustments
  /// on re-open and can't express sets. We discard that with `close()` and
  /// write our own history entry via the main editor's `addHistory` (the same
  /// public API the timeline/filter paths already use).
  void _commit(VideoEditorTuneBloc bloc, VideoEditorScope scope) {
    final editorMatrix = scope.tuneEditor?.tuneAdjustmentMatrix;
    bloc.add(const VideoEditorTuneConfirmed());
    scope.tuneEditor?.close();
    if (editorMatrix == null) return;

    final setId = 'set_${DateTime.now().microsecondsSinceEpoch}';
    final newSet = [
      for (final m in editorMatrix)
        if (m.value != 0)
          m.copyWith(
            id: '${m.id}__$setId',
            meta: {
              VideoEditorConstants.tuneSetIdMetaKey: setId,
              VideoEditorConstants.tuneKindMetaKey: m.id,
            },
          ),
    ];
    if (newSet.isEmpty) return;

    final existing =
        scope.editor?.stateManager.activeTuneAdjustments ??
        const <TuneAdjustmentMatrix>[];
    scope.editor?.addHistory(
      tuneAdjustments: [...existing.map((m) => m.copy()), ...newSet],
    );
  }
}

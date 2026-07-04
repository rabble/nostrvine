// ABOUTME: Pure helpers for retiming and previewing tune adjustment sets.
// ABOUTME: Extracted from the timeline/canvas wiring so they stay unit-testable.

import 'package:openvine/extensions/tune_adjustment_matrix_extensions.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Applies [startTime]/[endTime] to every tune adjustment in the set [setId].
///
/// One Adjust session's adjustments share a set id (via
/// `VideoEditorConstants.tuneSetIdMetaKey`) and one timeline window, so a
/// timeline trim/move/reorder must retime every member of the set.
void retimeTuneSet(
  ProImageEditorState editor, {
  required String setId,
  required Duration startTime,
  required Duration endTime,
}) {
  final tunes = editor.stateManager.activeTuneAdjustments;
  for (var i = 0; i < tunes.length; i++) {
    if (tunes[i].tuneSetId != setId) continue;
    editor.setTuneTimeline(
      index: i,
      startTime: startTime,
      endTime: endTime,
      skipUpdateHistory: true,
    );
  }
}

/// Seeds [tuneEditor]'s live preview with the edited set's values via its
/// public `onChanged` API.
///
/// The editor seeds itself neutral because set members carry unique
/// per-instance ids rather than preset ids, so each stored member ([active]
/// filtered to [setId]) is replayed by selecting its preset kind and pushing
/// the value through `onChanged`. The selection is reset to 0 afterwards so the
/// bar opens on the first adjustment.
void seedTuneEditorPreview({
  required TuneEditorState tuneEditor,
  required List<TuneAdjustmentMatrix> active,
  required String setId,
}) {
  for (final m in active) {
    if (m.tuneSetId != setId) continue;
    final idx = tuneEditor.tuneAdjustmentList.indexWhere(
      (t) => t.id == m.tuneKind,
    );
    if (idx < 0) continue;
    tuneEditor
      ..selectedIndex = idx
      ..onChanged(m.value);
  }
  tuneEditor.selectedIndex = 0;
}

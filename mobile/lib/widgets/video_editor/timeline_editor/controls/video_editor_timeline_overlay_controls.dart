import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_image_editor/features/filter_editor/types/filter_state.dart';

/// Controls shown when an overlay item is selected.
/// Adapts buttons based on the overlay type (layer vs filter).
class TimelineOverlayControls extends StatelessWidget {
  const TimelineOverlayControls({required this.item, super.key});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item.type) {
      .sound => _SoundOverlayControls(item: item),
      .filter => _FilterOverlayControls(item: item),
      .layer => _LayerOverlayControls(item: item),
    };
  }

  static void _deselect(BuildContext context) {
    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }
}

/// Controls for layer overlays (text, drawing, emoji, sticker).
/// Text layers get an Edit button; all layers support delete, duplicate,
/// split, and done.
class _LayerOverlayControls extends StatelessWidget {
  const _LayerOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

    final layer = scope.editor?.activeLayers
        .where((l) => l.id == item.id)
        .firstOrNull;
    final isTextLayer = layer is TextLayer;

    return VideoEditorTimelineControls(
      onDelete: () => _removeLayer(context: context, layer: layer),
      onEdit: isTextLayer
          ? () => _editTextLayer(context: context, layer: layer)
          : null,
      onDuplicated: () => _duplicateLayer(context: context, layer: layer),
      onSplit: () => _splitLayer(context: context, layer: layer),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  void _removeLayer({required BuildContext context, Layer? layer}) {
    // Remove from the ProImageEditor active layers.
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    if (editor != null && layer != null) {
      editor.removeLayer(layer);
    }
  }

  Future<void> _editTextLayer({
    required BuildContext context,
    required TextLayer layer,
  }) async {
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    if (editor == null) return;
    final originalLayer = layer;

    final updatedLayer = await scope.onAddEditTextLayer(originalLayer);
    if (updatedLayer == null) return;

    editor.applyTextLayerChanges(layer, updatedLayer);
  }

  void _duplicateLayer({required BuildContext context, Layer? layer}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null || layer == null) return;

    final layers = List<Layer>.from(editor.activeLayers);
    final layerIdx = layers.indexWhere((l) => l.id == item.id);
    if (layerIdx < 0) return;

    final copy = layer.copyWith(
      id: _copyId(layer.id),
      offset: layer.offset + const Offset(24, 24),
    );

    layers.insert(layerIdx + 1, copy);
    editor.addHistory(layers: layers);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(copy.id),
    );
  }

  void _splitLayer({required BuildContext context, Layer? layer}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null || layer == null) return;

    final splitAt = _validSplitPosition(context, item);
    if (splitAt == null) return;

    final layers = List<Layer>.from(editor.activeLayers);
    final layerIdx = layers.indexWhere((l) => l.id == item.id);
    if (layerIdx < 0) return;

    final second = layer.copyWith(
      id: _copyId(layer.id),
      startTime: splitAt,
      endTime: item.endTime,
    );

    layers[layerIdx] = layer.copyWith(endTime: splitAt);
    layers.insert(layerIdx + 1, second);
    editor.addHistory(layers: layers);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(second.id),
    );
  }
}

/// Controls for filter overlays: delete, duplicate, split, and done.
class _FilterOverlayControls extends StatelessWidget {
  const _FilterOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return VideoEditorTimelineControls(
      onDelete: () => _removeFilter(context: context),
      onDuplicated: () => _duplicateFilter(context: context),
      onSplit: () => _splitFilter(context: context),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  void _removeFilter({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final filters = editor.stateManager.activeFilters;
    final updatedFilters = filters
        .where((t) => t.id != item.id)
        .map((e) => e.copy())
        .toList();

    editor.addHistory(filters: updatedFilters);

    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }

  void _duplicateFilter({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final filters = List<FilterState>.from(editor.stateManager.activeFilters);
    final filterIdx = filters.indexWhere((t) => t.id == item.id);
    if (filterIdx < 0) return;

    final copy = filters[filterIdx].copyWith(id: _copyId(item.id));
    filters.insert(filterIdx + 1, copy);
    editor.addHistory(filters: filters);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(copy.id),
    );
  }

  void _splitFilter({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final splitAt = _validSplitPosition(context, item);
    if (splitAt == null) return;

    final filters = List<FilterState>.from(editor.stateManager.activeFilters);
    final filterIdx = filters.indexWhere((t) => t.id == item.id);
    if (filterIdx < 0) return;

    final filter = filters[filterIdx];
    final second = filter.copyWith(
      id: _copyId(item.id),
      startTime: splitAt,
      endTime: item.endTime,
    );

    filters[filterIdx] = filter.copyWith(endTime: splitAt);
    filters.insert(filterIdx + 1, second);
    editor.addHistory(filters: filters);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(second.id),
    );
  }
}

/// Controls for sound overlays: delete, edit, duplicate, split, and done.
class _SoundOverlayControls extends StatelessWidget {
  const _SoundOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return VideoEditorTimelineControls(
      onDelete: () => _removeSound(context: context),
      onEdit: () => _editSound(context: context),
      onDuplicated: () => _duplicateSound(context: context),
      onSplit: () => _splitSound(context: context),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  Future<void> _editSound({required BuildContext context}) async {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final tracks = editor.stateManager.audioTracks;
    final sound = tracks.where((t) => t.id == item.id).firstOrNull;
    if (sound == null) return;

    final timingResult = await Navigator.of(context).push<AudioTimingResult>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: VineTheme.transparent,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (_, _, _) => VideoAudioEditorTimingScreen(sound: sound),
      ),
    );
    if (timingResult == null || !context.mounted) return;

    switch (timingResult) {
      case AudioTimingConfirmed(:final sound):
        final updatedTracks = tracks
            .map((t) => t.id == item.id ? sound : t)
            .map((e) => e.toJson())
            .toList();
        editor.addHistory(
          meta: {
            ...editor.stateManager.activeMeta,
            VideoEditorConstants.audioStateHistoryKey: updatedTracks,
          },
        );
      case AudioTimingDeleted():
        _removeSound(context: context);
    }
  }

  void _removeSound({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final tracks = editor.stateManager.audioTracks;
    final updatedTracks = tracks
        .where((t) => t.id != item.id)
        .map((e) => e.toJson())
        .toList();

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: updatedTracks,
      },
    );

    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }

  void _duplicateSound({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final tracks = editor.stateManager.audioTracks;
    final trackIdx = tracks.indexWhere((t) => t.id == item.id);
    if (trackIdx < 0) return;

    final copy = tracks[trackIdx].copyWith(id: _copyId(item.id));
    final updatedTracks = List.of(tracks)..insert(trackIdx + 1, copy);

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: updatedTracks
            .map((e) => e.toJson())
            .toList(),
      },
    );
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(copy.id),
    );
  }

  void _splitSound({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final splitAt = _validSplitPosition(context, item);
    if (splitAt == null) return;

    final tracks = editor.stateManager.audioTracks;
    final trackIdx = tracks.indexWhere((t) => t.id == item.id);
    if (trackIdx < 0) return;

    final track = tracks[trackIdx];
    final offsetShift = splitAt - item.startTime;
    final second = track.copyWith(
      id: _copyId(item.id),
      startOffset: track.startOffset + offsetShift,
      startTime: splitAt,
      endTime: item.endTime,
    );

    final updatedTracks = List.of(tracks)
      ..[trackIdx] = track.copyWith(endTime: splitAt)
      ..insert(trackIdx + 1, second);

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: updatedTracks
            .map((e) => e.toJson())
            .toList(),
      },
    );
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(second.id),
    );
  }
}

String _copyId(String id) =>
    '${id}_copy_${DateTime.now().microsecondsSinceEpoch}';

Duration? _validSplitPosition(BuildContext context, TimelineOverlayItem item) {
  final splitAt = context.read<VideoEditorMainBloc>().state.currentPosition;
  if (splitAt <= item.startTime || splitAt >= item.endTime) {
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.videoEditorSplitPlayheadOutsideClip,
      ),
    );
    return null;
  }

  return splitAt;
}

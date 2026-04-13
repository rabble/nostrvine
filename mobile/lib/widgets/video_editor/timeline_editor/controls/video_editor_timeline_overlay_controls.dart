import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_image_editor/features/filter_editor/types/filter_state.dart';

/// Controls shown when an overlay item is selected.
/// Adapts buttons based on the overlay type (layer vs filter).
class TimelineOverlayControls extends StatelessWidget {
  const TimelineOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final overlayState = context.watch<TimelineOverlayBloc>().state;
    final selectedId = overlayState.selectedItemId;
    if (selectedId == null) return const SizedBox.shrink();

    final item = overlayState.items
        .where((i) => i.id == selectedId)
        .firstOrNull;
    if (item == null) return const SizedBox.shrink();

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
/// Text layers get an Edit button; others get Delete + Done.
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

    final updatedLayer = await scope.onAddEditTextLayer(
      originalLayer,
    );
    if (updatedLayer == null) return;

    editor.applyTextLayerChanges(layer, updatedLayer);
  }
}

/// Controls for filter overlays: Delete + Done.
class _FilterOverlayControls extends StatelessWidget {
  const _FilterOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return VideoEditorTimelineControls(
      onDelete: () => _removeFilter(context: context),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  void _removeFilter({
    required BuildContext context,
  }) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final currentFilters = List<FilterState>.from(
      editor.stateManager.activeFilters,
    );
    final filterIdx = currentFilters.indexWhere((f) => f.id == item.id);
    if (filterIdx < 0) return;
    currentFilters.removeAt(filterIdx);

    // The editor history system uses lastWhere(filters.isNotEmpty) to derive
    // activeFilters. An empty list would fall back to the previous non-empty
    // entry, keeping the old filter active. A single no-op FilterState
    // (empty matrices) is non-empty as a list, so it takes priority and
    // causes the rendered filter to be a no-op (no colour transformation).
    final newFilters = currentFilters.isEmpty
        ? [FilterState(name: 'none')]
        : currentFilters;
    editor.addHistory(filters: newFilters);

    // Sync the BLoC's applied-filter list so the BlocListener re-syncs the
    // timeline overlay strips. Remove only this specific entry so that sibling
    // filter strips (other applied filters) remain visible.
    context.read<VideoEditorFilterBloc>().add(
      VideoEditorFilterRemovedAt(filterIdx),
    );

    // Deselect immediately so the controls bar collapses without waiting for
    // the async overlay update.
    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }
}

/// Controls for sound overlays: Delete + Done.
class _SoundOverlayControls extends StatelessWidget {
  const _SoundOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return VideoEditorTimelineControls(
      onDelete: () => _removeSound(context: context),
      onEdit: () => _editSound(context: context),
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
}

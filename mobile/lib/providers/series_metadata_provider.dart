// ABOUTME: Per-segment metadata (title/description/thumbnail) for a 60s series.
// ABOUTME: Drives the per-segment tabs on the metadata screen before publish.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';

/// Per-segment metadata the user can customise before publishing a series.
///
/// Only the fields that differ per segment live here; shared fields (tags,
/// expiration, collaborators, …) stay on the global video-editor state.
class SegmentMetadata {
  const SegmentMetadata({
    this.title = '',
    this.description = '',
    this.thumbnailTimestamp,
  });

  final String title;
  final String description;

  /// Frame offset (within the segment) chosen as its thumbnail, or null for
  /// the segment's default (first frame).
  final Duration? thumbnailTimestamp;

  SegmentMetadata copyWith({
    String? title,
    String? description,
    Duration? thumbnailTimestamp,
  }) => SegmentMetadata(
    title: title ?? this.title,
    description: description ?? this.description,
    thumbnailTimestamp: thumbnailTimestamp ?? this.thumbnailTimestamp,
  );
}

/// State for the per-segment metadata tabs.
class SeriesMetadataState {
  const SeriesMetadataState({this.segments = const [], this.activeIndex = 0});

  final List<SegmentMetadata> segments;
  final int activeIndex;

  /// True when there is more than one segment, i.e. the tabs should be shown.
  bool get isSeries => segments.length > 1;

  int get count => segments.length;

  /// The currently-selected segment, or null when there are no segments.
  SegmentMetadata? get active => segments.isEmpty
      ? null
      : segments[activeIndex.clamp(0, segments.length - 1)];

  SeriesMetadataState copyWith({
    List<SegmentMetadata>? segments,
    int? activeIndex,
  }) => SeriesMetadataState(
    segments: segments ?? this.segments,
    activeIndex: activeIndex ?? this.activeIndex,
  );
}

class SeriesMetadataNotifier extends Notifier<SeriesMetadataState> {
  /// Derives one blank segment per per-video-limit slice of the rendered clip.
  ///
  /// Re-runs only when the rendered clip's duration changes (e.g. a re-render),
  /// so the user's per-segment edits persist while they stay on the screen.
  @override
  SeriesMetadataState build() {
    final duration = ref.watch(
      videoEditorProvider.select((s) => s.finalRenderedClip?.duration),
    );
    final count = duration == null
        ? 0
        : VideoEditorRenderService.computeSegmentWindows(
            totalDuration: duration,
            maxSegmentDuration: VideoEditorConstants.maxDuration,
          ).length;
    return SeriesMetadataState(
      segments: List.generate(count, (_) => const SegmentMetadata()),
    );
  }

  void setActiveIndex(int index) {
    if (index < 0 ||
        index >= state.segments.length ||
        index == state.activeIndex) {
      return;
    }
    state = state.copyWith(activeIndex: index);
  }

  void updateActive({
    String? title,
    String? description,
    Duration? thumbnailTimestamp,
  }) {
    final index = state.activeIndex;
    if (index < 0 || index >= state.segments.length) return;
    final segments = [...state.segments];
    segments[index] = segments[index].copyWith(
      title: title,
      description: description,
      thumbnailTimestamp: thumbnailTimestamp,
    );
    state = state.copyWith(segments: segments);
  }
}

final seriesMetadataProvider =
    NotifierProvider<SeriesMetadataNotifier, SeriesMetadataState>(
      SeriesMetadataNotifier.new,
    );

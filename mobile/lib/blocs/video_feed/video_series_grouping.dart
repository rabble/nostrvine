// ABOUTME: Collapses series segments in a feed video list into one card.
// ABOUTME: Pure helper so the grouping math is unit-testable in isolation.

import 'package:models/models.dart';

/// A feed video list after series collapsing.
///
/// [items] is the feed order with each series reduced to a single anchor
/// (its first segment). [seriesSegments] maps a series id to its full,
/// index-ordered segment list so the UI can render a swipeable card.
typedef GroupedSeriesFeed = ({
  List<VideoEvent> items,
  Map<String, List<VideoEvent>> seriesSegments,
});

/// Collapses series segments in [videos] into a single anchor item per series.
///
/// A series is identified by a shared [VideoEvent.series] id. Every segment of
/// a series is removed from [GroupedSeriesFeed.items] except one anchor, placed
/// at the position the series was first seen so overall feed order is preserved.
/// The anchor is the lowest-`index` segment, and the full ordered segment list
/// is returned under the series id. Videos without a series pass through
/// unchanged.
GroupedSeriesFeed groupVideoSeries(List<VideoEvent> videos) {
  final seriesSegments = <String, List<VideoEvent>>{};
  for (final video in videos) {
    final series = video.series;
    if (series == null) continue;
    (seriesSegments[series.id] ??= <VideoEvent>[]).add(video);
  }

  for (final segments in seriesSegments.values) {
    segments.sort((a, b) => a.series!.index.compareTo(b.series!.index));
  }

  final items = <VideoEvent>[];
  final placedSeries = <String>{};
  for (final video in videos) {
    final series = video.series;
    if (series == null) {
      items.add(video);
    } else if (placedSeries.add(series.id)) {
      // First segment of this series seen: place the ordered anchor here.
      items.add(seriesSegments[series.id]!.first);
    }
  }

  return (items: items, seriesSegments: seriesSegments);
}

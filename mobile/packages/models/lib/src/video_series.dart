import 'package:meta/meta.dart';

/// Membership of a video in an ordered series of short segments that were
/// published together — a longer recording split into per-video-limit pieces.
///
/// Carried on each segment's video event as a
/// `["series", "<id>", "<index>", "<total>"]` tag so a client can group and
/// order the segments without needing the (optional) NIP-51 container event.
@immutable
class VideoSeries {
  const VideoSeries({
    required this.id,
    required this.index,
    required this.total,
  });

  /// Parses a `["series", "<id>", "<index>", "<total>"]` tag.
  ///
  /// Returns null when the tag is missing fields or has a non-numeric
  /// index/total, so a malformed tag degrades to "not part of a series".
  static VideoSeries? fromTag(List<dynamic> tag) {
    if (tag.length < 4 || tag[0] != 'series') return null;
    final id = tag[1]?.toString() ?? '';
    final index = int.tryParse(tag[2]?.toString() ?? '');
    final total = int.tryParse(tag[3]?.toString() ?? '');
    if (id.isEmpty || index == null || total == null) return null;
    return VideoSeries(id: id, index: index, total: total);
  }

  /// Restores a series from its [toJson] map, or null when absent/invalid.
  static VideoSeries? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'] as String?;
    final index = (json['index'] as num?)?.toInt();
    final total = (json['total'] as num?)?.toInt();
    if (id == null || id.isEmpty || index == null || total == null) return null;
    return VideoSeries(id: id, index: index, total: total);
  }

  /// Shared identifier of the series (identical across all its segments).
  final String id;

  /// Zero-based position of this segment within the series.
  final int index;

  /// Total number of segments in the series.
  final int total;

  /// Human-facing position label, e.g. `1/10` for the first of ten.
  String get positionLabel => '${index + 1}/$total';

  Map<String, dynamic> toJson() => {'id': id, 'index': index, 'total': total};

  @override
  bool operator ==(Object other) =>
      other is VideoSeries &&
      other.id == id &&
      other.index == index &&
      other.total == total;

  @override
  int get hashCode => Object.hash(id, index, total);

  @override
  String toString() => 'VideoSeries(id: $id, index: $index, total: $total)';
}

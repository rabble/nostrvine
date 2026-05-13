import 'package:meta/meta.dart';
import 'package:models/src/video_stats.dart';

/// Response from the recommendations endpoint.
///
/// Contains recommended videos and the source of the recommendations
/// (e.g. "personalized", "popular", "recent").
@immutable
class RecommendationsResponse {
  /// Creates a new [RecommendationsResponse].
  const RecommendationsResponse({required this.videos, required this.source});

  /// The recommended videos.
  final List<VideoStats> videos;

  /// Source of recommendations.
  ///
  /// Possible values: `"personalized"`, `"popular"`, `"recent"`,
  /// or `"error"`.
  final String source;

  /// Whether recommendations are personalized (vs fallback).
  bool get isPersonalized => source == 'personalized';
}

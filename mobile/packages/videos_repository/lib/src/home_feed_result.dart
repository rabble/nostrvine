// ABOUTME: Result model for home feed fetches with list attribution.
// ABOUTME: Contains merged videos (following + list) plus metadata
// ABOUTME: mapping videos to their source curated lists.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// {@template home_feed_result}
/// Result of a home feed fetch, including list attribution metadata.
///
/// When the home feed includes videos from subscribed curated lists,
/// [videoListSources] maps each video to the lists that reference it,
/// and [listOnlyVideoIds] identifies videos present only because of
/// list subscriptions (not from followed authors).
///
/// When no list video refs are provided, [videoListSources] and
/// [listOnlyVideoIds] are empty — the result contains only following
/// videos with no list attribution.
///
/// When the home feed merges followed hashtags, [videoHashtagSources]
/// maps each video id to the canonical hashtag label(s) that contributed
/// that video via getVideosByHashtag.
/// {@endtemplate}
class HomeFeedResult extends Equatable {
  /// {@macro home_feed_result}
  const HomeFeedResult({
    required this.videos,
    this.videoListSources = const {},
    this.listOnlyVideoIds = const {},
    this.videoHashtagSources = const {},
    this.rawResponseBody,
  });

  /// All videos (following + list), sorted by createdAt descending.
  final List<VideoEvent> videos;

  /// Maps videoId to the set of list IDs that reference it.
  ///
  /// Empty for videos that aren't in any subscribed list.
  /// A video from a followed author can still appear here if it's also
  /// in a subscribed list.
  final Map<String, Set<String>> videoListSources;

  /// Video IDs present ONLY because of list subscriptions
  /// (not from followed authors).
  ///
  /// Used by the UI to show list attribution — these videos need
  /// visual attribution since the user didn't follow the author.
  final Set<String> listOnlyVideoIds;

  /// Maps videoId → canonical hashtag label(s) that surfaced this video
  /// from followed-hashtag fetches (Funnelcake).
  ///
  /// Empty when this fetch did not merge followed hashtags.
  /// A video from a followed author can still appear here if it was also
  /// returned under a followed tag.
  final Map<String, Set<String>> videoHashtagSources;

  /// The raw JSON response body from the API, if available.
  ///
  /// Populated on initial (non-paginated) home feed fetches so the
  /// BLoC can cache it for instant display on next cold start.
  /// Excluded from equality checks.
  final String? rawResponseBody;

  @override
  List<Object?> get props => [
    videos,
    videoListSources,
    listOnlyVideoIds,
    videoHashtagSources,
  ];
}

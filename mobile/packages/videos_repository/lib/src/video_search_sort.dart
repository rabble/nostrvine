/// Server-backed sort options for video search.
enum VideoSearchSort {
  /// Popular results ranked by the server's trending score.
  trending('trending'),

  /// Results ranked by loop count.
  loops('loops'),

  /// Results ranked by engagement.
  engagement('engagement'),

  /// Newest results first.
  recent('recent');

  const VideoSearchSort(this.apiValue);

  /// Raw API value sent to Funnelcake.
  final String apiValue;
}

/// Default Funnelcake search sort.
const VideoSearchSort defaultVideoSearchSort = VideoSearchSort.trending;

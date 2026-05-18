// ABOUTME: Time-window enum for /api/leaderboard/videos?period=… queries.
// ABOUTME: Used by the Popular tab time-period filter.

/// Time window for funnelcake's `/api/leaderboard/videos?period=…` endpoint.
enum LeaderboardPeriod {
  /// Last 24 hours.
  day,

  /// Last 7 days.
  week,

  /// Last 30 days.
  month,

  /// All time.
  alltime;

  /// The exact token funnelcake's REST API expects in `?period=…`.
  String get wireValue => switch (this) {
    LeaderboardPeriod.day => 'day',
    LeaderboardPeriod.week => 'week',
    LeaderboardPeriod.month => 'month',
    LeaderboardPeriod.alltime => 'alltime',
  };

  /// The slug used in the mobile app's URL query param `?period=…`. We use
  /// `today` (not `day`) for readability of shared links.
  String get urlSlug => switch (this) {
    LeaderboardPeriod.day => 'today',
    LeaderboardPeriod.week => 'week',
    LeaderboardPeriod.month => 'month',
    LeaderboardPeriod.alltime => 'alltime',
  };

  /// Parses a URL slug back into a [LeaderboardPeriod]. Accepts both
  /// `today` and the funnelcake-native `day`. Returns `null` for any
  /// unknown or empty input — caller treats `null` as "Right Now".
  static LeaderboardPeriod? fromUrlSlug(String? slug) {
    return switch (slug) {
      'today' || 'day' => LeaderboardPeriod.day,
      'week' => LeaderboardPeriod.week,
      'month' => LeaderboardPeriod.month,
      'alltime' => LeaderboardPeriod.alltime,
      _ => null,
    };
  }
}

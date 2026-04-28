// ABOUTME: DateTime extensions for Nostr-style epoch-second integers.
// ABOUTME: Avoids the `* 1000` / `~/ 1000` magic numbers at every call site.

/// Conversions from a Nostr-style epoch-seconds [int] to a [DateTime].
extension EpochSecondsToDateTime on int {
  /// Treats this int as Nostr-style epoch seconds and returns the
  /// corresponding [DateTime] in UTC.
  ///
  /// Nostr `created_at` is conventionally UTC seconds, so the returned
  /// value is always UTC. Call `.toLocal()` if the wall-clock value is
  /// needed for display.
  DateTime toDateTimeFromEpochSeconds() =>
      DateTime.fromMillisecondsSinceEpoch(this * 1000, isUtc: true);
}

/// Conversions from a [DateTime] to Nostr-style epoch seconds.
extension DateTimeToEpochSeconds on DateTime {
  /// Returns this [DateTime] as Nostr-style epoch seconds.
  ///
  /// Sub-second precision is truncated (matches the dominant `~/ 1000`
  /// idiom used across the codebase).
  int toEpochSeconds() => millisecondsSinceEpoch ~/ 1000;
}

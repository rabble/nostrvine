// ABOUTME: Generates Nostr created_at values for sync events.
// ABOUTME: Clamps against known remote timestamps to survive clock skew.

import 'package:clock/clock.dart';

/// Produces `created_at` values for sync events.
abstract final class SyncClock {
  /// Seconds since epoch to stamp on the next published sync event.
  ///
  /// Replaceable events resolve conflicts by highest `created_at`, so a
  /// device with a fast clock would otherwise win forever. Clamping to
  /// `latestKnownRemote + 1` guarantees this device leads by exactly one
  /// second, letting a corrected clock reclaim the lead later.
  static int nowSeconds({int? latestKnownRemote}) {
    final now = clock.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if (latestKnownRemote == null || now > latestKnownRemote) {
      return now;
    }
    return latestKnownRemote + 1;
  }
}

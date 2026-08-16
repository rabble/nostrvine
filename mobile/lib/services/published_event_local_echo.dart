// ABOUTME: Stores a just-published video event locally so the app can read
// ABOUTME: its own post before any relay is able to serve it back.

import 'package:nostr_sdk/event.dart';
import 'package:unified_logger/unified_logger.dart';

/// Writes [event] into local video storage.
typedef PublishedEventWriter = Future<void> Function(Event event);

/// Makes a freshly published video readable immediately.
///
/// The relay commits to ClickHouse on a batch timer — production runs
/// `BATCH_INTERVAL_MS` in the minutes — and funnelcake's REST reads that same
/// table, so for the first few minutes after a publish neither can serve the
/// event back. Every branch of the `/video/<d-tag>` lookup misses: local
/// cache (the app never stored its own event), funnelcake, relay-by-id (the
/// route value is a `d` tag, not an event id), and relay-by-d-tag.
///
/// Opening the video straight after publishing — which the post-publish
/// confirmation's View button does — therefore rendered "Video not found".
/// Writing the signed event locally closes the first branch.
class PublishedEventLocalEcho {
  const PublishedEventLocalEcho(this._write);

  final PublishedEventWriter _write;

  /// Records [event] locally, best-effort.
  ///
  /// The video is already live on the relay by the time this runs, so a
  /// failed cache write must never turn a successful publish into a failed
  /// one — it costs the read-back, nothing more.
  Future<void> record(Event event) async {
    try {
      await _write(event);
    } catch (error) {
      Log.warning(
        'Failed to cache published event ${event.id} locally: $error',
        name: 'PublishedEventLocalEcho',
        category: LogCategory.video,
      );
    }
  }
}

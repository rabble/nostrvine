// ABOUTME: Port for an OS foreground session that keeps the process network
// ABOUTME: alive across the whole background publish (upload + sign + relay).

/// Keeps the app process foregrounded — and therefore its network usable — for
/// the duration of a background publish.
///
/// The OS-backed uploader only carries the video blob across app suspension.
/// The steps that follow (remote-signer signing of the Nostr event and relay
/// broadcast) run in-process and are network-starved once Android backgrounds
/// the app, failing with DNS / socket errors. Holding a session for the whole
/// publish keeps the process foregrounded so those steps succeed.
///
/// Implemented in the app layer over the `background_uploader` plugin and
/// injected into [BackgroundPublishBloc], so the bloc stays free of plugin
/// dependencies and the session is fakeable in tests.
abstract class PublishForegroundSession {
  /// Starts the session identified by [sessionId]. Must be called while the
  /// app is foregrounded — starting a foreground service from the background
  /// is forbidden on Android.
  Future<void> begin(String sessionId);

  /// Ends the session identified by [sessionId]. Safe to call when no matching
  /// session is active.
  Future<void> end(String sessionId);
}

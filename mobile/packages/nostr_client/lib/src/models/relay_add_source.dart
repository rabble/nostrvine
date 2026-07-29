/// Identifies why a relay is being added to the configured relay list.
enum RelayAddSource {
  /// The user explicitly added or restored the relay from settings.
  user,

  /// The app added the relay for discovery, fallback, bootstrap, or
  /// reachability.
  automatic,
}

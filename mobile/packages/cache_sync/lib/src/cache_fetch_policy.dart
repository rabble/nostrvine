/// Controls how CacheSync balances freshness vs. latency.
enum CacheFetchPolicy {
  /// Emit cached data first (if present and not expired), then fetch from the
  /// network and emit the fresh result.
  cacheAndNetwork,

  /// Return cached data only.  Never performs a network call.
  cacheOnly,

  /// Always fetch from the network.  Ignores any cached data.
  networkOnly,
}

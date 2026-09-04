// ABOUTME: Central policy for profile/media image URLs requested by the app.
// ABOUTME: Requires HTTPS and excludes origins verified dead at the source.

/// Whether [url] points at a host whose content is known to be permanently
/// unavailable, so no request should ever be attempted.
///
/// `v.cdn.vine.co` was verified dead on 2026-08-15: cleartext returns 403
/// for every probed object, and the TLS certificate (Twitter-issued
/// `*.cdn.vine.co`) expired 2025-07-10, so no scheme rewrite can help.
/// Sibling subdomains (e.g. `mt.cdn.vine.co`) are unverified and NOT
/// matched — extend this only with per-host evidence.
bool isKnownDeadImageHost(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase();
  return host == 'v.cdn.vine.co';
}

/// Whether [url] is eligible for a direct image request from the app.
///
/// Profile metadata is untrusted. Only HTTPS URLs with an authority are
/// fetched, and origins known to be permanently unavailable are rejected
/// before an image provider or cache operation is created.
bool isUsableNetworkImageUrl(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme.toLowerCase() == 'https' &&
      uri.hasAuthority &&
      !isKnownDeadImageHost(url);
}

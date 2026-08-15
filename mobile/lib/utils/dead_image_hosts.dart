// ABOUTME: Hosts whose image content is verified-dead at the origin and must
// ABOUTME: never be requested — the placeholder is the correct render.

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

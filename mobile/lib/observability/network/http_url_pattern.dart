// ABOUTME: URL policy for Firebase Performance network-request metrics.
// ABOUTME: Decides which hosts are reported and collapses identifier path
// ABOUTME: segments into route patterns so the console aggregates them.

import 'package:nostr_sdk/nostr_sdk.dart' show isLoopbackHost;

/// Hosts Divine operates, matched as the host itself or any subdomain.
///
/// `dvines.org` carries the `poc` and `test` relay/API hosts; `divine.video`
/// carries production, staging, the media/Blossom host, the names service and
/// the auxiliary workers. Keep in sync with `EnvironmentConfig`.
const Set<String> _divineHostSuffixes = {'divine.video', 'dvines.org'};

/// Whether requests to [host] are reported to Firebase Performance.
///
/// Only Divine-operated hosts and the local-stack loopback hosts are. Two
/// reasons to filter rather than report everything an instrumented client
/// sends:
///
/// * Firebase aggregates network requests per URL pattern and drops patterns
///   past a per-app cap. A user-configured relay, Blossom server or avatar
///   host would spend that cap on hosts we cannot act on.
/// * Third-party hosts (a user's own media server, an arbitrary NIP-05
///   domain) are not ours to measure, and their URLs can carry
///   user-identifying paths.
///
/// Loopback is included so a local-stack run can be verified end to end
/// against the console before shipping a change.
bool isInstrumentedHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized.isEmpty) return false;
  if (isLoopbackHost(normalized)) return true;
  return _divineHostSuffixes.any(
    (suffix) => normalized == suffix || normalized.endsWith('.$suffix'),
  );
}

/// Prefix free-text routes: any remainder after [prefix] is one identifier.
///
/// Add an entry when a new endpoint interpolates something arbitrary (a
/// username, a slug, a search term) into its *path* and the remainder is a
/// single segment. Query parameters need no entry — [httpMetricUrlPattern]
/// drops the query entirely.
///
/// Placeholders use the `:name` form for the reason given on
/// [_normalizeIdentifier] — braces would make the URL unparseable.
const List<(String, String)> _freeTextRoutePatterns = [
  // names.divine.video/api/username/check/<username> — one pattern per
  // username typed into the claim field otherwise.
  ('/api/username/check/', '/api/username/check/:username'),
];

/// Structured free-text routes whose identifier is not the whole remainder
/// (subpaths after the id, or static siblings that must stay distinct).
///
/// Funnelcake accepts stableId / d-tag / vine shortcodes on video paths —
/// values like `5gITeYOlL7g` that fail the hex/uuid/opaque recognisers and
/// would otherwise mint one Firebase pattern per video.
final List<(RegExp, String Function(Match))> _structuredFreeTextRoutes = [
  // /api/videos/<id> and /api/videos/<id>/{stats|views}, but not
  // /api/videos/stats/bulk (static "stats" segment).
  (
    RegExp(r'^/api/videos/(?!stats(?:/|$))([^/]+)(?:/(stats|views))?$'),
    (m) {
      final suffix = m.group(2);
      return suffix == null ? '/api/videos/:id' : '/api/videos/:id/$suffix';
    },
  ),
  (
    RegExp(r'^/api/v2/videos/([^/]+)/comments$'),
    (_) => '/api/v2/videos/:id/comments',
  ),
];

final RegExp _digits = RegExp(r'^\d+$');
final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Nostr bech32 entities (NIP-19). Reported as `:npub`, `:nevent`, … so the
/// entity type stays readable in the console.
final RegExp _bech32Entity = RegExp(
  r'^(npub|nsec|note|nevent|naddr|nprofile|nrelay|ncryptsec)1[a-z0-9]{6,}$',
  caseSensitive: false,
);

/// Hex identifiers: 64-char pubkeys, event ids and sha256 hashes, plus any
/// other long hex token.
final RegExp _hexIdentifier = RegExp(r'^[0-9a-f]{32,}$', caseSensitive: false);

/// Opaque tokens (base64url-ish). Requires a digit so ordinary long words
/// stay untouched.
final RegExp _opaqueIdentifier = RegExp(r'^(?=[^\d]*\d)[A-Za-z0-9_-]{20,}$');

final RegExp _fileExtension = RegExp(r'^[A-Za-z0-9]{1,5}$');

/// The URL reported to Firebase for a request to [url].
///
/// Keeps scheme, host and an explicit port; drops userinfo, query and
/// fragment; and replaces identifier path segments with placeholders so every
/// call to one endpoint lands on one pattern:
///
/// ```
/// https://api.divine.video/api/users/<64-hex>/videos?limit=20
///   -> https://api.divine.video/api/users/:id/videos
/// https://media.divine.video/<sha256>.mp4
///   -> https://media.divine.video/:id.mp4
/// ```
///
/// Identifiers are replaced whole, never shortened — a truncated Nostr id is
/// still an id, and the repo bans emitting one (AGENTS.md, "Nostr And Async
/// Rules").
String httpMetricUrlPattern(Uri url) {
  final host = url.host.toLowerCase();
  // Bracket IPv6 hosts so the reported URL stays parseable by the Firebase
  // SDKs (same silent-drop failure mode as the braced-placeholder bug).
  final hostForAuthority = host.contains(':') ? '[$host]' : host;
  final authority = url.hasPort
      ? '$hostForAuthority:${url.port}'
      : hostForAuthority;
  return '${url.scheme}://$authority${_normalizePath(url.path)}';
}

String _normalizePath(String path) {
  for (final (prefix, pattern) in _freeTextRoutePatterns) {
    if (path.startsWith(prefix) && path.length > prefix.length) {
      return pattern;
    }
  }
  for (final (pattern, rewrite) in _structuredFreeTextRoutes) {
    final match = pattern.firstMatch(path);
    if (match != null) return rewrite(match);
  }
  return path.split('/').map(_normalizeSegment).join('/');
}

String _normalizeSegment(String segment) {
  if (segment.isEmpty) return segment;

  final lastDot = segment.lastIndexOf('.');
  if (lastDot > 0) {
    final extension = segment.substring(lastDot + 1);
    if (_fileExtension.hasMatch(extension)) {
      final stem = _normalizeIdentifier(segment.substring(0, lastDot));
      return '$stem.${extension.toLowerCase()}';
    }
  }
  return _normalizeIdentifier(segment);
}

/// Placeholders use `:name`, never `{name}`.
///
/// Both Firebase SDKs parse the reported URL before they will record it, and
/// braces are excluded characters in RFC 2396/3986. Android's
/// `FirebasePerfNetworkValidator` runs it through `java.net.URI.create`,
/// which throws, and the metric is dropped at dispatch with "URL cannot be
/// parsed" — so a braced pattern reports nothing at all. iOS 16's
/// `NSURL(string:)` returns nil for the same reason and the plugin fails the
/// call with `invalid-url`; newer Foundation percent-encodes it to
/// `%7Bid%7D`. A colon is a legal `pchar`, so `:id` parses on both.
///
/// `http_url_pattern_test.dart` pins the character set. Do not "tidy" these
/// back into braces.
String _normalizeIdentifier(String value) {
  if (value.isEmpty) return value;
  if (_digits.hasMatch(value)) return ':n';
  if (_uuid.hasMatch(value)) return ':uuid';

  final entity = _bech32Entity.firstMatch(value);
  if (entity != null) return ':${entity.group(1)!.toLowerCase()}';

  if (_hexIdentifier.hasMatch(value)) return ':id';
  if (_opaqueIdentifier.hasMatch(value)) return ':id';
  return value;
}

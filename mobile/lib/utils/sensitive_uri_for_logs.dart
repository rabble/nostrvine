// ABOUTME: Redacts secrets from URIs before writing them to diagnostic logs.
// ABOUTME: Preserves schemes, hosts, paths, and Nostr path segments unchanged except /invite/code.

/// Placeholder for secrets in free-form log text or HTTP headers.
const redactedSensitiveLogPlaceholder = '[REDACTED]';

/// Value used inside [Uri] path and query fragments so `Uri.toString()` does
/// not percent-encode bracket punctuation.
const redactedUriComponentForLogs = 'REDACTED';

/// Returns a URI string safe for logs: clears [userInfo], redacts query and
/// fragment values, redacts `/invite/<code>` path segments while keeping routes
/// like `/video/<ref>` verbatim (including full Nostr-style refs).
///
/// On parse failure, returns `[invalid-uri]` without echoing [uriString].
String redactUriStringForLogs(String uriString) {
  final trimmed = uriString.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || trimmed.isEmpty) {
    return '[invalid-uri]';
  }

  var pathSegments = List<String>.from(uri.pathSegments);
  if (pathSegments.length >= 2 &&
      pathSegments.first.toLowerCase() == 'invite') {
    pathSegments = [
      pathSegments.first,
      redactedUriComponentForLogs,
      ...pathSegments.skip(2),
    ];
  }

  final Map<String, dynamic>? qp;
  if (uri.query.isEmpty) {
    qp = null;
  } else {
    qp = {
      for (final e in uri.queryParametersAll.entries)
        e.key: e.value.length == 1
            ? redactedUriComponentForLogs
            : List<String>.filled(e.value.length, redactedUriComponentForLogs),
    };
  }

  var redactedUri = uri.replace(
    userInfo: '',
    pathSegments: pathSegments,
    queryParameters: qp,
  );
  if (uri.fragment.isNotEmpty) {
    redactedUri = redactedUri.replace(fragment: redactedUriComponentForLogs);
  }
  var out = redactedUri.toString();
  // `Uri.replace(pathSegments: ...)` drops the leading "/" on scheme-less
  // absolute paths used as GoRouter locations. Restore it for readable logs.
  if (!uri.hasScheme && uri.hasAbsolutePath && !out.startsWith('/')) {
    out = '/$out';
  }
  return out;
}

// ABOUTME: Redacts Authorization / Nostr auth payloads from header maps before logging.

/// Placeholder substituted for credential-like header values in log output.
const redactedSensitiveLogPlaceholder = '[REDACTED]';

/// Returns a shallow copy of [headers] suitable for logs: values of
/// `Authorization` become `[REDACTED]` or `Nostr [REDACTED]` when the value
/// used the Blossom/NIP-98 `Nostr` prefix (case-insensitive).
Map<String, String> redactHttpHeadersForLogs(Map<String, String> headers) {
  final out = Map<String, String>.from(headers);
  for (final key in out.keys.toList(growable: false)) {
    if (key.toLowerCase() != 'authorization') {
      continue;
    }
    final value = out[key]!;
    if (value.trimLeft().toLowerCase().startsWith('nostr')) {
      out[key] = 'Nostr $redactedSensitiveLogPlaceholder';
    } else {
      out[key] = redactedSensitiveLogPlaceholder;
    }
  }
  return out;
}

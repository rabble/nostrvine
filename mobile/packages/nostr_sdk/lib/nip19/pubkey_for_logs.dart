// ABOUTME: Renders a hex pubkey as its full npub plus the full hex, for logs.
// ABOUTME: Never truncates, never throws — safe to call inside any log sink.

import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nip19/nip19.dart';

/// The full npub for [hexPubkey] with the hex retained, for log/debug sinks.
///
/// Renders `npub1…full (…full hex)`. Hex is what greps against relay logs and
/// backend rows; npub is what a person pastes into a client. A support log
/// needs both, so neither is dropped and neither is shortened — see the Nostr
/// rule in AGENTS.md and the guard in `scripts/check_nostr_id_log_truncation.sh`.
///
/// Returns a marker for `null` and for the empty string, and returns anything
/// that is not an encodable 32-byte hex key — a short hex, a value that is
/// already an npub, a garbage string off a relay — unchanged and whole. These
/// call sites sit inside `Log.error` handlers holding remote-supplied input, so
/// a formatter that threw would turn a diagnostic line into a crash.
String pubkeyForLogs(String? hexPubkey) {
  if (hexPubkey == null) return '<null>';
  if (hexPubkey.isEmpty) return '<empty>';
  if (!keyIsValid(hexPubkey)) return hexPubkey;
  try {
    return '${Nip19.encodePubKey(hexPubkey)} ($hexPubkey)';
  } on Exception {
    return hexPubkey;
  }
}

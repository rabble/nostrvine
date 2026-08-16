// ABOUTME: Single source of truth for which relay URLs the client may dial.
// ABOUTME: Distinguishes self/app-supplied URLs from ones a remote party chose.

import 'package:nostr_sdk/utils/loopback_host.dart';

/// Upper bounds on how many relays the client will adopt from a single
/// advertised relay list.
///
/// A relay list arriving from the network is untrusted input, and nothing in
/// the protocol bounds its length — so the client bounds it. Both values sit
/// well above the sizing the NIPs themselves recommend, because the point is
/// to turn "unbounded" into a small constant, not to be tight: a cap that
/// bites a legitimate user silently reduces their reachability.
abstract final class RelayListCaps {
  /// Cap for a NIP-17 kind-10050 DM inbox relay list.
  ///
  /// NIP-17: "Clients SHOULD guide users to keep `kind:10050` lists small
  /// (1-3 relays)."
  static const int dmInbox = 8;

  /// Cap for a NIP-65 kind-10002 relay list metadata event.
  ///
  /// NIP-65: "Clients SHOULD guide users to keep `kind:10002` lists small
  /// (2-4 relays of each category)" — read and write, hence the larger bound.
  static const int nip65 = 16;

  /// Cap on the relays a NIP-46 signer may add to one pairing session by
  /// naming them in its deep-link callback.
  ///
  /// A signer returning control names the transport it answered on, so the
  /// protocol-meaningful count is one. This sits above that for the same
  /// reason the other two do — a signer retrying on a second transport is
  /// plausible, and a cap that bites costs the user the pairing. It matches
  /// the advertised set the session already dials, so one pairing opens at
  /// most twice the sockets it started with.
  static const int nip46Callback = 4;
}

/// Whether [url] is a relay URL the app may connect to.
///
/// Nostr relays speak WebSocket only — `wss://` is accepted for any host, and
/// `ws://` only for a recognized loopback host (the local Docker stack). Any
/// other scheme, a malformed URL, or a missing host is rejected.
///
/// Use this for URLs the app itself configured or the user authored. For a
/// list a *remote* party controls, use [isRemoteSuppliedRelayUrlAllowed].
///
/// This is the single source of truth for the rule; `mobile/lib`,
/// `nostr_client`, and `dm_repository` all delegate here rather than
/// re-implementing it (see #3362 / PR #3806, and #6585 which removed the last
/// drifted copy).
bool isRelayUrlAllowed(String url) {
  final uri = _tryParseRelayUri(url);
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'wss') return true;
  if (scheme == 'ws') return isLoopbackHost(uri.host);
  return false;
}

/// Whether [url] may be dialed when a *remote* party chose it.
///
/// Adds a host restriction on top of [isRelayUrlAllowed]: private, loopback,
/// and link-local addresses are refused. A counterparty's kind-10050 or an
/// indexer's kind-10002 must not be able to point this device at the user's
/// LAN, VPN, or loopback interface — neither to reach a service there nor to
/// learn, from how the connection behaves, whether one exists.
///
/// Note this makes `ws://` unreachable by construction: its only allowance was
/// loopback, which this predicate refuses. That is intended — a remote party
/// has no legitimate reason to ask for cleartext.
bool isRemoteSuppliedRelayUrlAllowed(String url) {
  final uri = _tryParseRelayUri(url);
  return uri != null && _isRemoteSuppliedUriAllowed(uri);
}

/// Whether [url] may be dialed when a NIP-46 signer named it in its callback.
///
/// Sits between the other two. A signer app on this device is not the stranger
/// [isRemoteSuppliedRelayUrlAllowed] guards against — same-device signers run
/// their relay on loopback and hand the client that address, and NIP-46 puts
/// the signer "in control of what relays are being used", so refusing loopback
/// would break the flow the callback exists to serve.
///
/// The rest of that predicate's reasoning still holds: the callback is a deep
/// link, so whoever opened it chose this URL, and it must not be able to point
/// the device at the user's LAN or VPN. Cleartext stays confined to loopback,
/// where it never leaves the device.
bool isSignerCallbackRelayUrlAllowed(String url) {
  final uri = _tryParseRelayUri(url);
  if (uri == null) return false;
  final host = uri.host;
  if (isLoopbackHost(host)) return isRelayUrlAllowed(url);
  return _isRemoteSuppliedUriAllowed(uri);
}

bool _isRemoteSuppliedUriAllowed(Uri uri) =>
    uri.scheme.toLowerCase() == 'wss' && !isPrivateOrLinkLocalHost(uri.host);

Uri? _tryParseRelayUri(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  // `wss://http://x` parses as host=`http` with path=`//x`; reject so a
  // mis-nested URL in a relay-list tag cannot pass and then target a
  // different host once the connection layer re-parses it.
  if (uri.path.startsWith('//')) return null;
  return uri;
}

/// The identity [urls] entries are deduplicated under, or null when a remote
/// party may not name this one at all.
///
/// Admitting and keying share a single parse: deciding twice would double the
/// work done per entry on input that is untrusted and, before the cap applies,
/// unbounded — and would let the two answers drift apart.
///
/// Only a bare root path is collapsed, so `wss://h.example` and
/// `wss://h.example/` are one relay while `wss://h.example/a` and
/// `wss://h.example/a/` stay two. That is the equivalence
/// `RelayAddrUtil.handle` already applies to every address this package dials;
/// a wider rule here would disagree with the pool it feeds. Scheme and host
/// need no case folding — `Uri` canonicalizes both at parse.
String? _admittedRemoteRelayKey(String url) {
  final uri = _tryParseRelayUri(url);
  if (uri == null || !_isRemoteSuppliedUriAllowed(uri)) return null;
  return uri.replace(path: uri.path == '/' ? '' : uri.path).toString();
}

/// Filters [urls] to those a remote party may legitimately point us at, and
/// truncates the result to [cap], preserving order.
///
/// Duplicates are collapsed. [onRejected] and [onTruncated] let the caller log
/// at its own layer, so this stays free of any logging dependency.
List<String> admitRemoteSuppliedRelays(
  Iterable<String> urls, {
  required int cap,
  void Function(String url)? onRejected,
  void Function(int kept, int total)? onTruncated,
}) {
  final admittedByKey = <String, String>{};
  for (final url in urls) {
    final key = _admittedRemoteRelayKey(url);
    if (key == null) {
      onRejected?.call(url);
      continue;
    }
    admittedByKey.putIfAbsent(key, () => url);
  }
  if (admittedByKey.length <= cap) return admittedByKey.values.toList();
  onTruncated?.call(cap, admittedByKey.length);
  return admittedByKey.values.take(cap).toList();
}

// ABOUTME: Loopback-host predicate for the local-stack TLS allowance.
// ABOUTME: Bad TLS certificates are tolerated only for these hosts; remote
// ABOUTME: hosts always go through platform certificate validation.

import 'package:flutter/foundation.dart';

/// The hosts that name an interface on this device. `::1` is the IPv6
/// loopback.
const Set<String> _onDeviceLoopbackHosts = {'localhost', '127.0.0.1', '::1'};

/// The hosts the local Docker stack is reachable on (see AGENTS.md,
/// "Local Stack Development"). `10.0.2.2` is the Android emulator's alias
/// for the host machine.
const Set<String> _loopbackHosts = {..._onDeviceLoopbackHosts, '10.0.2.2'};

/// Whether [host] is a local-stack loopback host.
///
/// Used to scope `HttpClient.badCertificateCallback`: self-signed
/// certificates are acceptable when developing against the local stack on
/// these hosts, but remote hosts (the divine relay, the funnelcake API)
/// must always pass platform certificate validation.
bool isLoopbackHost(String host) => _loopbackHosts.contains(host.toLowerCase());

/// Whether [host] names a loopback interface on this device.
///
/// Narrower than [isLoopbackHost], which also admits `10.0.2.2`. Only the
/// Android emulator maps that alias to the host machine; everywhere else it is
/// an ordinary routable 10/8 LAN address, and [isPrivateOrLinkLocalHost]
/// refuses it. Use this where the point is "traffic here never leaves the
/// device" — a same-device NIP-46 signer naming its own relay, say — rather
/// than "the local stack is reachable here".
bool isOnDeviceLoopbackHost(String host) =>
    _onDeviceLoopbackHosts.contains(host.toLowerCase());

/// Whether a bad TLS certificate may be tolerated for [host].
///
/// This is intentionally debug-only. The local-stack production allowance is
/// cleartext (`ws://` / `http://`) loopback, not self-signed TLS.
bool allowsLocalBadCertificateHost(String host) =>
    kDebugMode && isLoopbackHost(host);

/// Hostname suffixes that resolve only inside a private network.
const Set<String> _privateHostSuffixes = {'.local', '.internal', '.home.arpa'};

/// Whether [host] names a private, loopback, or link-local endpoint — an
/// address that is only meaningful inside the device's own network.
///
/// Used to refuse relay URLs supplied by a *remote* party. A counterparty
/// choosing which hosts this device dials must not be able to point it at the
/// user's LAN, VPN, or loopback interface. Self-authored and app-configured
/// URLs are not filtered by this (the local stack legitimately runs on
/// loopback) — see `isRemoteSuppliedRelayUrlAllowed` in `relay_url_policy.dart`.
///
/// Resolves [host] to an IP address before testing, so alternate literal
/// encodings (`0x7f.0.0.1`, `2130706433`, `::ffff:192.168.0.1`) are judged by
/// the address they denote rather than slipping past a string comparison.
/// A host that is not an IP literal is matched on name: [isLoopbackHost]
/// members plus [_privateHostSuffixes].
///
/// This does **not** resolve DNS — `wss://evil.example` that happens to
/// resolve to `192.168.1.1` is not caught here. Doing so would need async
/// resolution on the admission path and would still be racable via short TTLs,
/// so the filter deliberately stops at literals and known-private names.
///
/// Deliberately free of `dart:io`: `nostr_sdk` builds for web, where
/// `InternetAddress` does not exist. Parsing is `dart:core` only.
bool isPrivateOrLinkLocalHost(String host) {
  final normalized = host.toLowerCase().trim();
  if (normalized.isEmpty) return true;
  // A bracketed IPv6 literal arrives with its brackets when read off a URI.
  final bracketless = normalized.startsWith('[') && normalized.endsWith(']')
      ? normalized.substring(1, normalized.length - 1)
      : normalized;

  // A trailing dot root-anchors a name without changing what it resolves to,
  // so `localhost.` and `192.168.1.1.` must be judged as their bare forms.
  // Left in, the dot breaks every lookup below: it adds an empty fifth part
  // that defeats [_tryParseIPv4], and it misses both [isLoopbackHost] and
  // [_privateHostSuffixes] on the name comparison.
  final bare = bracketless.endsWith('.')
      ? bracketless.substring(0, bracketless.length - 1)
      : bracketless;
  if (bare.isEmpty) return true;

  final ipv4 = _tryParseIPv4(bare);
  if (ipv4 != null) return _isPrivateIPv4(ipv4);

  final ipv6 = _tryParseIPv6(bare);
  if (ipv6 != null) return _isPrivateIPv6(ipv6);

  if (isLoopbackHost(bare)) return true;
  return _privateHostSuffixes.any(bare.endsWith);
}

/// Parses the `inet_aton` family of IPv4 literals into four octets.
///
/// Accepts 1–4 dot-separated parts, each decimal, octal (`0…`), or hex
/// (`0x…`) — the same shapes the platform resolver accepts. The trailing part
/// absorbs the remaining octets, so `127.1` is `127.0.0.1` and `2130706433`
/// is `127.0.0.1`. Returns null when [host] is not an IPv4 literal at all.
List<int>? _tryParseIPv4(String host) {
  final parts = host.split('.');
  if (parts.isEmpty || parts.length > 4) return null;
  final values = <int>[];
  for (final part in parts) {
    final value = _parseUnsignedRadixAware(part);
    if (value == null) return null;
    values.add(value);
  }
  // Every leading part is a single octet; the last absorbs what remains.
  final octetsLeft = 4 - (values.length - 1);
  if (values.take(values.length - 1).any((v) => v > 0xff)) return null;
  final maxTail = octetsLeft == 4 ? 0xffffffff : (1 << (8 * octetsLeft)) - 1;
  if (values.last > maxTail) return null;

  var packed = 0;
  for (var i = 0; i < values.length - 1; i++) {
    packed = (packed << 8) | values[i];
  }
  packed = (packed << (8 * octetsLeft)) | values.last;
  return [
    (packed >> 24) & 0xff,
    (packed >> 16) & 0xff,
    (packed >> 8) & 0xff,
    packed & 0xff,
  ];
}

int? _parseUnsignedRadixAware(String raw) {
  if (raw.isEmpty) return null;
  if (raw.startsWith('0x')) {
    if (raw.length == 2) return null;
    return int.tryParse(raw.substring(2), radix: 16);
  }
  if (raw.length > 1 && raw.startsWith('0')) {
    return int.tryParse(raw.substring(1), radix: 8);
  }
  return int.tryParse(raw);
}

/// Parses an IPv6 literal into 16 bytes, or null when [host] is not one.
///
/// `Uri.parseIPv6Address` is `dart:core` and handles `::` compression and the
/// embedded-IPv4 tail, so there is no hand-rolled IPv6 parsing here.
List<int>? _tryParseIPv6(String host) {
  if (!host.contains(':')) return null;
  try {
    return Uri.parseIPv6Address(host);
  } on FormatException {
    return null;
  }
}

/// Whether [b] is outside the globally routable unicast space.
///
/// Tracks the IANA IPv4 Special-Purpose Address Registry rather than only the
/// reachable-LAN set: a relay list a stranger wrote has no business naming any
/// of these, and "not globally routable" is a rule that can be checked against
/// a published registry instead of re-argued per range.
bool _isPrivateIPv4(List<int> b) {
  if (b[0] == 10) return true; // 10.0.0.0/8 private
  if (b[0] == 127) return true; // 127.0.0.0/8 loopback
  if (b[0] == 0) return true; // 0.0.0.0/8 "this network"
  if (b[0] == 169 && b[1] == 254) return true; // 169.254.0.0/16 link-local
  if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true; // 172.16.0.0/12
  if (b[0] == 192 && b[1] == 168) return true; // 192.168.0.0/16
  if (b[0] == 100 && b[1] >= 64 && b[1] <= 127) return true; // 100.64/10 CGNAT
  if (b[0] >= 224) return true; // 224.0.0.0/4 multicast + 240/4 reserved
  // 192.0.0.0/24 IETF protocol assignments.
  if (b[0] == 192 && b[1] == 0 && b[2] == 0) return true;
  // 198.18.0.0/15 benchmarking (RFC 2544).
  if (b[0] == 198 && (b[1] == 18 || b[1] == 19)) return true;
  // RFC 5737 documentation ranges: TEST-NET-1/2/3.
  if (b[0] == 192 && b[1] == 0 && b[2] == 2) return true;
  if (b[0] == 198 && b[1] == 51 && b[2] == 100) return true;
  if (b[0] == 203 && b[1] == 0 && b[2] == 113) return true;
  return false;
}

bool _isPrivateIPv6(List<int> b) {
  if (b.length != 16) return true;
  // IPv4-mapped (::ffff:a.b.c.d) and IPv4-compatible (::a.b.c.d) carry the v4
  // address in the last four bytes; judge those by the v4 rules so a mapped
  // LAN address cannot dodge the filter.
  final prefixIsZero = b.take(10).every((byte) => byte == 0);
  if (prefixIsZero) {
    final mapped = b[10] == 0xff && b[11] == 0xff;
    final compatible = b[10] == 0 && b[11] == 0;
    if (mapped || compatible) return _isPrivateIPv4(b.sublist(12));
  }
  if ((b[0] & 0xfe) == 0xfc) return true; // fc00::/7 unique local
  // fe80::/10 link-local.
  if (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) return true;
  if (b[0] == 0xff) return true; // ff00::/8 multicast
  // 2001:db8::/32 documentation (RFC 3849) — the v6 twin of TEST-NET.
  if (b[0] == 0x20 && b[1] == 0x01 && b[2] == 0x0d && b[3] == 0xb8) return true;
  return false;
}

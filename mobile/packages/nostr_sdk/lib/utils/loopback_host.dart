// ABOUTME: Loopback-host predicate for the local-stack TLS allowance.
// ABOUTME: Bad TLS certificates are tolerated only for these hosts; remote
// ABOUTME: hosts always go through platform certificate validation.

import 'package:flutter/foundation.dart';

/// The hosts the local Docker stack is reachable on (see AGENTS.md,
/// "Local Stack Development"). `10.0.2.2` is the Android emulator's alias
/// for the host machine; `::1` is the IPv6 loopback.
const Set<String> _loopbackHosts = {
  'localhost',
  '127.0.0.1',
  '::1',
  '10.0.2.2',
};

/// Whether [host] is a local-stack loopback host.
///
/// Used to scope `HttpClient.badCertificateCallback`: self-signed
/// certificates are acceptable when developing against the local stack on
/// these hosts, but remote hosts (the divine relay, the funnelcake API)
/// must always pass platform certificate validation.
bool isLoopbackHost(String host) => _loopbackHosts.contains(host.toLowerCase());

/// Whether a bad TLS certificate may be tolerated for [host].
///
/// This is intentionally debug-only. The local-stack production allowance is
/// cleartext (`ws://` / `http://`) loopback, not self-signed TLS.
bool allowsLocalBadCertificateHost(String host) =>
    kDebugMode && isLoopbackHost(host);

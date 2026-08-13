import 'dart:io'
    if (dart.library.js_interop) 'package:openvine/utils/platform_io_web.dart'
    as io;

import 'package:web_socket_channel/web_socket_channel.dart';

/// Prefix `dart:io` gives every DNS resolution failure.
///
/// `dart:io` builds this text itself rather than taking it from the OS:
/// `_NativeSocket.lookup` and `_NativeSocket._resolveHost` both interpolate
/// `"Failed host lookup: '$host'"`. Everything the platform contributes lands
/// in the separate `osError` field, so the prefix does not vary by OS or
/// locale the way an `errno` or a strerror string does.
const _hostLookupFailure = 'Failed host lookup:';

/// Whether [error] is an expected network failure that should not be reported.
///
/// Being offline, sitting behind a captive portal, or running on a network
/// without working DNS is a normal state rather than a defect, which is why
/// the decision matrix in `.claude/rules/error_handling.md` puts "Network /
/// IO (timeout, dropped connection, DNS)" in the not-reportable row. Crash
/// reporters call this to drop such errors; nothing else changes, so the
/// connection retry, the relay state machine, and the UI's own offline
/// handling all still see the failure.
///
/// Both types it inspects are wider than the failure they usually carry, so
/// neither is trusted on type alone:
///
/// * A SocketException counts only when its message is a DNS resolution
///   failure. Every other socket error stays reportable — notably the
///   `Bad file descriptor` raised by a leaked or double-closed descriptor,
///   which is the one signal that would show such a leak.
/// * A WebSocketChannelException is unwrapped instead, because
///   `AdapterWebSocketChannel` wraps *every* connect error in it. Recursing on
///   `inner` keeps a TLS HandshakeException and the ArgumentError from a
///   malformed relay URI reportable; silencing those would mean never
///   connecting to that relay and never hearing why. A wrapper with no `inner`
///   carries nothing to classify and stays expected.
///
/// A connect `TimeoutException` is the one error the wrapper passes through
/// untouched, so it reaches neither branch and is still reported.
///
/// On web the `dart:io` half resolves to a stub whose `SocketException` is
/// never instantiated, so the first check is simply always false there.
bool isExpectedNetworkFailure(Object error) {
  if (error is io.SocketException) {
    return error.message.startsWith(_hostLookupFailure);
  }
  if (error is WebSocketChannelException) {
    final inner = error.inner;
    return inner == null || isExpectedNetworkFailure(inner);
  }
  return false;
}

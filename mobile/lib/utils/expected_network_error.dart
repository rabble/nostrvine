import 'dart:io'
    if (dart.library.js_interop) 'package:openvine/utils/platform_io_web.dart'
    as io;

import 'package:web_socket_channel/web_socket_channel.dart';

/// Whether [error] is an expected network or IO failure.
///
/// Being offline, sitting behind a captive portal, or running on a network
/// without working DNS is a normal state rather than a defect, which is why
/// the decision matrix in `.claude/rules/error_handling.md` puts "Network /
/// IO (timeout, dropped connection, DNS)" in the not-reportable row. Crash
/// reporters call this to drop such errors; nothing else changes, so the
/// connection retry, the relay state machine, and the UI's own offline
/// handling all still see the failure.
///
/// [WebSocketChannelException] counts because it is how the relay transport
/// surfaces a failed handshake: `AdapterWebSocketChannel` wraps every connect
/// error in it, so a check for [io.SocketException] alone would miss every
/// relay connection failure. Note the wrapper is wider than the socket error
/// it usually carries — a TLS or malformed-URI failure arrives as the same
/// type and is dropped with it, while a connect `TimeoutException` is the one
/// error the wrapper passes through untouched and so is still reported.
///
/// On web the `dart:io` half resolves to a stub whose `SocketException` is
/// never instantiated, so the first check is simply always false there.
bool isExpectedNetworkFailure(Object error) =>
    error is io.SocketException || error is WebSocketChannelException;

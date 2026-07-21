// ABOUTME: Platform-specific implementation for non-web platforms (iOS, Android, desktop)
// ABOUTME: Provides access to IOWebSocketChannel and HttpClient for SSL certificate handling

import 'dart:io';
import 'package:nostr_sdk/utils/loopback_host.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Creates a WebSocket channel for non-web platforms.
///
/// Remote hosts go through platform certificate validation; self-signed
/// certificates are tolerated only for local-stack loopback hosts.
WebSocketChannel createSecureWebSocketChannel(Uri wsUrl) {
  final httpClient = HttpClient();
  httpClient.badCertificateCallback = (cert, host, port) =>
      isLoopbackHost(host);

  return IOWebSocketChannel.connect(wsUrl, customClient: httpClient);
}

/// Creates a standard WebSocket channel for non-web platforms
WebSocketChannel createWebSocketChannel(Uri wsUrl) {
  return WebSocketChannel.connect(wsUrl);
}

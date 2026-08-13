import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/utils/expected_network_error.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('isExpectedNetworkFailure', () {
    test('treats a media host lookup failure as expected', () {
      // The signature behind the `dart:_http - _HttpClient.getUrl` and
      // `video_thumbnail_widget.dart - _resolveImageStream` non-fatals.
      const error = SocketException(
        "Failed host lookup: 'media.divine.video' "
        '(OS Error: nodename nor servname provided, or not known, errno = 8)',
      );

      expect(isExpectedNetworkFailure(error), isTrue);
    });

    test('treats a dropped socket as expected', () {
      const error = SocketException(
        'Bad file descriptor (OS Error: Bad file descriptor, errno = 9)',
      );

      expect(isExpectedNetworkFailure(error), isTrue);
    });

    test('treats a failed relay handshake as expected', () {
      // The relay transport wraps the socket error rather than rethrowing it,
      // so a `SocketException` check alone misses every relay DNS failure.
      final error = WebSocketChannelException.from(
        const SocketException("Failed host lookup: 'relay.divine.video'"),
      );

      expect(isExpectedNetworkFailure(error), isTrue);
    });

    test('treats a rejected websocket upgrade as expected', () {
      // A handshake the server answers with a non-101 status is still a
      // transport failure, and the caller already retries.
      final error = WebSocketChannelException(
        "Connection to 'https://relay.divine.video' was not upgraded to "
        'websocket, HTTP status code: 502',
      );

      expect(isExpectedNetworkFailure(error), isTrue);
    });

    test('does not treat a programming-invariant violation as expected', () {
      expect(
        isExpectedNetworkFailure(StateError('No public key available')),
        isFalse,
      );
    });

    test('does not treat a media decode failure as expected', () {
      // A broken image is recoverable but not a network failure — it keeps
      // its existing non-fatal report.
      expect(
        isExpectedNetworkFailure(
          const MediaCacheImageLoadException('https://media.divine.video/x'),
        ),
        isFalse,
      );
    });

    test(
      'does not treat an error that merely mentions sockets as expected',
      () {
        // The classification is by type, so prose about a socket in an
        // unrelated failure must not silence it.
        expect(
          isExpectedNetworkFailure(
            Exception('SocketException while parsing the relay config'),
          ),
          isFalse,
        );
      },
    );
  });
}

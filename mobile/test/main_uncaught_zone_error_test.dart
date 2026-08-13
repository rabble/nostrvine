import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('handleUncaughtZoneError', () {
    late List<({Object error, String? reason})> filed;

    setUp(() => filed = []);

    Future<void> Function(Object, StackTrace, {String? reason}) recorder() {
      return (error, stack, {reason}) async {
        filed.add((error: error, reason: reason));
      };
    }

    test('does not report a relay handshake that failed on DNS', () async {
      // The zone guard is where this lands: nothing catches the failed
      // handshake, so it escapes as an uncaught async error (#7290).
      await app.handleUncaughtZoneError(
        WebSocketChannelException.from(
          const SocketException("Failed host lookup: 'relay.divine.video'"),
        ),
        StackTrace.current,
        recordError: recorder(),
      );

      expect(filed, isEmpty);
    });

    test('does not report a bare socket failure', () async {
      await app.handleUncaughtZoneError(
        const SocketException("Failed host lookup: 'media.divine.video'"),
        StackTrace.current,
        recordError: recorder(),
      );

      expect(filed, isEmpty);
    });

    test('reports a socket failure the app inflicted on itself', () async {
      // Narrowed in review: only a DNS failure is dropped here, so a leaked
      // or double-closed descriptor still reaches Crashlytics (#7310).
      const error = SocketException(
        'OS Error: Bad file descriptor',
        osError: OSError('Bad file descriptor', 9),
      );

      await app.handleUncaughtZoneError(
        error,
        StackTrace.current,
        recordError: recorder(),
      );

      expect(filed, hasLength(1));
      expect(filed.single.error, same(error));
      expect(filed.single.reason, 'runZonedGuarded');
    });

    test('still reports an unexpected error', () async {
      final error = StateError('No public key available');

      await app.handleUncaughtZoneError(
        error,
        StackTrace.current,
        recordError: recorder(),
      );

      expect(filed, hasLength(1));
      expect(filed.single.error, same(error));
      expect(filed.single.reason, 'runZonedGuarded');
    });
  });
}

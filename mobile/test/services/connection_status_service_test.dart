// ABOUTME: Unit tests for ConnectionStatusService.
// ABOUTME: Pins how relay updates drive online state and reconnect callbacks.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/connection_status_service.dart';

void main() {
  group(ConnectionStatusService, () {
    group('lifecycle', () {
      test('completes its status stream on dispose', () async {
        final service = ConnectionStatusService();
        final closed = expectLater(service.statusStream, emitsDone);

        service.dispose();

        await closed;
      });
    });

    group('updateRelayStatus', () {
      test('goes offline when every known relay is disconnected', () {
        final service = ConnectionStatusService();
        addTearDown(service.dispose);

        final emitted = <bool>[];
        service.statusStream.listen(emitted.add);

        service.updateRelayStatus('wss://relay.one', false);

        expect(service.isOnline, isFalse);
        expect(service.connectedRelayCount, isZero);
        expect(service.totalRelayCount, equals(1));
      });

      test('comes back online when any relay reconnects', () {
        final service = ConnectionStatusService();
        addTearDown(service.dispose);

        service
          ..updateRelayStatus('wss://relay.one', false)
          ..updateRelayStatus('wss://relay.two', true);

        expect(service.isOnline, isTrue);
        expect(service.connectedRelayCount, equals(1));
        expect(service.connectionHealth, equals(0.5));
      });

      test('fires reconnect callbacks only on the offline to online edge', () {
        final service = ConnectionStatusService();
        addTearDown(service.dispose);

        var reconnects = 0;
        service.registerOnReconnectCallback(() => reconnects++);

        service.updateRelayStatus('wss://relay.one', false);
        expect(reconnects, isZero, reason: 'going offline is not a reconnect');

        service.updateRelayStatus('wss://relay.one', true);
        expect(reconnects, equals(1));

        service.updateRelayStatus('wss://relay.two', true);
        expect(
          reconnects,
          equals(1),
          reason: 'a second relay joining is not another reconnect',
        );
      });

      test('stops calling a callback once it is unregistered', () {
        final service = ConnectionStatusService();
        addTearDown(service.dispose);

        var reconnects = 0;
        final unregister = service.registerOnReconnectCallback(
          () => reconnects++,
        );

        service.updateRelayStatus('wss://relay.one', false);
        unregister();
        service.updateRelayStatus('wss://relay.one', true);

        expect(reconnects, isZero);
      });
    });
  });
}

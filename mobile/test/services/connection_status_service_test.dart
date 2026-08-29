// ABOUTME: Unit tests for ConnectionStatusService.
// ABOUTME: Pins that it arms no periodic work and that relay updates drive it.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/connection_status_service.dart';

void main() {
  group(ConnectionStatusService, () {
    group('lifecycle', () {
      test('notifies nothing on its own once constructed', () {
        // The constructor used to arm Timer.periodic(30s) -> checkConnection(),
        // which flipped isConnecting true, awaited a 100ms Future.delayed that
        // did no work ("Simulate connection check"), then flipped it back —
        // two notifyListeners() every 30 seconds, forever, from launch. On a
        // debug iOS build that toggle was observed 6 times in 95 seconds
        // across two live instances. PendingActionService listens here and
        // branches on isOnline, so both spurious edges reached
        // syncPendingActions(). Nothing should happen without an input.
        fakeAsync((async) {
          final service = ConnectionStatusService();
          addTearDown(service.dispose);

          var notifications = 0;
          service.addListener(() => notifications++);

          async.elapse(const Duration(minutes: 5));

          expect(notifications, isZero);
          expect(service.isConnecting, isFalse);
        });
      });

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

// ABOUTME: Tests for dmMessageRetryTriggerWithRelayRepair — the connectivity
// ABOUTME: trigger that force-reconnects the relay pool before the DM sweep.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/social_providers.dart';

void main() {
  group('dmMessageRetryTriggerWithRelayRepair', () {
    late StreamController<List<ConnectivityResult>> connectivity;
    late int repairCalls;
    late List<Completer<void>> repairGates;

    setUp(() {
      connectivity = StreamController<List<ConnectivityResult>>();
      repairCalls = 0;
      repairGates = [];
    });

    tearDown(() {
      // Not awaited: the per-test addTearDown cancels the generator's
      // subscription first, and a single-subscription controller with no
      // live listener never completes its close() future — awaiting it
      // hangs the teardown until the suite's per-test timeout.
      unawaited(connectivity.close());
    });

    Future<void> repair() {
      repairCalls++;
      final gate = Completer<void>()..complete();
      repairGates.add(gate);
      return gate.future;
    }

    test('repairs the pool once per real online transition and emits a '
        'trigger for every connectivity event', () async {
      final triggers = <void>[];
      final subscription = dmMessageRetryTriggerWithRelayRepair(
        connectivityChanges: connectivity.stream,
        repairRelayPool: repair,
      ).listen(triggers.add);
      addTearDown(subscription.cancel);

      // First emission is the current state, not a transition: no repair.
      connectivity.add(const [ConnectivityResult.wifi]);
      await pumpEventQueue();
      expect(repairCalls, 0);
      expect(triggers, hasLength(1));

      // Going offline: trigger emitted (offline pass), no repair.
      connectivity.add(const [ConnectivityResult.none]);
      await pumpEventQueue();
      expect(repairCalls, 0);
      expect(triggers, hasLength(2));

      // Back online: repair the zombie sockets BEFORE the sweep trigger.
      connectivity.add(const [ConnectivityResult.wifi]);
      await pumpEventQueue();
      expect(repairCalls, 1);
      expect(triggers, hasLength(3));

      // Duplicate report of the same transports: no repair churn.
      connectivity.add(const [ConnectivityResult.wifi]);
      await pumpEventQueue();
      expect(repairCalls, 1);
      expect(triggers, hasLength(4));

      // Interface handoff (wifi → cellular) breaks sockets too: repair.
      connectivity.add(const [ConnectivityResult.mobile]);
      await pumpEventQueue();
      expect(repairCalls, 2);
      expect(triggers, hasLength(5));
    });

    test('a failing repair still emits the sweep trigger', () async {
      final triggers = <void>[];
      final subscription = dmMessageRetryTriggerWithRelayRepair(
        connectivityChanges: connectivity.stream,
        repairRelayPool: () async => throw StateError('pool gone'),
      ).listen(triggers.add);
      addTearDown(subscription.cancel);

      connectivity.add(const [ConnectivityResult.none]);
      await pumpEventQueue();
      connectivity.add(const [ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(triggers, hasLength(2));
    });
  });
}

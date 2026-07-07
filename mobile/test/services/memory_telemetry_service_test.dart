// ABOUTME: Tests MemoryTelemetryService RSS/peak sampling and snapshot assembly
// ABOUTME: Drives sampleOnce() with injected gauges and asserts the emitted data

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/memory_telemetry_service.dart';

void main() {
  group(MemoryTelemetryService, () {
    late List<MemorySnapshot> emitted;

    setUp(() {
      emitted = <MemorySnapshot>[];
    });

    MemoryTelemetryService build({
      required int Function() readRssBytes,
      int Function() nativeControllerCount = _zero,
      int Function() fvpControllerCount = _zero,
      int Function() queueDepth = _zero,
      Duration interval = const Duration(seconds: 30),
    }) {
      return MemoryTelemetryService(
        readRssBytes: readRssBytes,
        nativeControllerCount: nativeControllerCount,
        fvpControllerCount: fvpControllerCount,
        queueDepth: queueDepth,
        emit: emitted.add,
        interval: interval,
      );
    }

    test('peakRssBytes holds the max across rising then falling rss', () {
      final readings = [100, 300, 200];
      var index = 0;
      final service = build(readRssBytes: () => readings[index++]);

      service
        ..sampleOnce()
        ..sampleOnce()
        ..sampleOnce();

      expect(emitted.map((s) => s.rssBytes), equals([100, 300, 200]));
      expect(emitted.map((s) => s.peakRssBytes), equals([100, 300, 300]));
    });

    test('snapshot carries the injected controller and queue gauges', () {
      final service = build(
        readRssBytes: () => 4242,
        nativeControllerCount: () => 3,
        fvpControllerCount: () => 5,
        queueDepth: () => 7,
      );

      service.sampleOnce();

      expect(emitted, hasLength(1));
      final snapshot = emitted.single;
      expect(snapshot.rssBytes, equals(4242));
      expect(snapshot.peakRssBytes, equals(4242));
      expect(snapshot.nativeControllers, equals(3));
      expect(snapshot.fvpControllers, equals(5));
      expect(snapshot.queueDepth, equals(7));
    });

    test('start samples periodically on the interval', () {
      fakeAsync((async) {
        var rss = 10;
        // Default interval is 30s.
        final service = build(readRssBytes: () => rss++)..start();

        async.elapse(const Duration(seconds: 90));
        service.stop();

        expect(emitted, hasLength(3));
      });
    });

    test('stop is idempotent and halts sampling', () {
      fakeAsync((async) {
        // Default interval is 30s.
        final service = build(readRssBytes: () => 1)..start();

        async.elapse(const Duration(seconds: 30));
        expect(emitted, hasLength(1));

        service
          ..stop()
          ..stop();

        async.elapse(const Duration(seconds: 90));
        expect(emitted, hasLength(1));
      });
    });
  });
}

int _zero() => 0;

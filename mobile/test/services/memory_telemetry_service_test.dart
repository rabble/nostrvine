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
      int Function() readPeakRssBytes = _zero,
      int Function() nativeControllerCount = _zero,
      int Function() queueDepth = _zero,
      int Function() imageCacheBytes = _zero,
      int Function() imageCacheLiveCount = _zero,
      Duration interval = const Duration(seconds: 30),
    }) {
      return MemoryTelemetryService(
        readRssBytes: readRssBytes,
        readPeakRssBytes: readPeakRssBytes,
        nativeControllerCount: nativeControllerCount,
        queueDepth: queueDepth,
        imageCacheBytes: imageCacheBytes,
        imageCacheLiveCount: imageCacheLiveCount,
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

    test('peakRssBytes reports a spike that landed between samples', () {
      // The shape measured on the 1.0.20 report in #8300: every sampled RSS
      // sat near 200 MB while the OS high-water mark was an order of
      // magnitude higher, because the allocation that drives an iOS memory
      // kill is over long before the next 30s tick.
      const mb = 1024 * 1024;
      final sampled = [201 * mb, 229 * mb, 188 * mb];
      var index = 0;
      final service = build(
        readRssBytes: () => sampled[index++],
        readPeakRssBytes: () => 2266 * mb,
      );

      service
        ..sampleOnce()
        ..sampleOnce()
        ..sampleOnce();

      expect(
        emitted.map((s) => s.peakRssBytes),
        everyElement(equals(2266 * mb)),
      );
    });

    test('peakRssBytes stays monotonic when the OS gauge reads lower', () {
      // Web has no OS gauge and reports 0; the sampled max still has to hold.
      final readings = [100, 500, 200];
      var index = 0;
      final service = build(readRssBytes: () => readings[index++]);

      service
        ..sampleOnce()
        ..sampleOnce()
        ..sampleOnce();

      expect(emitted.map((s) => s.peakRssBytes), equals([100, 500, 500]));
    });

    test('peakRssBytes tracks the OS gauge upward between samples', () {
      // Consecutive log lines are what localize a spike to a 30s window, so
      // a rising OS mark has to move the reported peak on the next sample.
      final peaks = [100, 900, 900];
      var index = 0;
      final service = build(
        readRssBytes: () => 100,
        readPeakRssBytes: () => peaks[index++],
      );

      service
        ..sampleOnce()
        ..sampleOnce()
        ..sampleOnce();

      expect(emitted.map((s) => s.rssBytes), equals([100, 100, 100]));
      expect(emitted.map((s) => s.peakRssBytes), equals([100, 900, 900]));
    });

    test('snapshot carries every injected memory gauge', () {
      final service = build(
        readRssBytes: () => 4242,
        nativeControllerCount: () => 3,
        queueDepth: () => 7,
        imageCacheBytes: () => 8,
        imageCacheLiveCount: () => 9,
      );

      service.sampleOnce();

      expect(emitted, hasLength(1));
      final snapshot = emitted.single;
      expect(snapshot.rssBytes, equals(4242));
      expect(snapshot.peakRssBytes, equals(4242));
      expect(snapshot.nativeControllers, equals(3));
      expect(snapshot.queueDepth, equals(7));
      expect(snapshot.imageCacheBytes, equals(8));
      expect(snapshot.imageCacheLiveCount, equals(9));
    });

    test('failed or negative gauges are reported as zero', () {
      final service = build(
        readRssBytes: () => throw StateError('rss unavailable'),
        readPeakRssBytes: () => -1,
        nativeControllerCount: () => -2,
        queueDepth: () => throw StateError('queue unavailable'),
        imageCacheBytes: () => throw StateError('cache unavailable'),
        imageCacheLiveCount: () => -3,
      );

      service
        ..sampleOnce()
        ..sampleOnce();

      expect(emitted, hasLength(2));
      final snapshot = emitted.last;
      expect(snapshot.rssBytes, isZero);
      expect(snapshot.peakRssBytes, isZero);
      expect(snapshot.nativeControllers, isZero);
      expect(snapshot.queueDepth, isZero);
      expect(snapshot.imageCacheBytes, isZero);
      expect(snapshot.imageCacheLiveCount, isZero);
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

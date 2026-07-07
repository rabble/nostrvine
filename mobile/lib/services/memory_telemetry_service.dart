// ABOUTME: Always-on memory gauge sampler (RSS + peak) for OOM instrumentation
// ABOUTME: Reads injected gauges on an interval and emits a MemorySnapshot

import 'dart:async';
import 'dart:math' as math;

/// An immutable point-in-time reading of the app's memory-relevant gauges.
class MemorySnapshot {
  const MemorySnapshot({
    required this.rssBytes,
    required this.peakRssBytes,
    required this.nativeControllers,
    required this.fvpControllers,
    required this.queueDepth,
  });

  /// Resident set size at sample time, in bytes.
  final int rssBytes;

  /// Highest [rssBytes] observed by the sampler so far, in bytes.
  final int peakRssBytes;

  /// Live `divine_video_player` native controllers.
  final int nativeControllers;

  /// Live `video_player`/FVP controllers.
  final int fvpControllers;

  /// Events queued for ingestion across all priorities.
  final int queueDepth;

  @override
  String toString() =>
      'MemorySnapshot(rssBytes: $rssBytes, peakRssBytes: $peakRssBytes, '
      'nativeControllers: $nativeControllers, fvpControllers: $fvpControllers, '
      'queueDepth: $queueDepth)';
}

/// Samples memory-relevant gauges and emits a [MemorySnapshot].
///
/// All inputs are injected as callbacks so the service stays Flutter-free and
/// trivially testable. Production wiring supplies a `readRssBytes` backed by
/// `ProcessInfo.currentRss` and an `emit` that logs and annotates Crashlytics.
class MemoryTelemetryService {
  MemoryTelemetryService({
    required int Function() readRssBytes,
    required int Function() nativeControllerCount,
    required int Function() fvpControllerCount,
    required int Function() queueDepth,
    required void Function(MemorySnapshot) emit,
    this.interval = const Duration(seconds: 30),
  }) : _readRssBytes = readRssBytes,
       _nativeControllerCount = nativeControllerCount,
       _fvpControllerCount = fvpControllerCount,
       _queueDepth = queueDepth,
       _emit = emit;

  final int Function() _readRssBytes;
  final int Function() _nativeControllerCount;
  final int Function() _fvpControllerCount;
  final int Function() _queueDepth;
  final void Function(MemorySnapshot) _emit;

  /// How often [start] samples the gauges.
  final Duration interval;

  Timer? _timer;
  int _peakRssBytes = 0;

  /// Reads every gauge once, updates the running peak, and emits a snapshot.
  void sampleOnce() {
    final rss = _readRssBytes();
    _peakRssBytes = math.max(_peakRssBytes, rss);
    _emit(
      MemorySnapshot(
        rssBytes: rss,
        peakRssBytes: _peakRssBytes,
        nativeControllers: _nativeControllerCount(),
        fvpControllers: _fvpControllerCount(),
        queueDepth: _queueDepth(),
      ),
    );
  }

  /// Begins periodic sampling on [interval]. Safe to call after [stop].
  void start() {
    _timer ??= Timer.periodic(interval, (_) => sampleOnce());
  }

  /// Stops periodic sampling. Idempotent.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

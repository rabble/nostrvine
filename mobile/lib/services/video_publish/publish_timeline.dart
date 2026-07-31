// ABOUTME: Phase-level timing for a single video publish, emitted as
// ABOUTME: greppable PUBTIME log lines so a slow publish can be attributed.

import 'package:unified_logger/unified_logger.dart';

/// Token every timing line carries, so a log export can be reduced to the
/// publish timeline with a single `grep PUBTIME`.
const String publishTimingToken = 'PUBTIME';

/// Logger name every timing line is tagged with. Exported log lines render it
/// as `[PublishTiming]`, which is the second way to filter for these entries.
const String publishTimingLogName = 'PublishTiming';

/// One finished phase of a publish.
typedef PublishPhase = ({String name, Duration elapsed});

/// Emits a single timing line for a phase that has just finished.
///
/// Free function so layers that do not own the [PublishTimeline] (the upload
/// pipeline) can contribute lines to the same filterable stream.
void logPublishPhase(String phase, Duration elapsed, {String? detail}) {
  final suffix = (detail == null || detail.isEmpty) ? '' : ' $detail';
  Log.info(
    '⏱️ $publishTimingToken $phase ${elapsed.inMilliseconds}ms$suffix',
    name: publishTimingLogName,
    category: LogCategory.video,
  );
}

/// Formats a transferred payload as `8.20MB 1.63MB/s` for a timing line.
///
/// Returns an empty string when the size is unknown or zero, and omits the
/// rate when [elapsed] rounds to zero seconds.
String formatTransferDetail(int? bytes, Duration elapsed) {
  if (bytes == null || bytes <= 0) return '';
  final megabytes = bytes / (1024 * 1024);
  final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  if (seconds <= 0) return '${megabytes.toStringAsFixed(2)}MB';
  final rate = megabytes / seconds;
  return '${megabytes.toStringAsFixed(2)}MB ${rate.toStringAsFixed(2)}MB/s';
}

/// Collects the phase durations of one publish and emits a summary line.
///
/// Phases are logged as they finish, so a publish that hangs still leaves the
/// completed phases in the log; the summary adds the total plus an `other`
/// bucket for everything not covered by a measured phase.
class PublishTimeline {
  PublishTimeline(this.draftId);

  /// Draft this publish belongs to — the join key between the timing lines and
  /// the surrounding upload logs.
  final String draftId;

  final Stopwatch _total = Stopwatch()..start();
  final List<PublishPhase> _phases = <PublishPhase>[];

  /// Phases recorded so far, in completion order.
  List<PublishPhase> get phases => List.unmodifiable(_phases);

  /// Wall-clock time since this timeline was created.
  Duration get total => _total.elapsed;

  /// Runs [action], recording its duration under [phase].
  ///
  /// The phase is recorded even when [action] throws, so a failed publish is
  /// still attributable; the error propagates unchanged.
  Future<T> measure<T>(String phase, Future<T> Function() action) async {
    final watch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      watch.stop();
      record(phase, watch.elapsed);
    }
  }

  /// Records an already-measured [phase] and logs its line.
  void record(String phase, Duration elapsed) {
    _phases.add((name: phase, elapsed: elapsed));
    logPublishPhase(phase, elapsed);
  }

  /// Builds the one-line summary for a publish that ended with [outcome].
  String summaryLine({required String outcome}) {
    final measured = _phases.fold(
      Duration.zero,
      (sum, phase) => sum + phase.elapsed,
    );
    final elapsed = _total.elapsed;
    final buffer = StringBuffer()
      ..write('⏱️ $publishTimingToken summary draft=$draftId ')
      ..write('outcome=$outcome total=${elapsed.inMilliseconds}ms');
    for (final phase in _phases) {
      buffer.write(' ${phase.name}=${phase.elapsed.inMilliseconds}ms');
    }
    buffer.write(' other=${(elapsed - measured).inMilliseconds}ms');
    return buffer.toString();
  }

  /// Logs [summaryLine] for a publish that ended with [outcome].
  void logSummary({required String outcome}) {
    Log.info(
      summaryLine(outcome: outcome),
      name: publishTimingLogName,
      category: LogCategory.video,
    );
  }
}

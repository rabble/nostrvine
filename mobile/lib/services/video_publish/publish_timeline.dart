// ABOUTME: Phase-level timing for a single video publish, emitted as
// ABOUTME: greppable PUBTIME log lines and as a Firebase Performance trace.

import 'dart:async';

import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Token every timing line carries, so a log export can be reduced to the
/// publish timeline with a single `grep PUBTIME`.
const String publishTimingToken = 'PUBTIME';

/// Logger name every timing line is tagged with. Exported log lines render it
/// as `[PublishTiming]`, which is the second way to filter for these entries.
const String publishTimingLogName = 'PublishTiming';

/// Firebase Performance trace name for one publish, from the first upload byte
/// to the outcome. Sits alongside the existing `video_upload` trace, which
/// covers only the Blossom call and reports it as a single number.
const String publishTraceName = 'video_publish';

/// Phase names shared by the sites that emit them and the metric mapping.
///
/// The upload and Nostr phases are timed where they happen — deep in the
/// upload manager and the event publisher — while the mapping to Firebase
/// metrics lives here, so both ends refer to the same constant.
abstract class PublishPhases {
  static const String upload = 'upload';
  static const String uploadTransfer = 'upload.transfer';
  static const String uploadThumbnail = 'upload.thumbnail';
  static const String mentions = 'mentions';
  static const String subtitles = 'subtitles';
  static const String nostr = 'nostr';
  static const String nostrSign = 'nostr.sign';
  static const String nostrPublish = 'nostr.publish';
  static const String invites = 'invites';

  /// Detail marker on [uploadThumbnail] for the leg that short-circuited on a
  /// thumbnail a previous attempt already put on the CDN.
  static const String reusedDetail = 'reused';
}

/// Firebase metric name per phase. A phase that never ran reports no metric,
/// so an absent metric reads as "did not happen" rather than as zero.
const Map<String, String> _metricByPhase = {
  PublishPhases.upload: 'upload_ms',
  PublishPhases.uploadTransfer: 'transfer_ms',
  PublishPhases.uploadThumbnail: 'thumbnail_ms',
  PublishPhases.mentions: 'mentions_ms',
  PublishPhases.subtitles: 'subtitles_ms',
  PublishPhases.nostr: 'nostr_ms',
  PublishPhases.nostrSign: 'sign_ms',
  PublishPhases.nostrPublish: 'nostr_publish_ms',
  PublishPhases.invites: 'invites_ms',
};

/// Wall-clock metric for the whole publish.
const String publishTotalMetric = 'total_ms';

/// Uploaded video size, so throughput can be derived from [publishTraceName]
/// rather than guessed from a nominal connection speed.
const String publishPayloadMetric = 'payload_bytes';

/// Zone key the ambient [PublishTimeline] is stored under.
const Object _timelineZoneKey = #publishTimeline;

/// One finished phase of a publish.
typedef PublishPhase = ({String name, Duration elapsed});

/// Emits a single timing line for a phase that has just finished, and folds it
/// into the ambient [PublishTimeline] when one is running.
///
/// Free function so layers that do not own the [PublishTimeline] (the upload
/// pipeline) can contribute lines to the same filterable stream.
///
/// Pass [bytes] for a transferred payload; the size and rate are appended to
/// the line and the size is carried into the publish's metrics.
void logPublishPhase(
  String phase,
  Duration elapsed, {
  String? detail,
  int? bytes,
}) {
  _logPhaseLine(
    phase,
    elapsed,
    detail ?? (bytes == null ? null : formatTransferDetail(bytes, elapsed)),
  );
  PublishTimeline.current?._absorb(
    phase,
    elapsed,
    detail: detail,
    bytes: bytes,
  );
}

void _logPhaseLine(String phase, Duration elapsed, String? detail) {
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

/// Collects the phase durations of one publish, emits a summary line, and
/// reports the same breakdown to Firebase Performance.
///
/// Phases are logged as they finish, so a publish that hangs still leaves the
/// completed phases in the log; the summary adds the total plus an `other`
/// bucket for everything not covered by a measured phase.
class PublishTimeline {
  PublishTimeline(this.draftId, {PerformanceTraceMonitor? performanceMonitor})
    : _trace = (performanceMonitor ?? const NoOpPerformanceTraceMonitor())
          .startOperationTrace(publishTraceName);

  /// The timeline of the publish currently running on this call chain, or null
  /// outside a [run].
  static PublishTimeline? get current =>
      Zone.current[_timelineZoneKey] as PublishTimeline?;

  /// Draft this publish belongs to — the join key between the timing lines and
  /// the surrounding upload logs.
  final String draftId;

  final PerformanceTrace _trace;

  final Stopwatch _total = Stopwatch()..start();
  final List<PublishPhase> _phases = <PublishPhase>[];

  /// Every phase heard of, summed per name. Unlike [_phases] this also holds
  /// the nested phases that [logPublishPhase] emits from inside the upload and
  /// Nostr legs, and it adds a retried phase's attempts together.
  final Map<String, Duration> _elapsedByPhase = <String, Duration>{};

  int? _payloadBytes;
  bool _thumbnailReused = false;

  /// Phases recorded so far, in completion order.
  List<PublishPhase> get phases => List.unmodifiable(_phases);

  /// Wall-clock time since this timeline was created.
  Duration get total => _total.elapsed;

  /// Runs [action] with this timeline as the ambient one, so the phases the
  /// upload and Nostr legs emit through [logPublishPhase] land in this
  /// publish's metrics without threading the timeline through every layer in
  /// between. Legs kicked off outside this call chain (a background upload
  /// resumed from a previous session) simply report no metric.
  Future<T> run<T>(Future<T> Function() action) =>
      runZoned<Future<T>>(action, zoneValues: {_timelineZoneKey: this});

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
    _absorb(phase, elapsed);
    _logPhaseLine(phase, elapsed, null);
  }

  /// Folds a phase into the metric breakdown without touching the summary's
  /// top-level phase list.
  void _absorb(String phase, Duration elapsed, {String? detail, int? bytes}) {
    _elapsedByPhase[phase] =
        (_elapsedByPhase[phase] ?? Duration.zero) + elapsed;
    if (bytes != null && bytes > 0 && phase == PublishPhases.uploadTransfer) {
      _payloadBytes = bytes;
    }
    if (phase == PublishPhases.uploadThumbnail &&
        detail == PublishPhases.reusedDetail) {
      _thumbnailReused = true;
    }
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

  /// Ends the timeline: logs the summary line and reports the same breakdown
  /// to Firebase Performance, tagged with [outcome] so a failed or abandoned
  /// publish is distinguishable from one that reached the relay.
  ///
  /// The trace is stopped fire-and-forget, so a publish never waits on a
  /// platform round-trip to return its result.
  void finish({required String outcome}) {
    logSummary(outcome: outcome);

    _total.stop();
    for (final entry in _elapsedByPhase.entries) {
      final metric = _metricByPhase[entry.key];
      if (metric != null) _trace.setMetric(metric, entry.value.inMilliseconds);
    }
    _trace.setMetric(publishTotalMetric, _total.elapsed.inMilliseconds);
    final payloadBytes = _payloadBytes;
    if (payloadBytes != null) {
      _trace.setMetric(publishPayloadMetric, payloadBytes);
    }
    _trace
      ..putAttribute('outcome', outcome)
      ..putAttribute('thumbnail', _thumbnailReused ? 'reused' : 'generated');
    unawaited(_trace.stop());
  }
}

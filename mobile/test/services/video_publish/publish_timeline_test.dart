// ABOUTME: Tests for PublishTimeline — phase capture, summary shape, and the
// ABOUTME: PUBTIME token contract the log-filtering workflow depends on.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_publish/publish_timeline.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  group(PublishTimeline, () {
    late PublishTimeline timeline;

    setUp(() {
      timeline = PublishTimeline('draft-1');
    });

    group('measure', () {
      test('returns the action result and records the phase', () async {
        final result = await timeline.measure('nostr', () async => 42);

        expect(result, equals(42));
        expect(timeline.phases.map((phase) => phase.name), equals(['nostr']));
      });

      test('records the phase and rethrows when the action throws', () async {
        await expectLater(
          timeline.measure<void>('nostr', () async => throw StateError('boom')),
          throwsA(isA<StateError>()),
        );

        expect(timeline.phases.map((phase) => phase.name), equals(['nostr']));
      });

      test('keeps phases in completion order', () async {
        await timeline.measure('upload', () async {});
        await timeline.measure('nostr', () async {});

        expect(
          timeline.phases.map((phase) => phase.name),
          equals(['upload', 'nostr']),
        );
      });
    });

    group('summaryLine', () {
      test('carries the filter token, draft, outcome and every phase', () {
        timeline
          ..record('upload', const Duration(milliseconds: 900))
          ..record('nostr', const Duration(milliseconds: 120));

        final summary = timeline.summaryLine(outcome: 'success');

        expect(summary, contains(publishTimingToken));
        expect(summary, contains('draft=draft-1'));
        expect(summary, contains('outcome=success'));
        expect(summary, contains('upload=900ms'));
        expect(summary, contains('nostr=120ms'));
        expect(summary, contains('other='));
      });

      test('reports a total even when no phase was recorded', () {
        final summary = timeline.summaryLine(outcome: 'threw');

        expect(summary, contains('outcome=threw'));
        expect(summary, contains('total='));
      });
    });
  });

  group('logPublishPhase', () {
    test('emits one filterable line carrying phase, duration and detail', () {
      logPublishPhase(
        'upload.transfer',
        const Duration(milliseconds: 5231),
        detail: '8.00MB 1.53MB/s',
      );

      final captured = LogCaptureService().getRecentLogs(limit: 1).single;

      expect(captured.name, equals(publishTimingLogName));
      expect(captured.category, equals(LogCategory.video));
      expect(captured.message, contains(publishTimingToken));
      expect(captured.message, contains('upload.transfer'));
      expect(captured.message, contains('5231ms'));
      expect(captured.message, contains('8.00MB 1.53MB/s'));
    });
  });

  group('formatTransferDetail', () {
    test('reports size and rate for a measured transfer', () {
      final detail = formatTransferDetail(
        8 * 1024 * 1024,
        const Duration(seconds: 4),
      );

      expect(detail, equals('8.00MB 2.00MB/s'));
    });

    test('omits the rate when the transfer took no measurable time', () {
      final detail = formatTransferDetail(2 * 1024 * 1024, Duration.zero);

      expect(detail, equals('2.00MB'));
    });

    test('returns nothing when the size is unknown or empty', () {
      expect(formatTransferDetail(null, const Duration(seconds: 1)), isEmpty);
      expect(formatTransferDetail(0, const Duration(seconds: 1)), isEmpty);
    });
  });
}

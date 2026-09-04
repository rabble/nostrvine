// ABOUTME: Tests final-export timeout, cancellation, and failure reporting
// ABOUTME: Keeps a stalled native export from surviving beside its retry

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:openvine/services/video_editor/video_render_watchdog.dart';

void main() {
  group('VideoRenderWatchdog.run', () {
    tearDown(() => VideoRenderWatchdog.crashReporterOverride = null);

    test('times out, cancels, reports, and observes a stalled export', () {
      fakeAsync((async) {
        final hung = Completer<void>();
        Object? failure;
        Object? reportedFailure;
        String? cancelledTaskId;
        VideoRenderWatchdog.crashReporterOverride = (error, stackTrace) =>
            reportedFailure = error;

        VideoRenderWatchdog.run<void>(
          render: hung.future,
          taskId: 'stalled-final-export',
          cancelTask: (taskId) async => cancelledTaskId = taskId,
        ).then<void>(
          (_) => fail('the stalled export must not complete successfully'),
          onError: (Object error, StackTrace stackTrace) => failure = error,
        );

        async.elapse(VideoEditorConstants.renderWatchdogTimeout);
        async.flushMicrotasks();

        expect(
          failure,
          isA<VideoRenderFailedException>().having(
            (error) => error.reason,
            'reason',
            VideoRenderFailureReason.timedOut,
          ),
        );
        expect(cancelledTaskId, 'stalled-final-export');
        expect(reportedFailure, same(failure));

        hung.completeError(Exception('late native failure'));
        async.flushMicrotasks();
      });
    });
  });
}

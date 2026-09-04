// ABOUTME: Bounds final video exports and cancels work that stops responding
// ABOUTME: Reports terminal export failures without coupling callers to Firebase

import 'dart:async';

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:unified_logger/unified_logger.dart';

/// Owns the liveness bound and failure reporting for final video exports.
class VideoRenderWatchdog {
  VideoRenderWatchdog._();

  static void Function(Object error, StackTrace stackTrace)?
  crashReporterOverride;

  /// Returns [render]'s result, or a classified failure when it stops settling.
  static Future<T> run<T>({
    required Future<T> render,
    required String? taskId,
    required Future<void> Function(String taskId) cancelTask,
  }) {
    return render.timeout(
      VideoEditorConstants.renderWatchdogTimeout,
      onTimeout: () {
        const failure = VideoRenderFailedException(
          VideoRenderFailureReason.timedOut,
        );
        reportFailure(failure, StackTrace.current, reportEveryFailure: true);
        if (taskId != null) {
          unawaited(_cancelAndObserve(render, taskId, cancelTask));
        }
        throw failure;
      },
    );
  }

  /// Reports failures that the caller classifies as operationally significant.
  ///
  /// Final exports report every failure because they are a user dead end and
  /// native failures commonly arrive as non-[Error] platform exceptions. Other
  /// render callers report only programming-invariant failures because their
  /// fallback paths may retry frequently (#7125).
  static void reportFailure(
    Object error,
    StackTrace stackTrace, {
    required bool reportEveryFailure,
  }) {
    if (!reportEveryFailure && error is! Error) return;
    final override = crashReporterOverride;
    if (override != null) {
      override(error, stackTrace);
      return;
    }
    CrashReportingService.instance.recordError(
      error,
      stackTrace,
      reason: 'renderVideo failed',
    );
  }

  static Future<void> _cancelAndObserve<T>(
    Future<T> render,
    String taskId,
    Future<void> Function(String taskId) cancelTask,
  ) async {
    await cancelTask(taskId);
    try {
      await render;
    } catch (error) {
      Log.debug(
        'Stalled render settled after the watchdog gave up: $error',
        name: 'VideoRenderWatchdog',
        category: LogCategory.video,
      );
    }
  }
}

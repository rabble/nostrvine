// ABOUTME: Backend-agnostic port for reporting one HTTP request's timing.
// ABOUTME: Implemented over Firebase Performance in the app, faked in tests.

/// One in-flight HTTP request's performance span.
///
/// The span times the whole request — from just before the client sends it
/// until the response body finishes, fails, or is cancelled.
abstract class HttpMetricSpan {
  /// Records the request body size in bytes, when the client knows it.
  void setRequestPayloadSize(int bytes);

  /// Records the outcome and ends the span. Idempotent: later calls are
  /// ignored, so a stream that both errors and is cancelled reports once.
  ///
  /// A null [statusCode] means the request never produced a response (DNS
  /// failure, timeout, connection reset). Implementations still end the span
  /// so the backend does not leak a native handle.
  void complete({
    int? statusCode,
    int? responsePayloadSize,
    String? responseContentType,
  });
}

/// Opens [HttpMetricSpan]s for outgoing HTTP requests.
abstract class HttpMetricRecorder {
  /// Opens a span for a [method] request reported as [urlPattern], or returns
  /// null when this request is not being recorded (monitoring disabled, an
  /// unsupported verb, or the backend refused the metric).
  HttpMetricSpan? start({required String urlPattern, required String method});
}

/// Records nothing. The default wherever no backend is wired — tests, and
/// any build where performance monitoring never initialised.
class NoOpHttpMetricRecorder implements HttpMetricRecorder {
  const NoOpHttpMetricRecorder();

  @override
  HttpMetricSpan? start({
    required String urlPattern,
    required String method,
  }) => null;
}

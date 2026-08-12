// ABOUTME: http.Client decorator that reports Divine-host requests as
// ABOUTME: Firebase Performance network requests, one metric per request.

import 'package:http/http.dart' as http;
import 'package:openvine/observability/network/http_metric_recorder.dart';
import 'package:openvine/observability/network/http_url_pattern.dart';

/// Wraps an [http.Client] and reports every request it sends to a
/// Divine-operated host (see [isInstrumentedHost]) to [HttpMetricRecorder].
///
/// One instrumentation point for the whole Dart HTTP surface: wire this in
/// where a client is constructed and every call the owning client makes is
/// covered, with no per-call-site bookkeeping.
///
/// The span ends when the response body ends — completed, failed, or the
/// subscription cancelled — so the reported duration covers the transfer, not
/// just time to first byte. A caller that takes a [http.StreamedResponse] and
/// never listens to its stream leaves the span open; that already leaks the
/// underlying connection, so it is a bug at the call site rather than
/// something this client papers over.
class PerformanceHttpClient extends http.BaseClient {
  PerformanceHttpClient({
    required http.Client inner,
    required HttpMetricRecorder recorder,
  }) : _inner = inner,
       _recorder = recorder;

  final http.Client _inner;
  final HttpMetricRecorder _recorder;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!isInstrumentedHost(request.url.host)) {
      return _inner.send(request);
    }

    final span = _recorder.start(
      urlPattern: httpMetricUrlPattern(request.url),
      method: request.method,
    );
    if (span == null) return _inner.send(request);

    final requestPayloadSize = request.contentLength;
    if (requestPayloadSize != null) {
      span.setRequestPayloadSize(requestPayloadSize);
    }

    final http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (_) {
      span.complete();
      rethrow;
    }

    return http.StreamedResponse(
      _trackBody(response, span),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Stream<List<int>> _trackBody(
    http.StreamedResponse response,
    HttpMetricSpan span,
  ) async* {
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        yield chunk;
      }
    } finally {
      span.complete(
        statusCode: response.statusCode,
        responsePayloadSize: received,
        responseContentType: response.headers['content-type'],
      );
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

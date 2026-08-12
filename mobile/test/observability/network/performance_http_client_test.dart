// ABOUTME: Tests the http.Client decorator that opens a metric per request.
// ABOUTME: Covers host filtering, payload sizes, failures and cancellation.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/observability/network/http_metric_recorder.dart';
import 'package:openvine/observability/network/performance_http_client.dart';

class _RecordedSpan implements HttpMetricSpan {
  _RecordedSpan(this.urlPattern, this.method);

  final String urlPattern;
  final String method;

  int? requestPayloadSize;
  int? statusCode;
  int? responsePayloadSize;
  String? responseContentType;
  int completions = 0;

  bool get isCompleted => completions > 0;

  @override
  void setRequestPayloadSize(int bytes) => requestPayloadSize = bytes;

  @override
  void complete({
    int? statusCode,
    int? responsePayloadSize,
    String? responseContentType,
  }) {
    completions++;
    if (completions > 1) return;
    this.statusCode = statusCode;
    this.responsePayloadSize = responsePayloadSize;
    this.responseContentType = responseContentType;
  }
}

class _FakeRecorder implements HttpMetricRecorder {
  _FakeRecorder({this.enabled = true});

  final bool enabled;
  final List<_RecordedSpan> spans = [];

  _RecordedSpan get only => spans.single;

  @override
  HttpMetricSpan? start({required String urlPattern, required String method}) {
    if (!enabled) return null;
    final span = _RecordedSpan(urlPattern, method);
    spans.add(span);
    return span;
  }
}

/// Inner client under the decorator: answers with a caller-supplied stream (or
/// error) and records what it was asked to send.
class _FakeInnerClient extends http.BaseClient {
  _FakeInnerClient({
    this.responder,
    this.error,
    this.headers = const {'content-type': 'application/json'},
    this.statusCode = 200,
  });

  final Stream<List<int>> Function()? responder;
  final Object? error;
  final Map<String, String> headers;
  final int statusCode;

  final List<http.BaseRequest> sent = [];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request);
    final failure = error;
    if (failure != null) throw failure;
    final body =
        responder?.call() ??
        Stream<List<int>>.fromIterable([utf8.encode('{}')]);
    return http.StreamedResponse(
      body,
      statusCode,
      request: request,
      headers: headers,
      reasonPhrase: 'OK',
    );
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  group(PerformanceHttpClient, () {
    late _FakeRecorder recorder;

    setUp(() {
      recorder = _FakeRecorder();
    });

    test('reports the route pattern and method for a Divine host', () async {
      final client = PerformanceHttpClient(
        inner: _FakeInnerClient(),
        recorder: recorder,
      );
      addTearDown(client.close);

      await client.get(
        Uri.parse(
          'https://api.divine.video/api/videos/'
          'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90'
          '/stats?limit=5',
        ),
      );

      expect(
        recorder.only.urlPattern,
        'https://api.divine.video/api/videos/:id/stats',
      );
      expect(recorder.only.method, 'GET');
    });

    test('records status, content type and transferred sizes', () async {
      final client = PerformanceHttpClient(
        inner: _FakeInnerClient(
          responder: () => Stream<List<int>>.fromIterable([
            utf8.encode('{"videos":'),
            utf8.encode('[]}'),
          ]),
        ),
        recorder: recorder,
      );
      addTearDown(client.close);

      final response = await client.post(
        Uri.parse('https://api.divine.video/api/events'),
        body: '{"kind":34236}',
      );

      expect(response.body, '{"videos":[]}');
      final span = recorder.only;
      expect(span.statusCode, 200);
      expect(span.requestPayloadSize, 14);
      expect(span.responsePayloadSize, 13);
      expect(span.responseContentType, 'application/json');
    });

    test('records an error status, and tolerates no content type', () async {
      final client = PerformanceHttpClient(
        inner: _FakeInnerClient(statusCode: 404, headers: const {}),
        recorder: recorder,
      );
      addTearDown(client.close);

      await client.get(Uri.parse('https://api.divine.video/api/videos'));

      final span = recorder.only;
      expect(span.statusCode, 404);
      expect(span.responseContentType, isNull);
    });

    test('does not report requests to third-party hosts', () async {
      final inner = _FakeInnerClient();
      final client = PerformanceHttpClient(inner: inner, recorder: recorder);
      addTearDown(client.close);

      await client.get(Uri.parse('https://api.github.com/repos/divine/app'));

      expect(recorder.spans, isEmpty);
      expect(inner.sent, hasLength(1));
    });

    test('still sends the request when the recorder declines it', () async {
      final inner = _FakeInnerClient();
      final client = PerformanceHttpClient(
        inner: inner,
        recorder: _FakeRecorder(enabled: false),
      );
      addTearDown(client.close);

      final response = await client.get(
        Uri.parse('https://api.divine.video/api/videos'),
      );

      expect(response.statusCode, 200);
      expect(inner.sent, hasLength(1));
    });

    test('completes the span without a status when the send fails', () async {
      final client = PerformanceHttpClient(
        inner: _FakeInnerClient(error: http.ClientException('offline')),
        recorder: recorder,
      );
      addTearDown(client.close);

      await expectLater(
        client.get(Uri.parse('https://api.divine.video/api/videos')),
        throwsA(isA<http.ClientException>()),
      );

      final span = recorder.only;
      expect(span.isCompleted, isTrue);
      expect(span.statusCode, isNull);
    });

    test(
      'completes the span when the response body errors mid-stream',
      () async {
        final client = PerformanceHttpClient(
          inner: _FakeInnerClient(
            responder: () => Stream<List<int>>.fromIterable([
              utf8.encode('partial'),
            ]).followedBy(Stream.error(http.ClientException('reset'))),
          ),
          recorder: recorder,
        );
        addTearDown(client.close);

        final response = await client.send(
          http.Request('GET', Uri.parse('https://media.divine.video/abc')),
        );

        await expectLater(
          response.stream.drain<void>(),
          throwsA(isA<http.ClientException>()),
        );
        expect(recorder.only.isCompleted, isTrue);
      },
    );

    test('completes the span once when the body is cancelled', () async {
      final client = PerformanceHttpClient(
        inner: _FakeInnerClient(
          responder: () => Stream<List<int>>.periodic(
            const Duration(milliseconds: 5),
            (_) => utf8.encode('chunk'),
          ),
        ),
        recorder: recorder,
      );
      addTearDown(client.close);

      final response = await client.send(
        http.Request('GET', Uri.parse('https://media.divine.video/abc.mp4')),
      );
      final subscription = response.stream.listen(null);
      await subscription.cancel();

      expect(recorder.only.completions, 1);
    });

    test('closing the wrapper closes the client it wraps', () {
      final inner = _FakeInnerClient();

      PerformanceHttpClient(inner: inner, recorder: recorder).close();

      expect(inner.closed, isTrue);
    });
  });
}

extension _FollowedBy on Stream<List<int>> {
  Stream<List<int>> followedBy(Stream<List<int>> next) async* {
    yield* this;
    yield* next;
  }
}

// ABOUTME: Tests the Firebase-backed HttpMetricRecorder implementation.
// ABOUTME: Method mapping, the start/stop race guard, and disabled behaviour.

import 'dart:async';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/network/firebase_http_metric_recorder.dart';

/// Stands in for a platform-backed [HttpMetric].
class _FakeHttpMetric implements HttpMetric {
  _FakeHttpMetric({Completer<void>? startGate}) : _startGate = startGate;

  final Completer<void>? _startGate;

  int startCalls = 0;
  int stopCalls = 0;

  @override
  int? httpResponseCode;

  @override
  int? requestPayloadSize;

  @override
  int? responsePayloadSize;

  @override
  String? responseContentType;

  @override
  Future<void> start() {
    startCalls++;
    return _startGate?.future ?? Future<void>.value();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  final Map<String, String> _attributes = {};

  @override
  void putAttribute(String name, String value) => _attributes[name] = value;

  @override
  void removeAttribute(String name) => _attributes.remove(name);

  @override
  String? getAttribute(String name) => _attributes[name];

  @override
  Map<String, String> getAttributes() => Map.of(_attributes);
}

void main() {
  group(FirebaseHttpMetricRecorder, () {
    late List<(String, HttpMethod)> created;
    late _FakeHttpMetric metric;

    FirebaseHttpMetricRecorder buildRecorder({
      bool enabled = true,
      _FakeHttpMetric? withMetric,
      Object? factoryError,
    }) {
      metric = withMetric ?? _FakeHttpMetric();
      return FirebaseHttpMetricRecorder(
        isEnabled: () => enabled,
        newHttpMetric: (url, httpMethod) {
          created.add((url, httpMethod));
          if (factoryError != null) throw factoryError;
          return metric;
        },
      );
    }

    setUp(() {
      created = [];
    });

    test('opens and starts a metric for the reported pattern', () {
      final recorder = buildRecorder();

      final span = recorder.start(
        urlPattern: 'https://api.divine.video/api/videos',
        method: 'get',
      );

      expect(span, isNotNull);
      expect(created, [
        ('https://api.divine.video/api/videos', HttpMethod.Get),
      ]);
      expect(metric.startCalls, 1);
    });

    test('maps every HTTP verb the API accepts', () {
      final recorder = buildRecorder();

      for (final method in [
        'CONNECT',
        'DELETE',
        'GET',
        'HEAD',
        'OPTIONS',
        'PATCH',
        'POST',
        'PUT',
        'TRACE',
      ]) {
        recorder.start(
          urlPattern: 'https://api.divine.video/x',
          method: method,
        );
      }

      expect(created.map((entry) => entry.$2), [
        HttpMethod.Connect,
        HttpMethod.Delete,
        HttpMethod.Get,
        HttpMethod.Head,
        HttpMethod.Options,
        HttpMethod.Patch,
        HttpMethod.Post,
        HttpMethod.Put,
        HttpMethod.Trace,
      ]);
    });

    test('declines an unsupported verb instead of guessing one', () {
      final recorder = buildRecorder();

      final span = recorder.start(
        urlPattern: 'https://api.divine.video/x',
        method: 'PROPFIND',
      );

      expect(span, isNull);
      expect(created, isEmpty);
    });

    test('records nothing until monitoring has initialised', () {
      final recorder = buildRecorder(enabled: false);

      final span = recorder.start(
        urlPattern: 'https://api.divine.video/api/videos',
        method: 'GET',
      );

      expect(span, isNull);
      expect(created, isEmpty);
    });

    test('declines rather than throwing when the metric cannot be made', () {
      final recorder = buildRecorder(factoryError: StateError('no app'));

      final span = recorder.start(
        urlPattern: 'https://api.divine.video/api/videos',
        method: 'GET',
      );

      expect(span, isNull);
    });

    test('writes the outcome onto the metric before stopping it', () async {
      final recorder = buildRecorder();
      final span = recorder.start(
        urlPattern: 'https://api.divine.video/api/events',
        method: 'POST',
      )!;

      span.setRequestPayloadSize(128);
      span.complete(
        statusCode: 201,
        responsePayloadSize: 64,
        responseContentType: 'application/json',
      );
      await pumpEventQueue();

      expect(metric.requestPayloadSize, 128);
      expect(metric.httpResponseCode, 201);
      expect(metric.responsePayloadSize, 64);
      expect(metric.responseContentType, 'application/json');
      expect(metric.stopCalls, 1);
    });

    test('waits for the start round-trip before stopping', () async {
      final startGate = Completer<void>();
      final recorder = buildRecorder(
        withMetric: _FakeHttpMetric(startGate: startGate),
      );
      final span = recorder.start(
        urlPattern: 'https://api.divine.video/api/videos',
        method: 'GET',
      )!;

      // A cache hit can finish before the platform hands back a handle; the
      // plugin drops a stop that arrives first and leaks the native metric.
      span.complete(statusCode: 304);
      await pumpEventQueue();
      expect(metric.stopCalls, 0);

      startGate.complete();
      await pumpEventQueue();
      expect(metric.stopCalls, 1);
    });

    test('stops once even when completed repeatedly', () async {
      final recorder = buildRecorder();
      final span = recorder.start(
        urlPattern: 'https://api.divine.video/api/videos',
        method: 'GET',
      )!;

      span.complete(statusCode: 200, responsePayloadSize: 10);
      span.complete(statusCode: 500, responsePayloadSize: 20);
      await pumpEventQueue();

      expect(metric.stopCalls, 1);
      expect(metric.httpResponseCode, 200);
      expect(metric.responsePayloadSize, 10);
    });

    test('ignores a payload size reported after completion', () async {
      final recorder = buildRecorder();
      final span = recorder.start(
        urlPattern: 'https://api.divine.video/api/videos',
        method: 'GET',
      )!;

      span.complete(statusCode: 200);
      span.setRequestPayloadSize(999);
      await pumpEventQueue();

      expect(metric.requestPayloadSize, isNull);
    });
  });
}

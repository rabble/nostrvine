// ABOUTME: Tests the `outcome` attribute tagged on the video_upload trace
// ABOUTME: for every terminal path of the in-process and OS-background uploads

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthProvider extends Mock implements BlossomAuthProvider {}

class _MockDio extends Mock implements Dio {}

/// Records every attribute put on a trace, keyed by trace name, so a test can
/// assert what the console would receive.
class _RecordingPerformanceMonitor implements BlossomPerformanceMonitor {
  final List<({String trace, String attribute, String value})> attributes = [];
  final List<String> stopped = [];

  /// Attributes that arrived after their trace was already reported. Firebase
  /// silently drops these, so any entry here is a bug the tests must catch.
  final List<String> lateAttributes = [];

  /// The `outcome` values tagged on the `video_upload` trace, in order.
  List<String> get uploadOutcomes => attributes
      .where((a) => a.trace == 'video_upload' && a.attribute == 'outcome')
      .map((a) => a.value)
      .toList();

  @override
  Future<void> startTrace(String traceName) async {}

  @override
  Future<void> stopTrace(String traceName) async => stopped.add(traceName);

  @override
  void setMetric(String traceName, String metricName, int value) {}

  @override
  void putAttribute(String traceName, String attribute, String value) {
    if (stopped.contains(traceName)) {
      lateAttributes.add('$traceName.$attribute');
    }
    attributes.add((trace: traceName, attribute: attribute, value: value));
  }
}

/// Emits [emitOnEnqueue] from inside [enqueue], after the service subscribed,
/// so a terminal event that lands during hand-off is never missed by a race.
class _FakeTransport implements BlossomBackgroundTransport {
  _FakeTransport({
    this.emitOnEnqueue = const [],
    this.throwOnEnqueue = false,
    this.bufferedTerminal,
  });

  final List<BlossomBackgroundTransferEvent> emitOnEnqueue;
  final bool throwOnEnqueue;
  final BlossomBackgroundTransferEvent? bufferedTerminal;

  final StreamController<BlossomBackgroundTransferEvent> _controller =
      StreamController<BlossomBackgroundTransferEvent>.broadcast();

  @override
  Stream<BlossomBackgroundTransferEvent> get events => _controller.stream;

  /// Delivers [event] after hand-off, the way the OS reports a transfer that
  /// was still running when [enqueue] returned.
  void emit(BlossomBackgroundTransferEvent event) => _controller.add(event);

  @override
  Future<void> enqueue({
    required String taskId,
    required String url,
    required String method,
    required Map<String, String> headers,
    required String filePath,
  }) async {
    if (throwOnEnqueue) throw Exception('enqueue failed');
    emitOnEnqueue.forEach(_controller.add);
  }

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<BlossomBackgroundTransferEvent?> takeBufferedTerminalEvent(
    String taskId,
  ) async => bufferedTerminal;
}

const _server = 'https://media.divine.video';
const _taskId = 'upload-1';
const _publicKey =
    '0223456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockAuthProvider auth;
  late _MockDio dio;
  late _RecordingPerformanceMonitor monitor;
  late Directory tempDir;
  late File videoFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    auth = _MockAuthProvider();
    dio = _MockDio();
    monitor = _RecordingPerformanceMonitor();

    when(() => auth.isAuthenticated).thenReturn(true);
    when(
      () => auth.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer(
      (_) async => const BlossomSignedEvent(
        json: <String, dynamic>{
          'id': 'test_id',
          'pubkey': _publicKey,
          'created_at': 0,
          'kind': 24242,
          'tags': <dynamic>[],
          'content': 'Upload video to Blossom server',
          'sig': 'test_sig',
        },
      ),
    );

    tempDir = await Directory.systemTemp.createTemp('blossom_outcome_test_');
    videoFile = File('${tempDir.path}/video.mp4')
      ..writeAsBytesSync(List<int>.generate(8, (i) => i));
  });

  tearDown(() async => tempDir.delete(recursive: true));

  BlossomUploadService service({BlossomBackgroundTransport? transport}) =>
      BlossomUploadService(
        authProvider: auth,
        dio: dio,
        defaultServerUrl: _server,
        backgroundTransport: transport,
        performanceMonitor: monitor,
      );

  /// Stubs the legacy whole-file PUT path: capability discovery reports no
  /// resumable support, then the blob PUT answers with [statusCode].
  void stubLegacyPut({required int statusCode}) {
    when(
      () => dio.head<dynamic>(any(), options: any(named: 'options')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/upload'),
        statusCode: 200,
        headers: Headers(),
      ),
    );
    when(
      () => dio.put<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
        onSendProgress: any(named: 'onSendProgress'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/upload'),
        statusCode: statusCode,
        headers: Headers(),
        data: const <String, dynamic>{'url': '$_server/blob', 'size': 8},
      ),
    );
  }

  Future<BlossomUploadResult> upload(BlossomUploadService s) => s.uploadVideo(
    videoFile: videoFile,
    nostrPubkey: _publicKey,
    title: 'Test Video',
    description: null,
    hashtags: null,
    proofManifestJson: null,
  );

  group('uploadVideo outcome attribute', () {
    test('tags success when the blob reaches the server', () async {
      stubLegacyPut(statusCode: 200);

      final result = await upload(service());

      expect(result.errorMessage, isNull);
      expect(result.success, isTrue);
      expect(monitor.uploadOutcomes, ['success']);
    });

    test('tags error:<reason> when every server rejects the blob', () async {
      stubLegacyPut(statusCode: 500);

      final result = await upload(service());

      expect(result.success, isFalse);
      expect(monitor.uploadOutcomes, ['error:server']);
    });

    test('tags error:auth when the user is not signed in', () async {
      when(() => auth.isAuthenticated).thenReturn(false);

      final result = await upload(service());

      expect(result.success, isFalse);
      expect(monitor.uploadOutcomes, ['error:auth']);
    });

    test('tags the outcome before the trace is stopped', () async {
      stubLegacyPut(statusCode: 200);

      await upload(service());

      expect(monitor.stopped, ['video_upload']);
      expect(monitor.lateAttributes, isEmpty);
    });
  });

  group('uploadVideoInBackground outcome attribute', () {
    BlossomBackgroundTransferEvent event(
      BlossomBackgroundTransferStatus status, {
      int? httpStatusCode,
    }) => BlossomBackgroundTransferEvent(
      taskId: _taskId,
      status: status,
      httpStatusCode: httpStatusCode,
    );

    Future<BlossomUploadResult> background(BlossomUploadService s) =>
        s.uploadVideoInBackground(
          videoFile: videoFile,
          taskId: _taskId,
          proofManifestJson: null,
        );

    test('tags enqueued once the OS owns the still-running transfer', () async {
      final transport = _FakeTransport(
        emitOnEnqueue: [event(BlossomBackgroundTransferStatus.running)],
      );

      final future = background(service(transport: transport));
      // The transfer has not reached a terminal state, so the trace can only
      // claim the hand-off it actually measured.
      await pumpEventQueue();
      expect(monitor.uploadOutcomes, ['enqueued']);

      transport.emit(
        event(BlossomBackgroundTransferStatus.completed, httpStatusCode: 200),
      );
      expect((await future).success, isTrue);
    });

    test('tags cancelled when the user stops the transfer', () async {
      final transport = _FakeTransport(
        emitOnEnqueue: [event(BlossomBackgroundTransferStatus.cancelled)],
      );

      final result = await background(service(transport: transport));

      expect(result.failureReason, BlossomUploadFailureReason.cancelled);
      expect(monitor.uploadOutcomes, ['cancelled']);
    });

    test(
      'tags error:<reason> when the transfer fails during hand-off',
      () async {
        final transport = _FakeTransport(
          emitOnEnqueue: [
            event(BlossomBackgroundTransferStatus.failed, httpStatusCode: 500),
          ],
        );

        final result = await background(service(transport: transport));

        expect(result.success, isFalse);
        expect(monitor.uploadOutcomes, ['error:server']);
      },
    );

    test('tags error:authUnavailable when the signer is unreachable', () async {
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => null);

      final result = await background(service(transport: _FakeTransport()));

      expect(
        result.failureReason,
        BlossomUploadFailureReason.authUnavailable,
      );
      expect(monitor.uploadOutcomes, ['error:authUnavailable']);
    });

    test('tags error:<reason> when the transfer cannot be enqueued', () async {
      final transport = _FakeTransport(throwOnEnqueue: true);

      final result = await background(service(transport: transport));

      expect(result.success, isFalse);
      expect(monitor.uploadOutcomes, ['error:unknown']);
    });

    test('tags success when a buffered terminal event is claimed', () async {
      final transport = _FakeTransport(
        bufferedTerminal: event(
          BlossomBackgroundTransferStatus.completed,
          httpStatusCode: 200,
        ),
      );

      final result = await background(service(transport: transport));

      expect(result.success, isTrue);
      expect(monitor.uploadOutcomes, ['success']);
    });

    test('tags threw when setup throws before any result exists', () async {
      // A missing file makes the streaming hash throw, which no catch inside
      // uploadVideoInBackground converts into a result.
      await videoFile.delete();

      await expectLater(
        background(service(transport: _FakeTransport())),
        throwsA(isA<Object>()),
      );

      expect(monitor.uploadOutcomes, ['threw']);
    });

    test('tags the trace exactly once across both stop sites', () async {
      final transport = _FakeTransport(
        emitOnEnqueue: [
          event(BlossomBackgroundTransferStatus.completed, httpStatusCode: 200),
        ],
      );

      await background(service(transport: transport));

      // stopTraceOnce runs after enqueue and again in the outer finally; the
      // second call must not report a duplicate trace or re-tag it.
      expect(monitor.stopped, ['video_upload']);
      expect(monitor.uploadOutcomes, hasLength(1));
      expect(monitor.lateAttributes, isEmpty);
    });
  });

  group('NoOpPerformanceMonitor', () {
    test('accepts attributes without a monitor configured', () async {
      stubLegacyPut(statusCode: 200);

      final result =
          await BlossomUploadService(
            authProvider: auth,
            dio: dio,
            defaultServerUrl: _server,
          ).uploadVideo(
            videoFile: videoFile,
            nostrPubkey: _publicKey,
            title: 'Test Video',
            description: null,
            hashtags: null,
            proofManifestJson: null,
          );

      expect(result.success, isTrue);
    });
  });
}

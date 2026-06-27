import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthProvider extends Mock implements BlossomAuthProvider {}

/// Emits [emitOnEnqueue] as soon as [enqueue] is called, after the service has
/// already subscribed — so the terminal event is never missed by a race.
class _FakeTransport implements BlossomBackgroundTransport {
  _FakeTransport({this.emitOnEnqueue = const []});

  final List<BlossomBackgroundTransferEvent> emitOnEnqueue;
  final StreamController<BlossomBackgroundTransferEvent> _controller =
      StreamController<BlossomBackgroundTransferEvent>.broadcast();
  final List<String> enqueued = <String>[];
  final List<String> cancelled = <String>[];

  @override
  Stream<BlossomBackgroundTransferEvent> get events => _controller.stream;

  @override
  Future<void> enqueue({
    required String taskId,
    required String url,
    required String method,
    required Map<String, String> headers,
    required String filePath,
  }) async {
    enqueued.add(taskId);
    emitOnEnqueue.forEach(_controller.add);
  }

  @override
  Future<void> cancel(String taskId) async => cancelled.add(taskId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const server = 'https://media.divine.video';
  const taskId = 'upload-1';
  late _MockAuthProvider auth;
  late Directory tempDir;
  late File videoFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    auth = _MockAuthProvider();
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
          'id': 'abc',
          'kind': 24242,
          'pubkey': 'pk',
          'created_at': 1,
          'tags': <dynamic>[],
        },
      ),
    );

    tempDir = await Directory.systemTemp.createTemp('blossom_bg_test_');
    videoFile = File('${tempDir.path}/video.mp4')
      ..writeAsBytesSync(List<int>.generate(64, (i) => i));
  });

  tearDown(() async => tempDir.delete(recursive: true));

  BlossomUploadService service(_FakeTransport? transport) {
    return BlossomUploadService(
      authProvider: auth,
      defaultServerUrl: server,
      backgroundTransport: transport,
    );
  }

  test('returns failure when no transport is configured', () async {
    final result = await service(null).uploadVideoInBackground(
      videoFile: videoFile,
      taskId: taskId,
      proofManifestJson: null,
    );

    expect(result.success, isFalse);
    expect(result.failureReason, BlossomUploadFailureReason.unknown);
  });

  test('returns auth failure when unauthenticated', () async {
    when(() => auth.isAuthenticated).thenReturn(false);

    final result = await service(_FakeTransport()).uploadVideoInBackground(
      videoFile: videoFile,
      taskId: taskId,
      proofManifestJson: null,
    );

    expect(result.success, isFalse);
    expect(result.failureReason, BlossomUploadFailureReason.auth);
  });

  test('enqueues a single PUT and resolves with the canonical URL', () async {
    final transport = _FakeTransport(
      emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
        BlossomBackgroundTransferEvent(
          taskId: taskId,
          status: BlossomBackgroundTransferStatus.completed,
          progress: 1,
          httpStatusCode: 200,
        ),
      ],
    );
    final progress = <double>[];

    final result = await service(transport).uploadVideoInBackground(
      videoFile: videoFile,
      taskId: taskId,
      proofManifestJson: null,
      onProgress: progress.add,
    );

    expect(transport.enqueued, <String>[taskId]);
    expect(result.success, isTrue);
    expect(result.url, startsWith('$server/'));
    expect(result.videoId, isNotEmpty);
    expect(progress.last, 1.0);
  });

  test('maps an HTTP error terminal event to a server failure', () async {
    final transport = _FakeTransport(
      emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
        BlossomBackgroundTransferEvent(
          taskId: taskId,
          status: BlossomBackgroundTransferStatus.failed,
          httpStatusCode: 503,
        ),
      ],
    );

    final result = await service(transport).uploadVideoInBackground(
      videoFile: videoFile,
      taskId: taskId,
      proofManifestJson: null,
    );

    expect(result.success, isFalse);
    expect(result.statusCode, 503);
    expect(result.failureReason, BlossomUploadFailureReason.server);
  });

  test(
    'maps a transport error (no status) to a transient network failure',
    () async {
      final transport = _FakeTransport(
        emitOnEnqueue: const <BlossomBackgroundTransferEvent>[
          BlossomBackgroundTransferEvent(
            taskId: taskId,
            status: BlossomBackgroundTransferStatus.failed,
            error: 'Connection reset by peer',
          ),
        ],
      );

      final result = await service(transport).uploadVideoInBackground(
        videoFile: videoFile,
        taskId: taskId,
        proofManifestJson: null,
      );

      expect(result.success, isFalse);
      expect(result.failureReason, BlossomUploadFailureReason.network);
      expect(result.isTransientNetworkFailure, isTrue);
    },
  );

  test('parses streaming metadata from the response body', () async {
    final body = jsonEncode(<String, dynamic>{
      'streaming': <String, dynamic>{
        'mp4Url': 'https://media.divine.video/stream.mp4',
        'status': 'processing',
      },
    });
    final transport = _FakeTransport(
      emitOnEnqueue: <BlossomBackgroundTransferEvent>[
        BlossomBackgroundTransferEvent(
          taskId: taskId,
          status: BlossomBackgroundTransferStatus.completed,
          httpStatusCode: 200,
          responseBody: body,
        ),
      ],
    );

    final result = await service(transport).uploadVideoInBackground(
      videoFile: videoFile,
      taskId: taskId,
      proofManifestJson: null,
    );

    expect(result.success, isTrue);
    expect(result.streamingMp4Url, 'https://media.divine.video/stream.mp4');
    expect(result.streamingStatus, 'processing');
  });
}

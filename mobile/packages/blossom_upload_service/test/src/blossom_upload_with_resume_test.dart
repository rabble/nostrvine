// ABOUTME: Tests for uploadVideoWithResume, the OS-first-then-resumable
// ABOUTME: combined upload path that prevents re-sending the whole file.

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthProvider extends Mock implements BlossomAuthProvider {}

class _MockDio extends Mock implements Dio {}

/// A controllable [BlossomBackgroundTransport] that records enqueue calls and
/// either completes or fails the OS-backed whole-file PUT.
class _FakeTransport implements BlossomBackgroundTransport {
  _FakeTransport({
    this.completeSuccessfully = true,
  });

  final bool completeSuccessfully;
  final List<String> enqueuedTaskIds = <String>[];
  final StreamController<BlossomBackgroundTransferEvent> _controller =
      StreamController<BlossomBackgroundTransferEvent>.broadcast();

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
    enqueuedTaskIds.add(taskId);
    if (completeSuccessfully) {
      _controller.add(
        BlossomBackgroundTransferEvent(
          taskId: taskId,
          status: BlossomBackgroundTransferStatus.completed,
          progress: 1,
          httpStatusCode: 200,
          responseBody:
              '{"url":"https://media.divine.video/bg-final",'
              '"fallbackUrl":"https://media.divine.video/bg-final"}',
        ),
      );
    } else {
      _controller.add(
        BlossomBackgroundTransferEvent(
          taskId: taskId,
          status: BlossomBackgroundTransferStatus.failed,
          error: 'network drop',
        ),
      );
    }
  }

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<BlossomBackgroundTransferEvent?> takeBufferedTerminalEvent(
    String taskId,
  ) async => null;
}

/// A performance monitor whose [startTrace] throws on the first call and
/// succeeds thereafter. The first call is from uploadVideoInBackground (the
/// OS-first attempt); the throw makes it propagate out of that method before
/// its internal try/catch, exercising the defensive catch in
/// uploadVideoWithResume. The subsequent resumable uploadVideo path then gets
/// a working trace so it can complete normally.
class _ThrowingPerformanceMonitor implements BlossomPerformanceMonitor {
  var _calls = 0;

  @override
  Future<void> startTrace(String traceName) async {
    _calls++;
    if (_calls == 1) {
      throw Exception('perf monitor unavailable');
    }
  }

  @override
  Future<void> stopTrace(String traceName) async {}

  @override
  void setMetric(String traceName, String metricName, int value) {}
}

const _testServer = 'https://media.divine.video';
const _testPublicKey =
    '0223456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Options());
  });

  late _MockAuthProvider auth;
  late _MockDio dio;
  late Directory tempDir;
  late File videoFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    auth = _MockAuthProvider();
    dio = _MockDio();

    when(() => auth.isAuthenticated).thenReturn(true);
    when(
      () => auth.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer(
      (_) async => const BlossomSignedEvent(
        json: {
          'id': 'test',
          'pubkey': _testPublicKey,
          'created_at': 0,
          'kind': 24242,
          'tags': <List<String>>[],
          'content': 'Upload video to Blossom server',
          'sig': 'test',
        },
      ),
    );

    tempDir = await Directory.systemTemp.createTemp('blossom_resume_test_');
    // 8-byte file → two 4-byte chunks in the resumable path.
    videoFile = File('${tempDir.path}/video.mp4')
      ..writeAsBytesSync(List<int>.generate(8, (i) => i));
  });

  tearDown(() async => tempDir.delete(recursive: true));

  /// Stubs the resumable capability HEAD + init POST + complete POST on [dio].
  /// The caller is responsible for stubbing `dio.put` for chunk PUTs.
  void stubResumableControlPlane({required String uploadId}) {
    // Capability HEAD — advertises resumable sessions.
    when(
      () => dio.head<dynamic>(any(), options: any(named: 'options')),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/upload'),
        statusCode: 200,
        headers: Headers.fromMap({
          DivineUploadHeaders.extensions: [
            DivineUploadExtensions.resumableSessions,
          ],
          DivineUploadHeaders.controlHost: [_testServer],
          DivineUploadHeaders.dataHost: ['https://upload.divine.video'],
        }),
      ),
    );

    // init + complete POSTs.
    when(
      () => dio.post<dynamic>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((invocation) async {
      final url = invocation.positionalArguments.first as String;
      if (url.endsWith('/upload/init')) {
        return Response(
          requestOptions: RequestOptions(path: '/upload/init'),
          statusCode: 200,
          data: {
            'uploadId': uploadId,
            'uploadUrl': 'https://upload.divine.video/sessions/$uploadId',
            'chunkSize': 4,
            'nextOffset': 0,
            'requiredHeaders': {'Authorization': 'Bearer session-token'},
          },
        );
      }
      if (url.endsWith('/upload/$uploadId/complete')) {
        return Response(
          requestOptions: RequestOptions(path: '/upload/$uploadId/complete'),
          statusCode: 200,
          data: {
            'url': '$_testServer/final',
            'fallbackUrl': '$_testServer/final',
          },
        );
      }
      throw StateError('Unexpected POST url: $url');
    });
  }

  group('uploadVideoWithResume', () {
    test(
      'fresh upload succeeds via OS-first PUT and never touches resumable',
      () async {
        final transport = _FakeTransport();
        final service = BlossomUploadService(
          authProvider: auth,
          dio: dio,
          defaultServerUrl: _testServer,
          backgroundTransport: transport,
        );

        final result = await service.uploadVideoWithResume(
          videoFile: videoFile,
          nostrPubkey: _testPublicKey,
          taskId: 'task-1',
          title: 'OS-first success',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);
        expect(transport.enqueuedTaskIds, equals(['task-1']));

        // The resumable control plane was never reached: no HEAD /upload
        // capability probe, no POST /upload/init.
        verifyNever(
          () => dio.head<dynamic>(any(), options: any(named: 'options')),
        );
        verifyNever(
          () => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        );
      },
    );

    test(
      'fresh upload whose OS PUT fails falls back to chunked resumable',
      () async {
        final transport = _FakeTransport(completeSuccessfully: false);
        final service = BlossomUploadService(
          authProvider: auth,
          dio: dio,
          defaultServerUrl: _testServer,
          backgroundTransport: transport,
        );

        stubResumableControlPlane(uploadId: 'up_fb');

        // Chunk PUTs — two 4-byte chunks, succeed immediately.
        when(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final options = invocation.namedArguments[#options] as Options;
          final contentRange = options.headers?['Content-Range'] as String;
          final nextOffset = switch (contentRange) {
            'bytes 0-3/8' => '4',
            'bytes 4-7/8' => '8',
            _ => throw StateError('Unexpected range: $contentRange'),
          };
          return Response(
            requestOptions: RequestOptions(path: '/sessions/up_fb'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: [nextOffset],
            }),
          );
        });

        final result = await service.uploadVideoWithResume(
          videoFile: videoFile,
          nostrPubkey: _testPublicKey,
          taskId: 'task-2',
          title: 'OS-first fails, resumable fallback',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);
        // The OS attempt was enqueued...
        expect(transport.enqueuedTaskIds, equals(['task-2']));
        // ...and the resumable fallback was reached.
        verify(
          () => dio.head<dynamic>(any(), options: any(named: 'options')),
        ).called(1);
        verify(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(2);
      },
    );

    test(
      'when a resumable session already exists, skips the OS PUT and resumes',
      () async {
        final transport = _FakeTransport();
        final service = BlossomUploadService(
          authProvider: auth,
          dio: dio,
          defaultServerUrl: _testServer,
          backgroundTransport: transport,
        );

        // Simulate a session from a prior attempt that committed 4 bytes.
        // HEAD resume returns offset 4, so only the final chunk (4-7) is sent.
        const uploadId = 'up_resume';
        final existingSession = BlossomResumableUploadSession(
          uploadId: uploadId,
          uploadUrl: 'https://upload.divine.video/sessions/$uploadId',
          chunkSize: 4,
          nextOffset: 0,
          expiresAt: DateTime.utc(2099),
          requiredHeaders: {'Authorization': 'Bearer session-token'},
        );

        // Capability HEAD (called by uploadVideo).
        when(
          () => dio.head<dynamic>(any(), options: any(named: 'options')),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url == '$_testServer/upload') {
            return Response(
              requestOptions: RequestOptions(path: '/upload'),
              statusCode: 200,
              headers: Headers.fromMap({
                DivineUploadHeaders.extensions: [
                  DivineUploadExtensions.resumableSessions,
                ],
              }),
            );
          }
          // HEAD on the session URL → resume offset query.
          if (url == existingSession.uploadUrl) {
            return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 204,
              headers: Headers.fromMap({
                DivineUploadHeaders.uploadOffset: ['4'],
              }),
            );
          }
          throw StateError('Unexpected HEAD url: $url');
        });

        // complete POST.
        when(
          () => dio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          final url = invocation.positionalArguments.first as String;
          if (url.endsWith('/upload/$uploadId/complete')) {
            return Response(
              requestOptions: RequestOptions(path: '/complete'),
              statusCode: 200,
              data: {
                'url': '$_testServer/final',
                'fallbackUrl': '$_testServer/final',
              },
            );
          }
          throw StateError('Unexpected POST url: $url');
        });

        // Chunk PUT — only the final chunk should arrive.
        when(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final options = invocation.namedArguments[#options] as Options;
          final contentRange = options.headers?['Content-Range'] as String;
          expect(
            contentRange,
            equals('bytes 4-7/8'),
            reason: 'resume must upload only the uncommitted tail, not byte 0',
          );
          return Response(
            requestOptions: RequestOptions(path: '/sessions/$uploadId'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: ['8'],
            }),
          );
        });

        final result = await service.uploadVideoWithResume(
          videoFile: videoFile,
          nostrPubkey: _testPublicKey,
          taskId: 'task-3',
          title: 'resume from existing session',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          resumableSession: existingSession,
        );

        expect(result.success, isTrue);
        // The OS PUT must NOT have been enqueued — existing session means
        // resume-by-offset, never re-run the whole-file PUT.
        expect(transport.enqueuedTaskIds, isEmpty);
        // Only one chunk PUT (the tail), proving byte-level resume.
        verify(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(1);
      },
    );

    test(
      'useBackgroundFirst=false skips OS PUT and goes straight to resumable',
      () async {
        final transport = _FakeTransport();
        final service = BlossomUploadService(
          authProvider: auth,
          dio: dio,
          defaultServerUrl: _testServer,
          backgroundTransport: transport,
        );

        stubResumableControlPlane(uploadId: 'up_nobg');

        when(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final options = invocation.namedArguments[#options] as Options;
          final contentRange = options.headers?['Content-Range'] as String;
          final nextOffset = switch (contentRange) {
            'bytes 0-3/8' => '4',
            'bytes 4-7/8' => '8',
            _ => throw StateError('Unexpected range: $contentRange'),
          };
          return Response(
            requestOptions: RequestOptions(path: '/sessions/up_nobg'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: [nextOffset],
            }),
          );
        });

        final result = await service.uploadVideoWithResume(
          videoFile: videoFile,
          nostrPubkey: _testPublicKey,
          taskId: 'task-4',
          title: 'no OS first',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          useBackgroundFirst: false,
        );

        expect(result.success, isTrue);
        // OS PUT never enqueued.
        expect(transport.enqueuedTaskIds, isEmpty);
        verify(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(2);
      },
    );

    test(
      'session callback emits monotonically increasing offsets during resume',
      () async {
        final transport = _FakeTransport(completeSuccessfully: false);
        final service = BlossomUploadService(
          authProvider: auth,
          dio: dio,
          defaultServerUrl: _testServer,
          backgroundTransport: transport,
        );

        stubResumableControlPlane(uploadId: 'up_cb');

        when(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final options = invocation.namedArguments[#options] as Options;
          final contentRange = options.headers?['Content-Range'] as String;
          final nextOffset = switch (contentRange) {
            'bytes 0-3/8' => '4',
            'bytes 4-7/8' => '8',
            _ => throw StateError('Unexpected range: $contentRange'),
          };
          return Response(
            requestOptions: RequestOptions(path: '/sessions/up_cb'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: [nextOffset],
            }),
          );
        });

        final sessionUpdates = <BlossomResumableUploadSession>[];
        final result = await service.uploadVideoWithResume(
          videoFile: videoFile,
          nostrPubkey: _testPublicKey,
          taskId: 'task-5',
          title: 'session callback',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          onResumableSessionUpdated: sessionUpdates.add,
        );

        expect(result.success, isTrue);
        // init reports offset 0, then each chunk reports the next committed
        // offset. This is the persisted progress the next retry resumes from.
        expect(sessionUpdates.map((s) => s.nextOffset), [0, 4, 8]);
      },
    );

    test(
      'OS-first attempt that throws still falls back to chunked resumable',
      () async {
        // uploadVideoInBackground normally returns failures rather than
        // throwing, so to exercise the catch-guard we make startTrace throw
        // (it runs before uploadVideoInBackground's internal try/catch). The
        // publish must still get a resumable retry rather than dying.
        final transport = _FakeTransport();
        final service = BlossomUploadService(
          authProvider: auth,
          dio: dio,
          defaultServerUrl: _testServer,
          backgroundTransport: transport,
          performanceMonitor: _ThrowingPerformanceMonitor(),
        );

        stubResumableControlPlane(uploadId: 'up_throw');

        when(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final options = invocation.namedArguments[#options] as Options;
          final contentRange = options.headers?['Content-Range'] as String;
          final nextOffset = switch (contentRange) {
            'bytes 0-3/8' => '4',
            'bytes 4-7/8' => '8',
            _ => throw StateError('Unexpected range: $contentRange'),
          };
          return Response(
            requestOptions: RequestOptions(path: '/sessions/up_throw'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: [nextOffset],
            }),
          );
        });

        final result = await service.uploadVideoWithResume(
          videoFile: videoFile,
          nostrPubkey: _testPublicKey,
          taskId: 'task-throw',
          title: 'OS-first throws',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);
        // The OS attempt never reached enqueue (startTrace threw first), but
        // the resumable fallback still completed successfully.
        expect(transport.enqueuedTaskIds, isEmpty);
        verify(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(2);
      },
    );

    test(
      'resumableTimeout bounds only the in-process resumable leg',
      () async {
        final transport = _FakeTransport(completeSuccessfully: false);
        final service = BlossomUploadService(
          authProvider: auth,
          dio: dio,
          defaultServerUrl: _testServer,
          backgroundTransport: transport,
        );

        stubResumableControlPlane(uploadId: 'up_to');

        when(
          () => dio.put<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          final options = invocation.namedArguments[#options] as Options;
          final contentRange = options.headers?['Content-Range'] as String;
          final nextOffset = switch (contentRange) {
            'bytes 0-3/8' => '4',
            'bytes 4-7/8' => '8',
            _ => throw StateError('Unexpected range: $contentRange'),
          };
          return Response(
            requestOptions: RequestOptions(path: '/sessions/up_to'),
            statusCode: 204,
            headers: Headers.fromMap({
              DivineUploadHeaders.uploadOffset: [nextOffset],
            }),
          );
        });

        // A generous timeout that the fast mock resumable leg stays well
        // under — proves the timeout branch is wired without flaking.
        final result = await service.uploadVideoWithResume(
          videoFile: videoFile,
          nostrPubkey: _testPublicKey,
          taskId: 'task-to',
          title: 'resumable timeout',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          resumableTimeout: const Duration(minutes: 1),
        );

        expect(result.success, isTrue);
      },
    );
  });
}

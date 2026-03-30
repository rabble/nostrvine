// ABOUTME: Integration-style coverage for the Divine resumable Blossom upload flow
// ABOUTME: Verifies capability discovery, opaque uploadUrl handling, and canonical completion URLs

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/upload_constants.dart';
import 'package:openvine/models/blossom_resumable_upload_session.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDio extends Mock implements Dio {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Options());
  });

  test(
    'Divine resumable uploads use init, session PUTs, and complete with an opaque uploadUrl',
    () async {
      SharedPreferences.setMockInitialValues({});

      final mockAuthService = _MockAuthService();
      final mockDio = _MockDio();
      final service = BlossomUploadService(
        authService: mockAuthService,
        dio: mockDio,
      );

      const testPublicKey =
          '0223456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(testPublicKey);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(
          testPublicKey,
          24242,
          const [],
          'Upload video to Blossom server',
        ),
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'blossom_resumable_integration_',
      );
      final videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync(List<int>.generate(10, (index) => index));
      final sessionUpdates = <BlossomResumableUploadSession>[];

      when(
        () => mockDio.head(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url == 'https://media.divine.video/upload') {
          return Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
              DivineUploadHeaders.controlHost: [
                'https://media.divine.video',
              ],
              DivineUploadHeaders.dataHost: [
                'https://upload.divine.video',
              ],
            }),
          );
        }

        throw StateError('Unexpected HEAD url: $url');
      });

      when(
        () => mockDio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        final data = invocation.namedArguments[#data];
        if (url.endsWith('/upload/init')) {
          return Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 200,
            data: {
              'uploadId': 'up_123',
              'uploadUrl': 'https://upload.divine.video/sessions/up_123',
              'chunkSize': 4,
              'nextOffset': 0,
              'requiredHeaders': {'Authorization': 'Bearer session-token'},
            },
          );
        }

        if (url.endsWith('/upload/up_123/complete')) {
          expect(data, isA<Map>());
          expect((data as Map)['sha256'], isNotEmpty);
          return Response(
            requestOptions: RequestOptions(path: '/upload/up_123/complete'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/final',
              'fallbackUrl': 'https://media.divine.video/final',
            },
          );
        }

        throw StateError('Unexpected POST url: $url');
      });

      when(
        () => mockDio.put(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((invocation) async {
        final options = invocation.namedArguments[#options] as Options;
        expect(
          options.headers?['Authorization'],
          equals('Bearer session-token'),
        );
        expect(
          invocation.positionalArguments.first,
          equals('https://upload.divine.video/sessions/up_123'),
        );

        final contentRange = options.headers?['Content-Range'] as String;
        final nextOffset = switch (contentRange) {
          'bytes 0-3/10' => '4',
          'bytes 4-7/10' => '8',
          'bytes 8-9/10' => '10',
          _ => throw StateError('Unexpected content range: $contentRange'),
        };

        return Response(
          requestOptions: RequestOptions(path: '/sessions/up_123'),
          statusCode: 204,
          headers: Headers.fromMap({
            DivineUploadHeaders.uploadOffset: [nextOffset],
          }),
        );
      });

      final result = await service.uploadVideo(
        videoFile: videoFile,
        nostrPubkey: testPublicKey,
        title: 'Integration test upload',
        description: null,
        hashtags: null,
        proofManifestJson: null,
        onResumableSessionUpdated: sessionUpdates.add,
      );

      expect(result.success, isTrue);
      expect(result.videoId, isNotNull);
      expect(
        result.cdnUrl,
        equals('https://media.divine.video/${result.videoId}'),
      );
      expect(sessionUpdates.map((session) => session.uploadUrl).toSet(), {
        'https://upload.divine.video/sessions/up_123',
      });
      expect(sessionUpdates.map((session) => session.nextOffset), [
        0,
        4,
        8,
        10,
      ]);

      await tempDir.delete(recursive: true);
    },
  );

  test(
    'Divine resumable uploads keep ProofMode metadata on the completion request',
    () async {
      SharedPreferences.setMockInitialValues({});

      final mockAuthService = _MockAuthService();
      final mockDio = _MockDio();
      final service = BlossomUploadService(
        authService: mockAuthService,
        dio: mockDio,
      );

      const testPublicKey =
          '0223456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const proofManifest = '{"videoHash":"abc123","pgpSignature":"sig"}';

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(testPublicKey);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(
          testPublicKey,
          24242,
          const [],
          'Upload video to Blossom server',
        ),
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'blossom_resumable_proofmode_integration_',
      );
      final videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync(List<int>.generate(10, (index) => index));
      final sessionUpdates = <BlossomResumableUploadSession>[];

      when(
        () => mockDio.head(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        if (url == 'https://media.divine.video/upload') {
          return Response(
            requestOptions: RequestOptions(path: '/upload'),
            statusCode: 200,
            headers: Headers.fromMap({
              DivineUploadHeaders.extensions: [
                DivineUploadExtensions.resumableSessions,
              ],
              DivineUploadHeaders.controlHost: [
                'https://media.divine.video',
              ],
              DivineUploadHeaders.dataHost: [
                'https://upload.divine.video',
              ],
            }),
          );
        }

        throw StateError('Unexpected HEAD url: $url');
      });

      when(
        () => mockDio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final url = invocation.positionalArguments.first as String;
        final options = invocation.namedArguments[#options] as Options;
        final data = invocation.namedArguments[#data];

        if (url.endsWith('/upload/init')) {
          return Response(
            requestOptions: RequestOptions(path: '/upload/init'),
            statusCode: 200,
            data: {
              'uploadId': 'up_123',
              'uploadUrl': 'https://upload.divine.video/sessions/up_123',
              'chunkSize': 4,
              'nextOffset': 0,
              'requiredHeaders': {'Authorization': 'Bearer session-token'},
            },
          );
        }

        if (url.endsWith('/upload/up_123/complete')) {
          expect(options.headers?['X-ProofMode-Manifest'], isNotNull);
          expect(data, isA<Map>());
          expect((data as Map)['sha256'], isNotEmpty);
          return Response(
            requestOptions: RequestOptions(path: '/upload/up_123/complete'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/final',
              'fallbackUrl': 'https://media.divine.video/final',
            },
          );
        }

        throw StateError('Unexpected POST url: $url');
      });

      when(
        () => mockDio.put(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((invocation) async {
        final options = invocation.namedArguments[#options] as Options;
        expect(
          options.headers?['Authorization'],
          equals('Bearer session-token'),
        );
        expect(
          options.headers?['X-ProofMode-Manifest'],
          isNull,
        );
        expect(
          invocation.positionalArguments.first,
          equals('https://upload.divine.video/sessions/up_123'),
        );

        final contentRange = options.headers?['Content-Range'] as String;
        final nextOffset = switch (contentRange) {
          'bytes 0-3/10' => '4',
          'bytes 4-7/10' => '8',
          'bytes 8-9/10' => '10',
          _ => throw StateError('Unexpected content range: $contentRange'),
        };

        return Response(
          requestOptions: RequestOptions(path: '/sessions/up_123'),
          statusCode: 204,
          headers: Headers.fromMap({
            DivineUploadHeaders.uploadOffset: [nextOffset],
          }),
        );
      });

      final result = await service.uploadVideo(
        videoFile: videoFile,
        nostrPubkey: testPublicKey,
        title: 'Integration test ProofMode upload',
        description: null,
        hashtags: null,
        proofManifestJson: proofManifest,
        onResumableSessionUpdated: sessionUpdates.add,
      );

      expect(result.success, isTrue);
      expect(result.videoId, isNotNull);
      expect(
        result.cdnUrl,
        equals('https://media.divine.video/${result.videoId}'),
      );
      expect(sessionUpdates.map((session) => session.nextOffset), [
        0,
        4,
        8,
        10,
      ]);

      await tempDir.delete(recursive: true);
    },
  );

  group('per-chunk retry', () {
    late _MockAuthService mockAuthService;
    late _MockDio mockDio;
    late BlossomUploadService service;
    late Directory tempDir;
    late File videoFile;

    const testPublicKey =
        '0223456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      mockAuthService = _MockAuthService();
      mockDio = _MockDio();
      service = BlossomUploadService(
        authService: mockAuthService,
        dio: mockDio,
      );

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(testPublicKey);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(
          testPublicKey,
          24242,
          const [],
          'Upload video to Blossom server',
        ),
      );

      tempDir = await Directory.systemTemp.createTemp(
        'blossom_chunk_retry_',
      );
      // 8-byte file → two 4-byte chunks
      videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync(List<int>.generate(8, (i) => i));

      // Capability HEAD — always returns resumable support
      when(
        () => mockDio.head(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/upload'),
          statusCode: 200,
          headers: Headers.fromMap({
            DivineUploadHeaders.extensions: [
              DivineUploadExtensions.resumableSessions,
            ],
            DivineUploadHeaders.controlHost: ['https://media.divine.video'],
            DivineUploadHeaders.dataHost: ['https://upload.divine.video'],
          }),
        ),
      );

      // Init POST — returns session with 4-byte chunks
      when(
        () => mockDio.post(
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
              'uploadId': 'up_retry',
              'uploadUrl': 'https://upload.divine.video/sessions/up_retry',
              'chunkSize': 4,
              'nextOffset': 0,
              'requiredHeaders': {'Authorization': 'Bearer token'},
            },
          );
        }
        if (url.endsWith('/upload/up_retry/complete')) {
          return Response(
            requestOptions: RequestOptions(path: '/upload/up_retry/complete'),
            statusCode: 200,
            data: {
              'url': 'https://media.divine.video/final',
              'fallbackUrl': 'https://media.divine.video/final',
            },
          );
        }
        throw StateError('Unexpected POST url: $url');
      });
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    Response<dynamic> chunkSuccessResponse(String nextOffset) => Response(
      requestOptions: RequestOptions(path: '/sessions/up_retry'),
      statusCode: 204,
      headers: Headers.fromMap({
        DivineUploadHeaders.uploadOffset: [nextOffset],
      }),
    );

    test(
      'retries a transient 502 on the first chunk and completes',
      () async {
        var putCallCount = 0;

        when(
          () => mockDio.put(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          putCallCount++;
          final options = invocation.namedArguments[#options] as Options;
          final contentRange = options.headers?['Content-Range'] as String;

          // First PUT for chunk 1 → 502, second PUT for chunk 1 → success
          if (contentRange == 'bytes 0-3/8' && putCallCount == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/sessions/up_retry'),
              response: Response(
                requestOptions: RequestOptions(path: '/sessions/up_retry'),
                statusCode: 502,
              ),
              type: DioExceptionType.badResponse,
            );
          }

          final nextOffset = switch (contentRange) {
            'bytes 0-3/8' => '4',
            'bytes 4-7/8' => '8',
            _ => throw StateError('Unexpected range: $contentRange'),
          };
          return chunkSuccessResponse(nextOffset);
        });

        final sessionUpdates = <BlossomResumableUploadSession>[];
        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'retry test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
          onResumableSessionUpdated: sessionUpdates.add,
        );

        expect(result.success, isTrue);
        // 1 failed + 1 success for chunk 1, 1 success for chunk 2 = 3
        expect(putCallCount, equals(3));
        expect(sessionUpdates.map((s) => s.nextOffset), [0, 4, 8]);
      },
    );

    test(
      'retries a DioException.connectionError and completes',
      () async {
        var putCallCount = 0;

        when(
          () => mockDio.put(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          putCallCount++;
          final options = invocation.namedArguments[#options] as Options;
          final contentRange = options.headers?['Content-Range'] as String;

          // First chunk, first attempt → network error
          if (contentRange == 'bytes 0-3/8' && putCallCount == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/sessions/up_retry'),
              type: DioExceptionType.connectionError,
              error: 'Connection reset by peer',
            );
          }

          final nextOffset = switch (contentRange) {
            'bytes 0-3/8' => '4',
            'bytes 4-7/8' => '8',
            _ => throw StateError('Unexpected range: $contentRange'),
          };
          return chunkSuccessResponse(nextOffset);
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'network retry test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isTrue);
        expect(putCallCount, equals(3));
      },
    );

    test(
      'does not retry a 404 session-expired response',
      () async {
        when(
          () => mockDio.put(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((invocation) async {
          // 404 is < 500, so Dio returns it as a response (not exception).
          // _uploadChunks should throw BlossomResumableUploadException
          // without retrying.
          return Response(
            requestOptions: RequestOptions(path: '/sessions/up_retry'),
            statusCode: 404,
          );
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'expired session test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        // Upload fails because the session-expired error propagates
        // through the server loop catch and returns a failed result.
        expect(result.success, isFalse);

        // PUT was called only once — no retry for 404
        verify(
          () => mockDio.put(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).called(1);
      },
    );

    test(
      'rethrows after exhausting per-chunk retries',
      () async {
        var putCallCount = 0;

        when(
          () => mockDio.put(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          putCallCount++;
          throw DioException(
            requestOptions: RequestOptions(path: '/sessions/up_retry'),
            response: Response(
              requestOptions: RequestOptions(path: '/sessions/up_retry'),
              statusCode: 503,
            ),
            type: DioExceptionType.badResponse,
          );
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'exhausted retries test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isFalse);
        // 1 initial + 2 retries = 3 total attempts
        expect(putCallCount, equals(3));
      },
    );

    test(
      'does not retry a non-transient DioException (e.g. cancel)',
      () async {
        var putCallCount = 0;

        when(
          () => mockDio.put(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((_) async {
          putCallCount++;
          throw DioException(
            requestOptions: RequestOptions(path: '/sessions/up_retry'),
            type: DioExceptionType.cancel,
          );
        });

        final result = await service.uploadVideo(
          videoFile: videoFile,
          nostrPubkey: testPublicKey,
          title: 'cancel test',
          description: null,
          hashtags: null,
          proofManifestJson: null,
        );

        expect(result.success, isFalse);
        // No retry — cancel is not transient
        expect(putCallCount, equals(1));
      },
    );
  });
}

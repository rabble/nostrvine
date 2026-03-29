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
}

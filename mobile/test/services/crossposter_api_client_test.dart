import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/crossposter_api_client.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group(CrossposterApiClient, () {
    late _MockKeycastOAuth oauthClient;
    late _MockHttpClient httpClient;
    late CrossposterApiClient client;

    const accessToken = 'session-access-token';
    const eventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        'aaaaaaaaaaaaaaaaaaaaaaaa';

    const connectionJson = {
      'id': 'conn-1',
      'platform': 'instagram',
      'externalAccountId': 'ig-123',
      'externalAccountName': 'divine.creator',
      'status': 'connected',
    };

    const postedJobJson = {
      'id': 'job-1',
      'platform': 'instagram',
      'status': 'posted',
      'externalPostId': 'ig-post-1',
      'externalPostUrl': 'https://www.instagram.com/reel/abc/',
      'errorCode': null,
      'errorMessage': null,
    };

    setUpAll(() {
      registerFallbackValue(Uri());
    });

    setUp(() {
      oauthClient = _MockKeycastOAuth();
      httpClient = _MockHttpClient();
      client = CrossposterApiClient(
        oauthClient: oauthClient,
        httpClient: httpClient,
      );
      when(() => oauthClient.getSession()).thenAnswer(
        (_) async => const KeycastSession(
          bunkerUrl: 'bunker://test',
          accessToken: accessToken,
        ),
      );
    });

    group('getConnections', () {
      test('calls GET /connections with bearer token and parses '
          'connections', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'connections': [connectionJson],
            }),
            200,
          ),
        );

        final connections = await client.getConnections();

        final captured = verify(
          () => httpClient.get(
            captureAny(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;
        expect(
          captured.first,
          equals(Uri.parse('https://crossposter.divine.video/connections')),
        );
        expect(
          (captured.last as Map<String, String>)['Authorization'],
          equals('Bearer $accessToken'),
        );
        expect(connections, hasLength(1));
        expect(connections.single.platform, equals('instagram'));
        expect(connections.single.isConnected, isTrue);
        expect(
          connections.single.externalAccountName,
          equals('divine.creator'),
        );
      });

      test('throws $CrossposterApiException with code when '
          'unauthenticated session', () async {
        when(() => oauthClient.getSession()).thenAnswer((_) async => null);

        expect(
          client.getConnections,
          throwsA(
            isA<CrossposterApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(401),
            ),
          ),
        );
      });

      test('parses server error envelope on non-200', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'unauthorized',
                'message': 'missing bearer token',
              },
            }),
            401,
          ),
        );

        expect(
          client.getConnections,
          throwsA(
            isA<CrossposterApiException>()
                .having((e) => e.code, 'code', equals('unauthorized'))
                .having(
                  (e) => e.message,
                  'message',
                  equals('missing bearer token'),
                ),
          ),
        );
      });
    });

    group('createCrossposts', () {
      test('POSTs the platform list and parses jobs', () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'jobs': [postedJobJson],
            }),
            200,
          ),
        );

        final jobs = await client.createCrossposts(
          eventId: eventId,
          platforms: ['instagram'],
        );

        final captured = verify(
          () => httpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;
        expect(
          captured.first,
          equals(
            Uri.parse(
              'https://crossposter.divine.video/videos/$eventId/crossposts',
            ),
          ),
        );
        expect(
          jsonDecode(captured.last as String),
          equals({
            'platforms': ['instagram'],
          }),
        );
        expect(jobs.single.status, equals(CrosspostJobStatus.posted));
        expect(
          jobs.single.externalPostUrl,
          equals('https://www.instagram.com/reel/abc/'),
        );
      });

      test('surfaces not_eligible error code', () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 'not_eligible',
                'message': 'video is not eligible',
              },
            }),
            409,
          ),
        );

        expect(
          () => client.createCrossposts(
            eventId: eventId,
            platforms: ['instagram'],
          ),
          throwsA(
            isA<CrossposterApiException>().having(
              (e) => e.code,
              'code',
              equals('not_eligible'),
            ),
          ),
        );
      });
    });

    group('getCrossposts', () {
      test('parses pending job statuses from the wire', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'jobs': [
                {'id': 'j1', 'platform': 'instagram', 'status': 'queued'},
                {'id': 'j2', 'platform': 'tiktok', 'status': 'uploading'},
                {
                  'id': 'j3',
                  'platform': 'x',
                  'status': 'needs_reauth',
                  'errorCode': 'needs_reauth',
                },
              ],
            }),
            200,
          ),
        );

        final jobs = await client.getCrossposts(eventId: eventId);

        expect(jobs, hasLength(3));
        expect(jobs[0].status, equals(CrosspostJobStatus.queued));
        expect(jobs[0].status.isPending, isTrue);
        expect(jobs[1].status, equals(CrosspostJobStatus.uploading));
        expect(jobs[2].status, equals(CrosspostJobStatus.needsReauth));
        expect(jobs[2].status.isPending, isFalse);
      });

      test('maps unknown wire status to '
          '${CrosspostJobStatus.unknown}', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'jobs': [
                {
                  'id': 'j1',
                  'platform': 'instagram',
                  'status': 'brand-new-status',
                },
              ],
            }),
            200,
          ),
        );

        final jobs = await client.getCrossposts(eventId: eventId);

        expect(jobs.single.status, equals(CrosspostJobStatus.unknown));
      });

      test('falls back to generic message on non-JSON error body', () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('<html>bad</html>', 502));

        expect(
          () => client.getCrossposts(eventId: eventId),
          throwsA(
            isA<CrossposterApiException>()
                .having((e) => e.statusCode, 'statusCode', equals(502))
                .having((e) => e.code, 'code', isNull),
          ),
        );
      });
    });
  });
}

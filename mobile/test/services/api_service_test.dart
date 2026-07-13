// ABOUTME: Unit tests for ApiService to verify backend communication functionality
// ABOUTME: Tests HTTP requests, error handling, and response parsing for API endpoints

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/api_service.dart';

// Mock classes
class MockHttpClient extends Mock implements http.Client {}

class MockResponse extends Mock implements http.Response {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  group('ApiService', () {
    late ApiService apiService;
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
      apiService = ApiService(
        client: mockClient,
        relayManagerBaseUrl: 'https://api-relay-prod.divine.video',
      );
    });

    group('requestSignedUpload', () {
      test('should return signed upload parameters on success', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.body).thenReturn(
          jsonEncode({
            'upload_url': 'https://example.com/upload',
            'signed_fields': {'key': 'value'},
          }),
        );

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.requestSignedUpload(
          nostrPubkey: 'test_pubkey',
          fileSize: 1024,
          mimeType: 'video/mp4',
        );

        // Assert
        expect(result, isA<Map<String, dynamic>>());
        expect(result['upload_url'], equals('https://example.com/upload'));
        expect(result['signed_fields'], isA<Map<String, dynamic>>());
      });

      test('posts to the media API host', () async {
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.body).thenReturn(
          jsonEncode({
            'upload_url': 'https://example.com/upload',
            'signed_fields': {'key': 'value'},
          }),
        );

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => mockResponse);

        await apiService.requestSignedUpload(
          nostrPubkey: 'test_pubkey',
          fileSize: 1024,
          mimeType: 'video/mp4',
        );

        final captured =
            verify(
                  () => mockClient.post(
                    captureAny(),
                    headers: any(named: 'headers'),
                    body: any(named: 'body'),
                  ),
                ).captured.single
                as Uri;

        expect(captured.host, 'api.openvine.co');
        expect(captured.path, '/v1/media/request-upload');
      });

      test('should handle API error responses', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(400);
        when(() => mockResponse.body).thenReturn('Bad Request');

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => apiService.requestSignedUpload(
            nostrPubkey: 'test_pubkey',
            fileSize: 1024,
            mimeType: 'video/mp4',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(400),
            ),
          ),
        );
      });

      test('should handle network timeout', () async {
        // Arrange
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('timeout'));

        // Act & Assert
        expect(
          () => apiService.requestSignedUpload(
            nostrPubkey: 'test_pubkey',
            fileSize: 1024,
            mimeType: 'video/mp4',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              contains('Network error'),
            ),
          ),
        );
      });
    });

    group('minor account review endpoints', () {
      test(
        'getMinorAccountReviewStatus returns parsed response on success',
        () async {
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.body).thenReturn(
            jsonEncode({
              'restriction': {'status': 'restricted_minor_review'},
            }),
          );

          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => mockResponse);

          final result = await apiService.getMinorAccountReviewStatus();

          expect(result['restriction'], isA<Map<String, dynamic>>());
        },
      );

      test(
        'getMinorAccountReviewStatus uses the relay-manager host, '
        'not the main backend (relay-manager#108: backend 404s -> gate inert)',
        () async {
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.body).thenReturn(
            jsonEncode({
              'restriction': {'status': 'active'},
            }),
          );

          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => mockResponse);

          await apiService.getMinorAccountReviewStatus();

          final captured =
              verify(
                    () => mockClient.get(
                      captureAny(),
                      headers: any(named: 'headers'),
                    ),
                  ).captured.single
                  as Uri;

          expect(captured.host, 'api-relay-prod.divine.video');
          expect(captured.path, '/v1/account/moderation-status');
        },
      );

      test(
        'minor-review calls follow the injected relay-manager base URL '
        '(env-aware: staging builds must not hit prod)',
        () async {
          final stagingService = ApiService(
            client: mockClient,
            relayManagerBaseUrl: 'https://api-relay-staging.divine.video',
          );
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(200);
          when(() => mockResponse.body).thenReturn(
            jsonEncode({
              'restriction': {'status': 'active'},
            }),
          );
          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => mockResponse);

          await stagingService.getMinorAccountReviewStatus();

          final captured =
              verify(
                    () => mockClient.get(
                      captureAny(),
                      headers: any(named: 'headers'),
                    ),
                  ).captured.single
                  as Uri;
          expect(captured.host, 'api-relay-staging.divine.video');

          // Both endpoints read the same injected base — pin the POST too
          when(() => mockResponse.statusCode).thenReturn(204);
          when(() => mockResponse.body).thenReturn('');
          when(
            () => mockClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => mockResponse);

          await stagingService.submitMinorAccountReviewParentContact(
            caseId: 'case-9',
            email: 'parent@example.com',
          );

          final posted =
              verify(
                    () => mockClient.post(
                      captureAny(),
                      headers: any(named: 'headers'),
                      body: any(named: 'body'),
                    ),
                  ).captured.single
                  as Uri;
          expect(posted.host, 'api-relay-staging.divine.video');
        },
      );

      test(
        'getMinorAccountReviewStatus throws ApiException on non-200',
        () async {
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(503);
          when(() => mockResponse.body).thenReturn('Unavailable');

          when(
            () => mockClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer((_) async => mockResponse);

          expect(
            apiService.getMinorAccountReviewStatus,
            throwsA(
              isA<ApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                503,
              ),
            ),
          );
        },
      );

      test(
        'submitMinorAccountReviewParentContact posts email payload',
        () async {
          final mockResponse = MockResponse();
          when(() => mockResponse.statusCode).thenReturn(204);
          when(() => mockResponse.body).thenReturn('');

          when(
            () => mockClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async => mockResponse);

          await apiService.submitMinorAccountReviewParentContact(
            caseId: 'case-123',
            email: 'parent@example.com',
          );

          final captured =
              verify(
                    () => mockClient.post(
                      captureAny(),
                      headers: any(named: 'headers'),
                      body: jsonEncode({'email': 'parent@example.com'}),
                    ),
                  ).captured.single
                  as Uri;

          // Same host contract as moderation-status (relay-manager#108)
          expect(captured.host, 'api-relay-prod.divine.video');
          expect(
            captured.path,
            '/v1/minor-review-cases/case-123/parent-contact',
          );
        },
      );
    });

    group('ApiException', () {
      test('should format error message correctly', () {
        // Act
        const exception = ApiException('Test error', statusCode: 404);

        // Assert
        expect(exception.toString(), 'ApiException: Test error (404)');
      });

      test('should handle missing status code', () {
        // Act
        const exception = ApiException('Test error');

        // Assert
        expect(exception.toString(), 'ApiException: Test error (no status)');
      });
    });
  });
}

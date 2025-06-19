// ABOUTME: Unit tests for ApiService to verify backend communication functionality
// ABOUTME: Tests HTTP requests, error handling, and response parsing for ready events API

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:nostrvine_app/services/api_service.dart';

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
      apiService = ApiService(client: mockClient);
    });

    tearDown(() {
      apiService.dispose();
    });

    group('getReadyEvents', () {
      test('should return empty list when no events available', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(204);
        when(() => mockResponse.body).thenReturn('');
        
        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.getReadyEvents();

        // Assert
        expect(result, isEmpty);
      });

      test('should parse ready events from successful response', () async {
        // Arrange
        final responseBody = jsonEncode({
          'events': [
            {
              'public_id': 'test-public-id',
              'secure_url': 'https://cloudinary.com/test.mp4',
              'content_suggestion': 'Test video',
              'tags': [['url', 'https://cloudinary.com/test.mp4']],
              'metadata': {'width': 1920, 'height': 1080},
              'processed_at': '2024-01-01T12:00:00Z',
              'original_upload_id': 'upload-123',
              'mime_type': 'video/mp4',
              'file_size': 1024000,
            }
          ]
        });

        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.body).thenReturn(responseBody);
        
        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.getReadyEvents();

        // Assert
        expect(result, hasLength(1));
        expect(result.first.publicId, 'test-public-id');
        expect(result.first.secureUrl, 'https://cloudinary.com/test.mp4');
        expect(result.first.mimeType, 'video/mp4');
        expect(result.first.fileSize, 1024000);
        expect(result.first.originalUploadId, 'upload-123');
      });

      test('should handle malformed JSON response', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.body).thenReturn('invalid json {');
        
        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => apiService.getReadyEvents(),
          throwsA(isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Invalid response format'),
          )),
        );
      });

      test('should handle network timeout', () async {
        // Arrange
        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('timeout'));

        // Act & Assert
        expect(
          () => apiService.getReadyEvents(),
          throwsA(isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Network error'),
          )),
        );
      });

      test('should handle server error responses', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(500);
        when(() => mockResponse.body).thenReturn('Internal Server Error');
        
        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => apiService.getReadyEvents(),
          throwsA(isA<ApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          )),
        );
      });

      test('should include proper headers in request', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(204);
        when(() => mockResponse.body).thenReturn('');
        
        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => mockResponse);

        // Act
        await apiService.getReadyEvents();

        // Assert
        final captured = verify(() => mockClient.get(
          any(),
          headers: captureAny(named: 'headers'),
        )).captured.first as Map<String, String>;

        expect(captured['Content-Type'], 'application/json');
        expect(captured['Accept'], 'application/json');
        expect(captured['User-Agent'], 'NostrVine-Mobile/1.0');
        expect(captured['Authorization'], startsWith('Bearer '));
      });
    });

    group('cleanupRemoteEvent', () {
      test('should handle successful cleanup', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        
        when(() => mockClient.delete(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => apiService.cleanupRemoteEvent('test-public-id'),
          returnsNormally,
        );
      });

      test('should handle not found as success', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(404);
        
        when(() => mockClient.delete(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => apiService.cleanupRemoteEvent('test-public-id'),
          returnsNormally,
        );
      });

      test('should throw on cleanup failure', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(500);
        when(() => mockResponse.body).thenReturn('Server error');
        
        when(() => mockClient.delete(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => mockResponse);

        // Act & Assert
        expect(
          () => apiService.cleanupRemoteEvent('test-public-id'),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('requestSignedUpload', () {
      test('should create proper request body', () async {
        // Arrange
        final responseBody = jsonEncode({
          'cloud_name': 'test-cloud',
          'api_key': 'test-key',
          'signature': 'test-signature',
          'timestamp': 1234567890,
          'public_id': 'test-public-id',
        });

        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.body).thenReturn(responseBody);
        
        when(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        )).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.requestSignedUpload(
          nostrPubkey: 'test-pubkey',
          fileSize: 1024000,
          mimeType: 'video/mp4',
          title: 'Test Video',
          hashtags: ['test', 'video'],
        );

        // Assert
        expect(result['cloud_name'], 'test-cloud');
        expect(result['api_key'], 'test-key');

        // Verify request body
        final captured = verify(() => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: captureAny(named: 'body'),
        )).captured.first as String;

        final requestData = jsonDecode(captured);
        expect(requestData['nostr_pubkey'], 'test-pubkey');
        expect(requestData['file_size'], 1024000);
        expect(requestData['mime_type'], 'video/mp4');
        expect(requestData['title'], 'Test Video');
        expect(requestData['hashtags'], ['test', 'video']);
      });
    });

    group('testConnection', () {
      test('should return true for healthy API', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        
        when(() => mockClient.get(any())).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.testConnection();

        // Assert
        expect(result, true);
      });

      test('should return false for unhealthy API', () async {
        // Arrange
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(500);
        
        when(() => mockClient.get(any())).thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.testConnection();

        // Assert
        expect(result, false);
      });

      test('should return false on network error', () async {
        // Arrange
        when(() => mockClient.get(any())).thenThrow(Exception('Network error'));

        // Act
        final result = await apiService.testConnection();

        // Assert
        expect(result, false);
      });
    });

    group('getUserUploadStatus', () {
      test('should return upload status data', () async {
        // Arrange
        final responseBody = jsonEncode({
          'total_uploads': 5,
          'pending_uploads': 2,
          'processing_uploads': 1,
          'published_uploads': 2,
        });

        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.body).thenReturn(responseBody);
        
        when(() => mockClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => mockResponse);

        // Act
        final result = await apiService.getUserUploadStatus();

        // Assert
        expect(result['total_uploads'], 5);
        expect(result['pending_uploads'], 2);
        expect(result['processing_uploads'], 1);
        expect(result['published_uploads'], 2);
      });
    });
  });

  group('ApiException', () {
    test('should format error message correctly', () {
      // Act
      final exception = ApiException('Test error', statusCode: 404);

      // Assert
      expect(exception.toString(), 'ApiException: Test error (404)');
    });

    test('should handle missing status code', () {
      // Act
      final exception = ApiException('Test error');

      // Assert
      expect(exception.toString(), 'ApiException: Test error (no status)');
    });
  });
}
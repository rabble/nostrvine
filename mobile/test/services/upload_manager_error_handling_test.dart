// ABOUTME: Tests for upload error categorization, retry logic,
// ABOUTME: and user-friendly error messages in UploadManager.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload_manager.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockBlossomUploadService mockBlossomService;
  late UploadManager uploadManager;
  late Directory testDir;

  /// Mock the connectivity plugin to return [result].
  void mockConnectivity(String result) {
    const channel = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'check') return [result];
          return null;
        });
  }

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp(
      'upload_manager_error_test_',
    );

    Hive.init(testDir.path);

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UploadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PendingUploadAdapter());
    }

    mockBlossomService = _MockBlossomUploadService();
    uploadManager = UploadManager(blossomService: mockBlossomService);

    mockConnectivity('wifi');

    await uploadManager.initialize();
  });

  tearDown(() async {
    uploadManager.dispose();
    try {
      await Hive.close();
    } on PathNotFoundException catch (_) {
      // Hive may already have removed the lock file during async shutdown.
    }
    try {
      await testDir.delete(recursive: true);
    } on PathNotFoundException catch (_) {
      // Lock file may already be deleted by Hive.close().
    }
  });

  group(BlossomUploadFailureException, () {
    test('stores message and statusCode', () {
      const exception = BlossomUploadFailureException(
        'Server error',
        statusCode: 502,
      );

      expect(exception.message, equals('Server error'));
      expect(exception.statusCode, equals(502));
    });

    test('toString returns message', () {
      const exception = BlossomUploadFailureException('Bad gateway');

      expect(exception.toString(), equals('Bad gateway'));
    });

    test('statusCode defaults to null', () {
      const exception = BlossomUploadFailureException('Unknown');

      expect(exception.statusCode, isNull);
    });
  });

  group('isRetriableError', () {
    group('BlossomUploadFailureException with statusCode', () {
      test('returns true for 408 request timeout', () {
        const error = BlossomUploadFailureException(
          'Request Timeout',
          statusCode: 408,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 429 rate limited', () {
        const error = BlossomUploadFailureException(
          'Rate limited',
          statusCode: 429,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 500 internal server error', () {
        const error = BlossomUploadFailureException(
          'Internal Server Error',
          statusCode: 500,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 502 bad gateway', () {
        const error = BlossomUploadFailureException(
          'Bad Gateway',
          statusCode: 502,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 503 service unavailable', () {
        const error = BlossomUploadFailureException(
          'Service Unavailable',
          statusCode: 503,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns true for 504 gateway timeout', () {
        const error = BlossomUploadFailureException(
          'Gateway Timeout',
          statusCode: 504,
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('returns false for 501 not implemented', () {
        const error = BlossomUploadFailureException(
          'Not Implemented',
          statusCode: 501,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 505 http version not supported', () {
        const error = BlossomUploadFailureException(
          'HTTP Version Not Supported',
          statusCode: 505,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 400 bad request', () {
        const error = BlossomUploadFailureException(
          'Bad Request',
          statusCode: 400,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 401 unauthorized', () {
        const error = BlossomUploadFailureException(
          'Unauthorized',
          statusCode: 401,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 403 forbidden', () {
        const error = BlossomUploadFailureException(
          'Forbidden',
          statusCode: 403,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 404 not found', () {
        const error = BlossomUploadFailureException(
          'Not Found',
          statusCode: 404,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });

      test('returns false for 413 payload too large', () {
        const error = BlossomUploadFailureException(
          'Payload Too Large',
          statusCode: 413,
        );

        expect(uploadManager.isRetriableError(error), isFalse);
      });
    });

    group('BlossomUploadFailureException without statusCode', () {
      test('falls back to string matching for timeout', () {
        const error = BlossomUploadFailureException(
          'Connection timeout',
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });

      test('falls back to string matching for network error', () {
        const error = BlossomUploadFailureException(
          'Network error: connection refused',
        );

        expect(uploadManager.isRetriableError(error), isTrue);
      });
    });

    group('generic exceptions (string matching fallback)', () {
      test('returns true for timeout errors', () {
        expect(
          uploadManager.isRetriableError(Exception('Connection timeout')),
          isTrue,
        );
      });

      test('returns true for connection errors', () {
        expect(
          uploadManager.isRetriableError(Exception('Cannot connect to server')),
          isTrue,
        );
      });

      test('returns true for socket errors', () {
        expect(
          uploadManager.isRetriableError(Exception('Socket closed')),
          isTrue,
        );
      });

      test('returns false for file not found', () {
        expect(
          uploadManager.isRetriableError(Exception('File not found')),
          isFalse,
        );
      });

      test('returns false for auth errors', () {
        expect(
          uploadManager.isRetriableError(Exception('Authentication failed')),
          isFalse,
        );
      });

      test('returns false for permission errors', () {
        expect(
          uploadManager.isRetriableError(Exception('Permission denied')),
          isFalse,
        );
      });

      test('returns true for unknown errors by default', () {
        expect(
          uploadManager.isRetriableError(Exception('Something unexpected')),
          isTrue,
        );
      });
    });
  });

  group('categorizeError', () {
    group('BlossomUploadFailureException with statusCode', () {
      test('returns TIMEOUT for 408', () async {
        const error = BlossomUploadFailureException(
          'Request Timeout',
          statusCode: 408,
        );

        expect(await uploadManager.categorizeError(error), equals('TIMEOUT'));
      });

      test('returns FILE_TOO_LARGE for 413', () async {
        const error = BlossomUploadFailureException(
          'Payload Too Large',
          statusCode: 413,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('FILE_TOO_LARGE'),
        );
      });

      test('returns RATE_LIMITED for 429', () async {
        const error = BlossomUploadFailureException(
          'Too Many Requests',
          statusCode: 429,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('RATE_LIMITED'),
        );
      });

      test('returns AUTHENTICATION for 401', () async {
        const error = BlossomUploadFailureException(
          'Unauthorized',
          statusCode: 401,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('AUTHENTICATION'),
        );
      });

      test('returns AUTHENTICATION for 403', () async {
        const error = BlossomUploadFailureException(
          'Forbidden',
          statusCode: 403,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('AUTHENTICATION'),
        );
      });

      test('returns SERVER_UNAVAILABLE for 502', () async {
        const error = BlossomUploadFailureException(
          'Bad Gateway',
          statusCode: 502,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_UNAVAILABLE'),
        );
      });

      test('returns SERVER_UNAVAILABLE for 503', () async {
        const error = BlossomUploadFailureException(
          'Service Unavailable',
          statusCode: 503,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_UNAVAILABLE'),
        );
      });

      test('returns SERVER_UNAVAILABLE for 504', () async {
        const error = BlossomUploadFailureException(
          'Gateway Timeout',
          statusCode: 504,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_UNAVAILABLE'),
        );
      });

      test('returns SERVER_ERROR for 500', () async {
        const error = BlossomUploadFailureException(
          'Internal Server Error',
          statusCode: 500,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_ERROR'),
        );
      });

      test('returns SERVER_ERROR for 501', () async {
        const error = BlossomUploadFailureException(
          'Not Implemented',
          statusCode: 501,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('SERVER_ERROR'),
        );
      });

      test('returns CLIENT_ERROR for 400', () async {
        const error = BlossomUploadFailureException(
          'Bad Request',
          statusCode: 400,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('CLIENT_ERROR'),
        );
      });

      test('returns CLIENT_ERROR for 404', () async {
        const error = BlossomUploadFailureException(
          'Not Found',
          statusCode: 404,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('CLIENT_ERROR'),
        );
      });

      test('returns CLIENT_ERROR for 422', () async {
        const error = BlossomUploadFailureException(
          'Unprocessable Entity',
          statusCode: 422,
        );

        expect(
          await uploadManager.categorizeError(error),
          equals('CLIENT_ERROR'),
        );
      });
    });

    group('no internet', () {
      test('returns NO_INTERNET when connectivity is none', () async {
        mockConnectivity('none');

        final error = Exception('Some error');

        expect(
          await uploadManager.categorizeError(error),
          equals('NO_INTERNET'),
        );
      });
    });

    group('string matching fallback', () {
      test('returns DNS_ERROR for host lookup failures', () async {
        final error = Exception('Failed to lookup host');

        expect(
          await uploadManager.categorizeError(error),
          equals('DNS_ERROR'),
        );
      });

      test('returns DNS_ERROR for DNS resolution failures', () async {
        final error = Exception('DNS resolution failed');

        expect(
          await uploadManager.categorizeError(error),
          equals('DNS_ERROR'),
        );
      });

      test('returns TIMEOUT for timeout errors', () async {
        final error = Exception('Connection timeout');

        expect(
          await uploadManager.categorizeError(error),
          equals('TIMEOUT'),
        );
      });

      test('returns SLOW_CONNECTION for timeout on cellular', () async {
        mockConnectivity('mobile');

        final error = Exception('Connection timeout');

        expect(
          await uploadManager.categorizeError(error),
          equals('SLOW_CONNECTION'),
        );
      });

      test('returns NETWORK_ERROR for connection errors', () async {
        final error = Exception('Cannot connect to server');

        expect(
          await uploadManager.categorizeError(error),
          equals('NETWORK_ERROR'),
        );
      });

      test('returns FILE_NOT_FOUND for missing files', () async {
        final error = Exception('File not found');

        expect(
          await uploadManager.categorizeError(error),
          equals('FILE_NOT_FOUND'),
        );
      });

      test('returns OUT_OF_MEMORY for memory errors', () async {
        final error = Exception('Out of memory');

        expect(
          await uploadManager.categorizeError(error),
          equals('OUT_OF_MEMORY'),
        );
      });

      test('returns PERMISSION_DENIED for permission errors', () async {
        final error = Exception('Permission denied');

        expect(
          await uploadManager.categorizeError(error),
          equals('PERMISSION_DENIED'),
        );
      });

      test('returns UNKNOWN for unrecognized errors', () async {
        final error = Exception('Something completely unexpected');

        expect(
          await uploadManager.categorizeError(error),
          equals('UNKNOWN'),
        );
      });
    });
  });

  group('getUserFriendlyErrorMessage', () {
    test('NO_INTERNET', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'NO_INTERNET',
          ConnectivityResult.none,
        ),
        contains('No internet connection'),
      );
    });

    test('SLOW_CONNECTION', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'SLOW_CONNECTION',
          ConnectivityResult.mobile,
        ),
        contains('WiFi'),
      );
    });

    test('TIMEOUT', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'TIMEOUT',
          ConnectivityResult.wifi,
        ),
        contains('timed out'),
      );
    });

    test('NETWORK_ERROR includes network type', () {
      final message = uploadManager.getUserFriendlyErrorMessage(
        'NETWORK_ERROR',
        ConnectivityResult.wifi,
      );

      expect(message, contains('WiFi'));
      expect(message, contains('Network error'));
    });

    test('DNS_ERROR', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'DNS_ERROR',
          ConnectivityResult.wifi,
        ),
        contains('Could not reach'),
      );
    });

    test('FILE_NOT_FOUND', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'FILE_NOT_FOUND',
          ConnectivityResult.wifi,
        ),
        contains('not found'),
      );
    });

    test('FILE_TOO_LARGE', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'FILE_TOO_LARGE',
          ConnectivityResult.wifi,
        ),
        contains('too large'),
      );
    });

    test('AUTHENTICATION', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'AUTHENTICATION',
          ConnectivityResult.wifi,
        ),
        contains('sign in'),
      );
    });

    test('RATE_LIMITED', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'RATE_LIMITED',
          ConnectivityResult.wifi,
        ),
        contains('Too many uploads'),
      );
    });

    test('SERVER_UNAVAILABLE', () {
      final message = uploadManager.getUserFriendlyErrorMessage(
        'SERVER_UNAVAILABLE',
        ConnectivityResult.wifi,
      );

      expect(message, contains('temporarily unavailable'));
      expect(message, contains('retry'));
    });

    test('SERVER_ERROR', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'SERVER_ERROR',
          ConnectivityResult.wifi,
        ),
        contains('encountered an error'),
      );
    });

    test('CLIENT_ERROR', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'CLIENT_ERROR',
          ConnectivityResult.wifi,
        ),
        contains('request failed'),
      );
    });

    test('UNKNOWN returns default message', () {
      expect(
        uploadManager.getUserFriendlyErrorMessage(
          'UNKNOWN',
          ConnectivityResult.wifi,
        ),
        contains('Upload failed'),
      );
    });
  });
}

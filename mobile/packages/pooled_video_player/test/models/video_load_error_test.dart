import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('VideoLoadError', () {
    group('Constructor', () {
      test('creates with required fields', () {
        final timestamp = DateTime.now();
        final error = VideoLoadError(
          index: 5,
          videoId: 'video-123',
          error: Exception('Test error'),
          timestamp: timestamp,
        );

        expect(error.index, 5);
        expect(error.videoId, 'video-123');
        expect(error.error, isA<Exception>());
        expect(error.timestamp, timestamp);
      });

      test('retryCount defaults to 0', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Test'),
          timestamp: DateTime.now(),
        );

        expect(error.retryCount, 0);
      });

      test('stackTrace is optional', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Test'),
          timestamp: DateTime.now(),
        );

        expect(error.stackTrace, isNull);
      });

      test('stackTrace can be provided', () {
        final stackTrace = StackTrace.current;
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Test'),
          timestamp: DateTime.now(),
          stackTrace: stackTrace,
        );

        expect(error.stackTrace, stackTrace);
      });

      test('retryCount can be provided', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Test'),
          timestamp: DateTime.now(),
          retryCount: 3,
        );

        expect(error.retryCount, 3);
      });
    });

    group('copyWithIncrementedRetry', () {
      test('increments retryCount by 1', () {
        final original = VideoLoadError(
          index: 5,
          videoId: 'video-123',
          error: Exception('Test'),
          timestamp: DateTime.now(),
          retryCount: 2,
        );

        final copy = original.copyWithIncrementedRetry();

        expect(copy.retryCount, 3);
      });

      test('preserves other fields', () {
        final stackTrace = StackTrace.current;
        final original = VideoLoadError(
          index: 5,
          videoId: 'video-123',
          error: Exception('Test error'),
          timestamp: DateTime.now(),
          stackTrace: stackTrace,
          retryCount: 1,
        );

        final copy = original.copyWithIncrementedRetry();

        expect(copy.index, original.index);
        expect(copy.videoId, original.videoId);
        expect(copy.error, original.error);
        expect(copy.stackTrace, original.stackTrace);
      });

      test('updates timestamp to now', () {
        final oldTimestamp = DateTime(2024);
        final original = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Test'),
          timestamp: oldTimestamp,
        );

        final copy = original.copyWithIncrementedRetry();

        expect(copy.timestamp.isAfter(oldTimestamp), true);
      });

      test('creates new instance (immutable)', () {
        final original = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Test'),
          timestamp: DateTime.now(),
        );

        final copy = original.copyWithIncrementedRetry();

        expect(identical(copy, original), false);
        expect(original.retryCount, 0); // Original unchanged
        expect(copy.retryCount, 1);
      });
    });

    group('message', () {
      test('returns VideoPlayerException.message for VideoPlayerException', () {
        const exception = VideoLoadFailedException(
          videoId: 'video-123',
          url: 'https://example.com/video.mp4',
          reason: 'Network error',
        );

        final error = VideoLoadError(
          index: 0,
          videoId: 'video-123',
          error: exception,
          timestamp: DateTime.now(),
        );

        expect(error.message, exception.message);
      });

      test(
        'returns error.toString() for non-VideoPlayerException errors',
        () {
          final exception = Exception('Generic error');

          final error = VideoLoadError(
            index: 0,
            videoId: 'video-1',
            error: exception,
            timestamp: DateTime.now(),
          );

          expect(error.message, exception.toString());
        },
      );

      test('returns message for PlayerPoolExhaustedException', () {
        const exception = PlayerPoolExhaustedException(
          totalPlayers: 5,
          maxPlayers: 5,
          inUse: 5,
          available: 0,
        );

        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: exception,
          timestamp: DateTime.now(),
        );

        expect(error.message, exception.message);
      });
    });

    group('isRecoverable', () {
      test('returns true for PlayerPoolExhaustedException', () {
        const exception = PlayerPoolExhaustedException(
          totalPlayers: 5,
          maxPlayers: 5,
          inUse: 5,
          available: 0,
        );

        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: exception,
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, true);
      });

      test('returns true for PreloadCancelledException', () {
        const exception = PreloadCancelledException(
          index: 0,
          videoId: 'video-1',
        );

        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: exception,
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, true);
      });

      test('returns true for network errors', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Network error occurred'),
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, true);
      });

      test('returns true for timeout errors', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Request timeout'),
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, true);
      });

      test('returns true for connection errors', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Connection refused'),
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, true);
      });

      test('returns true for socket errors', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Socket exception'),
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, true);
      });

      test('returns false for codec errors', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Unsupported codec'),
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, false);
      });

      test('returns false for generic errors', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('Something went wrong'),
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, false);
      });

      test('case insensitive matching for network', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('NETWORK ERROR'),
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, true);
      });

      test('case insensitive matching for timeout', () {
        final error = VideoLoadError(
          index: 0,
          videoId: 'video-1',
          error: Exception('TIMEOUT occurred'),
          timestamp: DateTime.now(),
        );

        expect(error.isRecoverable, true);
      });
    });

    group('toString', () {
      test('includes index, videoId, retryCount, and message', () {
        final error = VideoLoadError(
          index: 5,
          videoId: 'video-123',
          error: Exception('Test error'),
          timestamp: DateTime.now(),
          retryCount: 2,
        );

        final string = error.toString();

        expect(string, contains('index: 5'));
        expect(string, contains('videoId: video-123'));
        expect(string, contains('retryCount: 2'));
        expect(string, contains('message:'));
      });
    });
  });
}

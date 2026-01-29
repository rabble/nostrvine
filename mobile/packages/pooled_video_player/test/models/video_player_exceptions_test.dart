import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('VideoPlayerException', () {
    test('message returns the provided message', () {
      const exception = _TestVideoPlayerException('Test error message');

      expect(exception.message, 'Test error message');
    });

    test('cause is optional and can be null', () {
      const exception = _TestVideoPlayerException('Test error');

      expect(exception.cause, isNull);
    });

    test('cause can store underlying error', () {
      final cause = Exception('Underlying error');
      final exception = _TestVideoPlayerException('Test error', cause);

      expect(exception.cause, cause);
    });

    test('toString includes exception type and message', () {
      const exception = _TestVideoPlayerException('Test error message');

      expect(exception.toString(), 'VideoPlayerException: Test error message');
    });
  });

  group('PlayerPoolExhaustedException', () {
    test('creates with required pool state details', () {
      const exception = PlayerPoolExhaustedException(
        totalPlayers: 5,
        maxPlayers: 5,
        inUse: 5,
        available: 0,
      );

      expect(exception.totalPlayers, 5);
      expect(exception.maxPlayers, 5);
      expect(exception.inUse, 5);
      expect(exception.available, 0);
    });

    test('message includes all pool details', () {
      const exception = PlayerPoolExhaustedException(
        totalPlayers: 5,
        maxPlayers: 7,
        inUse: 4,
        available: 1,
      );

      expect(exception.message, contains('Total: 5'));
      expect(exception.message, contains('max: 7'));
      expect(exception.message, contains('in use: 4'));
      expect(exception.message, contains('available: 1'));
    });

    test('cause is optional', () {
      const exception = PlayerPoolExhaustedException(
        totalPlayers: 5,
        maxPlayers: 5,
        inUse: 5,
        available: 0,
      );

      expect(exception.cause, isNull);
    });

    test('cause can store underlying error', () {
      final cause = StateError('Pool error');
      final exception = PlayerPoolExhaustedException(
        totalPlayers: 5,
        maxPlayers: 5,
        inUse: 5,
        available: 0,
        cause: cause,
      );

      expect(exception.cause, cause);
    });

    test('toString includes exception type and message', () {
      const exception = PlayerPoolExhaustedException(
        totalPlayers: 5,
        maxPlayers: 7,
        inUse: 4,
        available: 1,
      );

      expect(exception.toString(), startsWith('PlayerPoolExhaustedException:'));
      expect(exception.toString(), contains('Player pool exhausted'));
    });
  });

  group('VideoLoadFailedException', () {
    test('creates with required video details', () {
      const exception = VideoLoadFailedException(
        videoId: 'video-123',
        url: 'https://example.com/video.mp4',
        reason: 'Network error',
      );

      expect(exception.videoId, 'video-123');
      expect(exception.url, 'https://example.com/video.mp4');
      expect(exception.reason, 'Network error');
    });

    test('message includes video ID and reason', () {
      const exception = VideoLoadFailedException(
        videoId: 'video-123',
        url: 'https://example.com/video.mp4',
        reason: 'Network error',
      );

      expect(exception.message, contains('video-123'));
      expect(exception.message, contains('Network error'));
    });

    test('cause is optional', () {
      const exception = VideoLoadFailedException(
        videoId: 'video-123',
        url: 'https://example.com/video.mp4',
        reason: 'Network error',
      );

      expect(exception.cause, isNull);
    });

    test('cause can store underlying error', () {
      final cause = Exception('Connection refused');
      final exception = VideoLoadFailedException(
        videoId: 'video-123',
        url: 'https://example.com/video.mp4',
        reason: 'Network error',
        cause: cause,
      );

      expect(exception.cause, cause);
    });

    test('toString includes exception type', () {
      const exception = VideoLoadFailedException(
        videoId: 'video-123',
        url: 'https://example.com/video.mp4',
        reason: 'Network error',
      );

      expect(exception.toString(), startsWith('VideoLoadFailedException:'));
    });
  });

  group('PreloadCancelledException', () {
    test('creates with required index and video ID', () {
      const exception = PreloadCancelledException(
        index: 5,
        videoId: 'video-123',
      );

      expect(exception.index, 5);
      expect(exception.videoId, 'video-123');
    });

    test('reason is optional and can be null', () {
      const exception = PreloadCancelledException(
        index: 5,
        videoId: 'video-123',
      );

      expect(exception.reason, isNull);
    });

    test('reason can store cancellation reason', () {
      const exception = PreloadCancelledException(
        index: 5,
        videoId: 'video-123',
        reason: 'User scrolled away',
      );

      expect(exception.reason, 'User scrolled away');
    });

    test('message includes index and video ID', () {
      const exception = PreloadCancelledException(
        index: 5,
        videoId: 'video-123',
      );

      expect(exception.message, contains('index 5'));
      expect(exception.message, contains('video-123'));
    });

    test('message includes reason when provided', () {
      const exception = PreloadCancelledException(
        index: 5,
        videoId: 'video-123',
        reason: 'User scrolled away',
      );

      expect(exception.message, contains('User scrolled away'));
    });

    test('message excludes reason when not provided', () {
      const exception = PreloadCancelledException(
        index: 5,
        videoId: 'video-123',
      );

      expect(exception.message, isNot(contains(':')));
    });

    test('toString includes exception type', () {
      const exception = PreloadCancelledException(
        index: 5,
        videoId: 'video-123',
      );

      expect(exception.toString(), startsWith('PreloadCancelledException:'));
    });
  });

  group('ControllerDisposedException', () {
    test('creates with controller name', () {
      const exception = ControllerDisposedException('VideoFeedController');

      expect(exception.message, contains('VideoFeedController'));
      expect(exception.message, contains('disposed'));
    });

    test('toString includes exception type', () {
      const exception = ControllerDisposedException('VideoFeedController');

      expect(exception.toString(), startsWith('ControllerDisposedException:'));
    });

    test('cause is null by default', () {
      const exception = ControllerDisposedException('VideoFeedController');

      expect(exception.cause, isNull);
    });
  });
}

/// Test implementation of VideoPlayerException for testing base class behavior.
class _TestVideoPlayerException extends VideoPlayerException {
  const _TestVideoPlayerException(super.message, [super.cause]);
}

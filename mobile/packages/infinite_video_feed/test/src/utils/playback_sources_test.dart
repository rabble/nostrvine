import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/models/video_error_type.dart';
import 'package:infinite_video_feed/src/utils/playback_sources.dart';
import 'package:models/models.dart';

/// Minimal [VideoEvent] factory for tests.
VideoEvent _makeVideo({String id = 'vid1', String? videoUrl}) => VideoEvent(
  id: id,
  pubkey: 'pubkey',
  createdAt: 0,
  content: '',
  timestamp: DateTime(2024),
  videoUrl: videoUrl,
);

const _hash =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _rawUrl = 'https://media.divine.video/$_hash';
const _hlsUrl = 'https://media.divine.video/$_hash/hls/master.m3u8';

void main() {
  group('resolvePlaybackSources', () {
    group('when videoUrl is null and no resolver', () {
      test('returns empty list', () {
        final video = _makeVideo();
        expect(resolvePlaybackSources(video), isEmpty);
      });
    });

    group('when videoUrl is empty and no resolver', () {
      test('returns empty list', () {
        final video = _makeVideo(videoUrl: '');
        expect(resolvePlaybackSources(video), isEmpty);
      });
    });

    group('when URL is a non-divine URL', () {
      test('returns [resolvedSource, originalUrl] deduplicated', () {
        final video = _makeVideo(videoUrl: 'https://example.com/video.mp4');
        expect(
          resolvePlaybackSources(video),
          equals(['https://example.com/video.mp4']),
        );
      });

      test('includes both resolver result and original when different', () {
        final video = _makeVideo(videoUrl: 'https://example.com/original.mp4');
        final result = resolvePlaybackSources(
          video,
          urlResolver: (_) => 'https://example.com/resolved.mp4',
        );
        expect(
          result,
          equals([
            'https://example.com/resolved.mp4',
            'https://example.com/original.mp4',
          ]),
        );
      });
    });

    group('when URL is a canonical HLS URL', () {
      test(
        'returns [hlsUrl, rawUrl] deduplicated when originalUrl equals hlsUrl',
        () {
          final video = _makeVideo(videoUrl: _hlsUrl);
          expect(
            resolvePlaybackSources(video),
            equals([_hlsUrl, _rawUrl]),
          );
        },
      );
    });

    group('when URL is the raw blob URL', () {
      test('returns [rawUrl, hlsUrl, originalUrl] deduplicated', () {
        final video = _makeVideo(videoUrl: _rawUrl);
        // raw == original → [rawUrl, hlsUrl]
        expect(
          resolvePlaybackSources(video),
          equals([_rawUrl, _hlsUrl]),
        );
      });

      test('includes originalUrl when it differs from rawUrl', () {
        const otherOriginal = 'https://example.com/original.mp4';
        final video = _makeVideo(videoUrl: otherOriginal);
        final result = resolvePlaybackSources(
          video,
          urlResolver: (_) => _rawUrl,
        );
        expect(result, equals([_rawUrl, _hlsUrl, otherOriginal]));
      });
    });

    group('when URL is a quality-specific Divine variant', () {
      const variantUrl = 'https://media.divine.video/$_hash/720p.mp4';

      test(
        'returns [variantUrl, hlsUrl, rawUrl, originalUrl] deduplicated',
        () {
          final video = _makeVideo(videoUrl: variantUrl);
          expect(
            resolvePlaybackSources(video),
            equals([variantUrl, _hlsUrl, _rawUrl]),
          );
        },
      );
    });

    group('with resolver returning null', () {
      test('falls back to videoUrl', () {
        final video = _makeVideo(videoUrl: 'https://example.com/video.mp4');
        final result = resolvePlaybackSources(
          video,
          urlResolver: (_) => null,
        );
        expect(result, equals(['https://example.com/video.mp4']));
      });
    });

    group('with resolver returning empty string', () {
      test('falls back to videoUrl', () {
        final video = _makeVideo(videoUrl: 'https://example.com/video.mp4');
        final result = resolvePlaybackSources(
          video,
          urlResolver: (_) => '',
        );
        expect(result, equals(['https://example.com/video.mp4']));
      });
    });
  });

  group('classifyVideoError', () {
    test('returns ageRestricted for 401', () {
      expect(
        classifyVideoError(errorMessage: 'HTTP 401 Unauthorized'),
        equals(VideoErrorType.ageRestricted),
      );
    });

    test('returns ageRestricted for "unauthorized" (case-insensitive)', () {
      expect(
        classifyVideoError(errorMessage: 'unauthorized access'),
        equals(VideoErrorType.ageRestricted),
      );
    });

    test('returns forbidden for 403', () {
      expect(
        classifyVideoError(errorMessage: 'HTTP 403 Forbidden'),
        equals(VideoErrorType.forbidden),
      );
    });

    test('returns forbidden for "forbidden" (case-insensitive)', () {
      expect(
        classifyVideoError(errorMessage: 'forbidden content'),
        equals(VideoErrorType.forbidden),
      );
    });

    test('returns notFound for 404', () {
      expect(
        classifyVideoError(errorMessage: 'HTTP 404 Not Found'),
        equals(VideoErrorType.notFound),
      );
    });

    test('returns notFound for "not found" (case-insensitive)', () {
      expect(
        classifyVideoError(errorMessage: 'content not found'),
        equals(VideoErrorType.notFound),
      );
    });

    test('returns notFound when source is a Divine blob URL', () {
      expect(
        classifyVideoError(source: _rawUrl),
        equals(VideoErrorType.notFound),
      );
    });

    test('returns generic for unknown error', () {
      expect(
        classifyVideoError(errorMessage: 'something went wrong'),
        equals(VideoErrorType.generic),
      );
    });

    test('returns generic when both message and source are null', () {
      expect(classifyVideoError(), equals(VideoErrorType.generic));
    });

    test('returns generic when source is not a Divine URL', () {
      expect(
        classifyVideoError(source: 'https://example.com/video.mp4'),
        equals(VideoErrorType.generic),
      );
    });
  });
}

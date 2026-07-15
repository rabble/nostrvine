// ABOUTME: Unit tests for resolveRenderAudioTracks.
// ABOUTME: Covers resolution, per-track skip-on-failure, and empty fallback.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/video_editor_audio_render.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// An [EditorAudio] whose [safeFilePath] always fails, standing in for a track
/// whose source cannot be resolved (e.g. a failed network download).
class _UnresolvableAudio extends EditorAudio {
  _UnresolvableAudio() : super(networkUrl: 'https://example.com/missing.mp3');

  @override
  Future<String> safeFilePath({String? fileExtension}) async {
    throw const FileSystemException('cannot resolve audio for render');
  }
}

AudioTrack _fileTrack({
  required String id,
  required String path,
  Duration startTime = const Duration(seconds: 1),
  Duration endTime = const Duration(seconds: 4),
  Duration audioStartTime = const Duration(milliseconds: 250),
  Duration audioEndTime = const Duration(seconds: 3),
  double volume = 0.5,
  bool loop = true,
}) {
  return AudioTrack(
    id: id,
    title: id,
    subtitle: 'test',
    duration: const Duration(seconds: 3),
    audio: EditorAudio.file(File(path)),
    startTime: startTime,
    endTime: endTime,
    audioStartTime: audioStartTime,
    audioEndTime: audioEndTime,
    volume: volume,
    loop: loop,
  );
}

AudioTrack _unresolvableTrack(String id) {
  return AudioTrack(
    id: id,
    title: id,
    subtitle: 'test',
    duration: const Duration(seconds: 3),
    audio: _UnresolvableAudio(),
  );
}

void main() {
  group('resolveRenderAudioTracks', () {
    test('returns an empty list for empty input', () async {
      final result = await resolveRenderAudioTracks(
        const <AudioTrack>[],
        logName: 'test',
      );

      expect(result, isEmpty);
    });

    test(
      'resolves a file-backed track to a VideoAudioTrack preserving timing, '
      'volume, and loop',
      () async {
        final result = await resolveRenderAudioTracks(
          [_fileTrack(id: 'a', path: '/tmp/a.mp3')],
          logName: 'test',
        );

        expect(result, hasLength(1));
        final track = result.single;
        expect(track.path, equals('/tmp/a.mp3'));
        expect(track.startTime, equals(const Duration(seconds: 1)));
        expect(track.endTime, equals(const Duration(seconds: 4)));
        expect(
          track.audioStartTime,
          equals(const Duration(milliseconds: 250)),
        );
        expect(track.audioEndTime, equals(const Duration(seconds: 3)));
        expect(track.volume, equals(0.5));
        expect(track.loop, isTrue);
      },
    );

    test(
      'skips a track that cannot be resolved while keeping the resolvable ones',
      () async {
        final result = await resolveRenderAudioTracks(
          [
            _unresolvableTrack('bad'),
            _fileTrack(id: 'good', path: '/tmp/good.mp3'),
          ],
          logName: 'test',
        );

        expect(result, hasLength(1));
        expect(result.single.path, equals('/tmp/good.mp3'));
      },
    );

    test('returns an empty list when no requested track resolves', () async {
      final result = await resolveRenderAudioTracks(
        [_unresolvableTrack('bad-1'), _unresolvableTrack('bad-2')],
        logName: 'test',
      );

      expect(result, isEmpty);
    });

    test(
      'clamps a track window that outlasts the video to the video duration',
      () async {
        // A full-length song (endTime 4s) muxed onto a ~1s stop-motion video
        // must not outlast the video track, or iOS freezes the last frame.
        final result = await resolveRenderAudioTracks(
          [
            _fileTrack(
              id: 'song',
              path: '/tmp/song.mp3',
              startTime: Duration.zero,
            ),
          ],
          logName: 'test',
          videoDuration: const Duration(seconds: 1),
        );

        expect(result.single.startTime, equals(Duration.zero));
        expect(result.single.endTime, equals(const Duration(seconds: 1)));
      },
    );

    test('leaves a track shorter than the video untouched', () async {
      final result = await resolveRenderAudioTracks(
        [
          _fileTrack(
            id: 'short',
            path: '/tmp/short.mp3',
            endTime: const Duration(seconds: 2),
          ),
        ],
        logName: 'test',
        videoDuration: const Duration(seconds: 6),
      );

      expect(result.single.startTime, equals(const Duration(seconds: 1)));
      expect(result.single.endTime, equals(const Duration(seconds: 2)));
    });
  });

  group('clampAudioWindowToVideo', () {
    test('returns the window unchanged when videoDuration is null', () {
      final result = clampAudioWindowToVideo(
        startTime: const Duration(seconds: 1),
        endTime: const Duration(seconds: 9),
        videoDuration: null,
      );

      expect(result.startTime, equals(const Duration(seconds: 1)));
      expect(result.endTime, equals(const Duration(seconds: 9)));
    });

    test('leaves a null endTime null (means "play to end of video")', () {
      final result = clampAudioWindowToVideo(
        startTime: Duration.zero,
        endTime: null,
        videoDuration: const Duration(seconds: 1),
      );

      expect(result.endTime, isNull);
    });

    test('clamps both start and end past the video to the video end', () {
      final result = clampAudioWindowToVideo(
        startTime: const Duration(seconds: 5),
        endTime: const Duration(seconds: 9),
        videoDuration: const Duration(seconds: 1),
      );

      expect(result.startTime, equals(const Duration(seconds: 1)));
      expect(result.endTime, equals(const Duration(seconds: 1)));
    });
  });
}

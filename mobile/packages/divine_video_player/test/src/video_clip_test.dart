import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  group(VideoClip, () {
    group('default constructor', () {
      test('sets uri and defaults', () {
        const clip = VideoClip(uri: '/path/to/video.mp4');

        expect(clip.uri, equals('/path/to/video.mp4'));
        expect(clip.start, equals(Duration.zero));
        expect(clip.end, isNull);
      });

      test('accepts start and end', () {
        const clip = VideoClip(
          uri: '/path/to/video.mp4',
          start: Duration(seconds: 5),
          end: Duration(seconds: 30),
        );

        expect(clip.start, equals(const Duration(seconds: 5)));
        expect(clip.end, equals(const Duration(seconds: 30)));
      });
    });

    group('file constructor', () {
      test('sets uri from path', () {
        const clip = VideoClip.file('/local/file.mp4');

        expect(clip.uri, equals('/local/file.mp4'));
        expect(clip.start, equals(Duration.zero));
        expect(clip.end, isNull);
      });

      test('accepts start and end', () {
        const clip = VideoClip.file(
          '/local/file.mp4',
          start: Duration(seconds: 2),
          end: Duration(seconds: 10),
        );

        expect(clip.start, equals(const Duration(seconds: 2)));
        expect(clip.end, equals(const Duration(seconds: 10)));
      });
    });

    group('network constructor', () {
      test('sets uri from url', () {
        const clip = VideoClip.network('https://example.com/video.mp4');

        expect(clip.uri, equals('https://example.com/video.mp4'));
        expect(clip.start, equals(Duration.zero));
        expect(clip.end, isNull);
      });

      test('accepts start and end', () {
        const clip = VideoClip.network(
          'https://example.com/video.mp4',
          start: Duration(seconds: 1),
          end: Duration(seconds: 20),
        );

        expect(clip.start, equals(const Duration(seconds: 1)));
        expect(clip.end, equals(const Duration(seconds: 20)));
      });
    });

    group('toMap', () {
      test('serializes without end', () {
        const clip = VideoClip(
          uri: '/path/video.mp4',
          start: Duration(seconds: 5),
        );
        final map = clip.toMap();

        expect(map['uri'], equals('/path/video.mp4'));
        expect(map['startMs'], equals(5000));
        expect(map['endMs'], isNull);
      });

      test('serializes with end', () {
        const clip = VideoClip(
          uri: '/path/video.mp4',
          start: Duration(seconds: 2),
          end: Duration(seconds: 10),
        );
        final map = clip.toMap();

        expect(map['uri'], equals('/path/video.mp4'));
        expect(map['startMs'], equals(2000));
        expect(map['endMs'], equals(10000));
      });

      test('serializes zero start', () {
        const clip = VideoClip(uri: 'test.mp4');
        final map = clip.toMap();

        expect(map['startMs'], isZero);
      });
    });

    group('asset', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('video_clip_test_');
        PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('copies asset data to temp file', () async {
        final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final bundle = _FakeAssetBundle(testBytes);

        final clip = await VideoClip.asset(
          'assets/test_video.mp4',
          start: const Duration(seconds: 1),
          end: const Duration(seconds: 5),
          bundle: bundle,
        );

        expect(clip.uri, contains('test_video.mp4'));
        expect(clip.start, equals(const Duration(seconds: 1)));
        expect(clip.end, equals(const Duration(seconds: 5)));
        expect(File(clip.uri).existsSync(), isTrue);
        expect(File(clip.uri).readAsBytesSync(), equals(testBytes));
      });
    });

    group('memory', () {
      late Directory tempDir;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('video_clip_test_');
        PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
      });

      tearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('writes bytes to temp file', () async {
        final bytes = Uint8List.fromList([10, 20, 30, 40]);

        final clip = await VideoClip.memory(
          bytes,
          fileName: 'test_clip.mp4',
          start: const Duration(seconds: 3),
          end: const Duration(seconds: 8),
        );

        expect(clip.uri, contains('test_clip.mp4'));
        expect(clip.start, equals(const Duration(seconds: 3)));
        expect(clip.end, equals(const Duration(seconds: 8)));
        expect(File(clip.uri).existsSync(), isTrue);
        expect(File(clip.uri).readAsBytesSync(), equals(bytes));
      });
    });
  });
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._tempPath);

  final String _tempPath;

  @override
  Future<String?> getTemporaryPath() async => _tempPath;
}

class _FakeAssetBundle extends Fake implements AssetBundle {
  _FakeAssetBundle(this._bytes);

  final Uint8List _bytes;

  @override
  Future<ByteData> load(String key) async => _bytes.buffer.asByteData();
}

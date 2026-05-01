import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';

/// Stream that throws synchronously inside [listen], triggering the
/// `on Object` catch block in [CancellableCacheOperation.fromStream].
class _SynchronouslyThrowingStream extends Stream<FileResponse> {
  @override
  StreamSubscription<FileResponse> listen(
    void Function(FileResponse event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => throw Exception('synchronous listen error');
}

class _ThrowingDownload implements CancellableDownload {
  @override
  Future<File?> get file => Future<File?>.error(Exception('download failed'));

  @override
  bool get isCancelled => false;

  @override
  void cancel() {}
}

void main() {
  group(CancellableCacheOperation, () {
    group('completed', () {
      test('file future completes with the provided file', () async {
        final mockFile = MockFile();
        final op = CancellableCacheOperation.completed(mockFile);

        expect(await op.file, equals(mockFile));
      });

      test('isCancelled is false', () {
        final op = CancellableCacheOperation.completed(MockFile());

        expect(op.isCancelled, isFalse);
      });
    });

    group('fromStream', () {
      test(
        'file future completes with file when FileInfo is received',
        () async {
          final controller = StreamController<FileResponse>();
          final mockFile = MockFile();
          final mockFileInfo = MockFileInfo();
          when(() => mockFileInfo.file).thenReturn(mockFile);

          final op = CancellableCacheOperation.fromStream(controller.stream);
          controller.add(mockFileInfo);
          await controller.close();

          expect(await op.file, equals(mockFile));
        },
      );

      test(
        'calls onCached with key and path when FileInfo is received',
        () async {
          final controller = StreamController<FileResponse>();
          final mockFile = MockFile();
          final mockFileInfo = MockFileInfo();
          when(() => mockFileInfo.file).thenReturn(mockFile);
          when(() => mockFile.path).thenReturn('/cached/video.mp4');

          String? capturedKey;
          String? capturedPath;

          final op = CancellableCacheOperation.fromStream(
            controller.stream,
            cacheKey: 'video_key',
            onCached: (key, path) {
              capturedKey = key;
              capturedPath = path;
            },
          );
          controller.add(mockFileInfo);
          await controller.close();
          await op.file;

          expect(capturedKey, equals('video_key'));
          expect(capturedPath, equals('/cached/video.mp4'));
        },
      );

      test('file future completes with null on stream error', () async {
        final controller = StreamController<FileResponse>();
        final op = CancellableCacheOperation.fromStream(controller.stream);

        controller.addError(Exception('network failure'));

        expect(await op.file, isNull);
      });

      test(
        'file future completes with null when stream closes without data',
        () async {
          final controller = StreamController<FileResponse>();
          final op = CancellableCacheOperation.fromStream(controller.stream);

          await controller.close();

          expect(await op.file, isNull);
        },
      );

      test('isCancelled is false before cancel is called', () async {
        final controller = StreamController<FileResponse>();
        final op = CancellableCacheOperation.fromStream(controller.stream);

        expect(op.isCancelled, isFalse);

        await controller.close();
      });

      test(
        'file future completes with null when stream.listen throws '
        'synchronously',
        () async {
          final op = CancellableCacheOperation.fromStream(
            _SynchronouslyThrowingStream(),
          );

          expect(await op.file, isNull);
        },
      );
    });

    group('cancel', () {
      test('sets isCancelled to true', () async {
        final controller = StreamController<FileResponse>();
        final op = CancellableCacheOperation.fromStream(controller.stream)
          ..cancel();

        expect(op.isCancelled, isTrue);

        await controller.close();
      });

      test('file future completes with null', () async {
        final controller = StreamController<FileResponse>();
        final op = CancellableCacheOperation.fromStream(controller.stream)
          ..cancel();

        expect(await op.file, isNull);

        await controller.close();
      });

      test('is idempotent when called multiple times', () async {
        final controller = StreamController<FileResponse>();
        final op = CancellableCacheOperation.fromStream(controller.stream)
          ..cancel()
          ..cancel();

        expect(op.isCancelled, isTrue);

        await controller.close();
      });

      test('is a no-op on an already-completed operation', () async {
        final mockFile = MockFile();
        final op = CancellableCacheOperation.completed(mockFile)..cancel();

        // File was already resolved; cancel must not override it.
        expect(await op.file, equals(mockFile));
      });
    });

    group('fromDownload', () {
      test('completes with null when download future throws', () async {
        final op = CancellableCacheOperation.fromDownload(
          _ThrowingDownload(),
          cacheKey: 'failing_key',
        );

        expect(await op.file, isNull);
      });
    });
  });
}

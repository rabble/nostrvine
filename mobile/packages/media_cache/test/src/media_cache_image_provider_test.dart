import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file/local.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

const _transparentPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0x18,
  0xDD,
  0x8D,
  0xB1,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaCacheImageProvider', () {
    setUpTestEnvironment();

    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    test(
      'cancels in-flight download when the last listener is removed',
      () async {
        const url = 'https://example.com/image.jpg';
        final cacheManager = _MockMediaCacheManager();
        final download = FakeCancellableDownload(
          url: url,
          targetFile: File('$testTempPath/pending.jpg'),
          headers: null,
        );
        final operation = CancellableCacheOperation.fromDownload(download);

        when(
          () => cacheManager.getFileFromCache(url),
        ).thenAnswer((_) async => null);
        when(
          () => cacheManager.cacheFileCancellable(
            url,
            key: url,
          ),
        ).thenReturn(operation);

        final provider = MediaCacheImageProvider(
          url,
          cacheManager: cacheManager,
        );
        final completer = provider.loadImage(
          provider,
          (buffer, {getTargetSize}) => Completer<ui.Codec>().future,
        );
        final listener = ImageStreamListener((image, synchronousCall) {
          image.dispose();
        });

        completer.addListener(listener);
        await Future<void>.delayed(Duration.zero);

        verify(() => cacheManager.getFileFromCache(url)).called(1);
        verify(
          () => cacheManager.cacheFileCancellable(
            url,
            key: url,
          ),
        ).called(1);
        expect(download.isCancelled, isFalse);

        completer.removeListener(listener);

        expect(download.isCancelled, isTrue);
      },
    );

    test(
      'keeps a shared in-flight download alive until every listener leaves',
      () async {
        const url = 'https://example.com/image.jpg';
        final cacheManager = _MockMediaCacheManager();
        final download = FakeCancellableDownload(
          url: url,
          targetFile: File('$testTempPath/shared.jpg'),
          headers: null,
        );
        final operation = CancellableCacheOperation.fromDownload(download);

        when(
          () => cacheManager.getFileFromCache(url),
        ).thenAnswer((_) async => null);
        when(
          () => cacheManager.cacheFileCancellable(
            url,
            key: url,
          ),
        ).thenReturn(operation);

        final provider = MediaCacheImageProvider(
          url,
          cacheManager: cacheManager,
        );
        final completer = provider.loadImage(
          provider,
          (buffer, {getTargetSize}) => Completer<ui.Codec>().future,
        );
        final firstListener = ImageStreamListener((image, synchronousCall) {
          image.dispose();
        });
        final secondListener = ImageStreamListener((image, synchronousCall) {
          image.dispose();
        });

        completer
          ..addListener(firstListener)
          ..addListener(secondListener);
        await Future<void>.delayed(Duration.zero);

        verify(() => cacheManager.getFileFromCache(url)).called(1);
        verify(
          () => cacheManager.cacheFileCancellable(
            url,
            key: url,
          ),
        ).called(1);

        completer.removeListener(firstListener);
        expect(download.isCancelled, isFalse);

        completer.removeListener(secondListener);
        expect(download.isCancelled, isTrue);
      },
    );

    test(
      'decodes an existing cached file without starting a new download',
      () async {
        const url = 'https://example.com/cached-image.jpg';
        final cacheManager = _MockMediaCacheManager();
        final imageFile = const LocalFileSystem().file(
          '$testTempPath/cached-image.png',
        )..writeAsBytesSync(Uint8List.fromList(_transparentPng));

        final fileInfo = MockFileInfo();
        when(() => fileInfo.file).thenReturn(imageFile);
        when(
          () => cacheManager.getFileFromCache(url),
        ).thenAnswer((_) async => fileInfo);

        var decodeCalled = false;
        final decodeAttempted = Completer<void>();
        final provider = MediaCacheImageProvider(
          url,
          cacheManager: cacheManager,
        );
        final completer = provider.loadImage(provider, (
          buffer, {
          getTargetSize,
        }) {
          decodeCalled = true;
          if (!decodeAttempted.isCompleted) {
            decodeAttempted.complete();
          }
          throw StateError('stop after verifying decode entry');
        });
        final listener = ImageStreamListener(
          (image, synchronousCall) {
            image.dispose();
          },
          onError: (error, stackTrace) {},
        );

        completer.addListener(listener);
        await decodeAttempted.future;

        expect(decodeCalled, isTrue);
        verify(() => cacheManager.getFileFromCache(url)).called(1);
        verifyNever(
          () => cacheManager.cacheFileCancellable(
            any(),
            key: any(named: 'key'),
          ),
        );

        completer.removeListener(listener);
      },
    );
  });
}

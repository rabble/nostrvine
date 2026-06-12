import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:media_cache/src/cancellable_downloader.dart';

class _CallbackClient extends http.BaseClient {
  _CallbackClient(this._onSend, {this.onClose});

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _onSend;
  final void Function()? onClose;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _onSend(request);

  @override
  void close() {
    onClose?.call();
    closed = true;
    super.close();
  }
}

void main() {
  group(HttpCancellableDownloader, () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cancellable_dl_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('downloads file successfully and forwards headers', () async {
      http.BaseRequest? capturedRequest;
      final client = _CallbackClient((request) async {
        capturedRequest = request;
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([
            utf8.encode('hello '),
            utf8.encode('world'),
          ]),
          200,
        );
      });

      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/nested/video.mp4');

      final download = downloader.download(
        url: 'https://example.com/video.mp4',
        targetFile: target,
        headers: {'Authorization': 'Bearer token'},
      );

      final file = await download.file;

      expect(file, isNotNull);
      expect(file!.path, equals(target.path));
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), equals('hello world'));
      expect(capturedRequest, isA<http.Request>());
      expect(
        (capturedRequest! as http.Request).headers['Authorization'],
        equals('Bearer token'),
      );
      expect(download.isCancelled, isFalse);
    });

    test('close releases the underlying client', () async {
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(const Stream.empty(), 200),
      );
      final downloader = HttpCancellableDownloader(client);

      await downloader.close();

      expect(client.closed, isTrue);
    });

    test(
      'download after close completes with null without using client',
      () async {
        var sendCalled = false;
        final client = _CallbackClient((_) async {
          sendCalled = true;
          return http.StreamedResponse(const Stream.empty(), 200);
        });
        final downloader = HttpCancellableDownloader(client);
        final target = File('${tempDir.path}/closed.mp4');

        await downloader.close();
        final download = downloader.download(
          url: 'https://example.com/closed.mp4',
          targetFile: target,
        )..cancel();

        expect(await download.file, isNull);
        expect(download.isCancelled, isFalse);
        expect(sendCalled, isFalse);
        expect(target.existsSync(), isFalse);
      },
    );

    test('close aborts a pending request before closing the client', () async {
      var inFlightRequests = 0;
      var closedAfterAbort = false;
      final client = _CallbackClient(
        (request) async {
          inFlightRequests += 1;
          expect(request, isA<http.AbortableRequest>());
          await (request as http.AbortableRequest).abortTrigger;
          inFlightRequests -= 1;
          throw http.RequestAbortedException(request.url);
        },
        onClose: () {
          closedAfterAbort = inFlightRequests == 0;
        },
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/pending_close.mp4');

      final download = downloader.download(
        url: 'https://example.com/pending.mp4',
        targetFile: target,
      );
      await Future<void>.delayed(Duration.zero);

      await downloader.close();

      expect(await download.file, isNull);
      expect(download.isCancelled, isTrue);
      expect(client.closed, isTrue);
      expect(closedAfterAbort, isTrue);
      expect(target.existsSync(), isFalse);
    });

    test('close waits for active response stream cancellation', () async {
      var streamCancelled = false;
      var closedAfterStreamCancel = false;
      final controller = StreamController<List<int>>(
        onCancel: () async {
          await Future<void>.delayed(Duration.zero);
          streamCancelled = true;
        },
      );
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(controller.stream, 200),
        onClose: () {
          closedAfterStreamCancel = streamCancelled;
        },
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/stream_close.mp4');

      final download = downloader.download(
        url: 'https://example.com/stream.mp4',
        targetFile: target,
      );
      await Future<void>.delayed(Duration.zero);

      await downloader.close();

      expect(await download.file, isNull);
      expect(download.isCancelled, isTrue);
      expect(client.closed, isTrue);
      expect(closedAfterStreamCancel, isTrue);
      expect(target.existsSync(), isFalse);
    });

    test('returns null for non-2xx responses', () async {
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('not found')),
          404,
        ),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/non_success.mp4');

      final file = await downloader
          .download(
            url: 'https://example.com/missing.mp4',
            targetFile: target,
          )
          .file;

      expect(file, isNull);
      expect(target.existsSync(), isFalse);
    });

    test(
      'returns null when stream emits an error and cleans partial file',
      () async {
        final controller = StreamController<List<int>>();
        final client = _CallbackClient(
          (_) async => http.StreamedResponse(controller.stream, 200),
        );
        final downloader = HttpCancellableDownloader(client);
        final target = File('${tempDir.path}/error_stream.mp4');

        final future = downloader
            .download(
              url: 'https://example.com/error.mp4',
              targetFile: target,
            )
            .file;

        controller
          ..add(utf8.encode('partial-bytes'))
          ..addError(Exception('stream failure'));
        await controller.close();

        final file = await future;
        expect(file, isNull);
        expect(target.existsSync(), isFalse);
      },
    );

    test('returns null when client send throws', () async {
      final client = _CallbackClient((_) async {
        throw Exception('send failed');
      });
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/send_throw.mp4');

      final file = await downloader
          .download(
            url: 'https://example.com/fail.mp4',
            targetFile: target,
          )
          .file;

      expect(file, isNull);
      expect(target.existsSync(), isFalse);
    });

    test('rejects non-https urls before sending request', () async {
      var sendCalled = false;
      final client = _CallbackClient((_) async {
        sendCalled = true;
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('insecure')),
          200,
        );
      });
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/http_not_allowed.mp4');

      final file = await downloader
          .download(
            url: 'http://example.com/insecure.mp4',
            targetFile: target,
          )
          .file;

      expect(file, isNull);
      expect(sendCalled, isFalse);
      expect(target.existsSync(), isFalse);
    });

    test('cancels before response arrives', () async {
      final responseCompleter = Completer<http.StreamedResponse>();
      final client = _CallbackClient((_) => responseCompleter.future);
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/cancel_before_response.mp4');

      final dl = downloader.download(
        url: 'https://example.com/cancel.mp4',
        targetFile: target,
      )..cancel();

      responseCompleter.complete(
        http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('late bytes')),
          200,
        ),
      );

      final file = await dl.file;
      expect(file, isNull);
      expect(dl.isCancelled, isTrue);
      expect(target.existsSync(), isFalse);
    });

    test('cancel after completion is a no-op', () async {
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('ok')),
          200,
        ),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/completed_then_cancel.mp4');

      final dl = downloader.download(
        url: 'https://example.com/done.mp4',
        targetFile: target,
      );
      final file = await dl.file;

      expect(file, isNotNull);
      dl.cancel();

      // Already completed downloads remain non-cancelled.
      expect(dl.isCancelled, isFalse);
      expect(target.existsSync(), isTrue);
    });

    test(
      'cancel during stream completion keeps successful file',
      () async {
        final controller = StreamController<List<int>>();
        final client = _CallbackClient(
          (_) async => http.StreamedResponse(controller.stream, 200),
        );
        final downloader = HttpCancellableDownloader(client);
        final target = File('${tempDir.path}/cancel_during_done.mp4');

        final dl = downloader.download(
          url: 'https://example.com/cancel_during_done.mp4',
          targetFile: target,
        );

        // Ensure listener is attached before we trigger completion.
        await Future<void>.delayed(const Duration(milliseconds: 1));
        controller.add(utf8.encode('partial'));
        await controller.close();

        // Trigger cancellation while stream completion is in-flight.
        dl.cancel();

        final file = await dl.file;
        expect(file, isNotNull);
        expect(dl.isCancelled, isFalse);
        expect(target.existsSync(), isTrue);
      },
    );

    test('cancel queued before stream done deletes the target file', () async {
      final controller = StreamController<List<int>>();
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(controller.stream, 200),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/cancel_before_done.mp4');

      final dl = downloader.download(
        url: 'https://example.com/cancel_before_done.mp4',
        targetFile: target,
      );

      await Future<void>.delayed(const Duration(milliseconds: 1));
      controller.add(utf8.encode('partial'));
      final closeFuture = controller.close();
      dl.cancel();

      final file = await dl.file;
      await closeFuture;

      expect(file, isNull);
      expect(dl.isCancelled, isTrue);
      expect(target.existsSync(), isFalse);
    });
  });
}

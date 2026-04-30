import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';

import 'helpers/mocks.dart';

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

    group('fromFuture', () {
      test('file future completes with the file', () async {
        final mockFile = MockFile();
        final completer = Completer<File?>();
        final op = CancellableCacheOperation.fromFuture(completer.future);

        completer.complete(mockFile);

        expect(await op.file, equals(mockFile));
      });

      test('file future completes with null when future resolves null',
          () async {
        final completer = Completer<File?>();
        final op = CancellableCacheOperation.fromFuture(completer.future);

        completer.complete(null);

        expect(await op.file, isNull);
      });

      test('file future completes with null on error', () async {
        final completer = Completer<File?>();
        final op = CancellableCacheOperation.fromFuture(completer.future);

        completer.completeError(Exception('download failed'));

        expect(await op.file, isNull);
      });

      test('didStall is true when stallTimeout expires', () async {
        final completer = Completer<File?>();
        final op = CancellableCacheOperation.fromFuture(
          completer.future,
          stallTimeout: const Duration(milliseconds: 10),
        );

        // Let the stall timeout fire without completing the future.
        expect(await op.file, isNull);
        expect(op.didStall, isTrue);

        // Clean up the dangling completer.
        completer.complete(null);
      });

      test('didStall is false when completed before stallTimeout', () async {
        final mockFile = MockFile();
        final completer = Completer<File?>();
        final op = CancellableCacheOperation.fromFuture(
          completer.future,
          stallTimeout: const Duration(seconds: 10),
        );

        completer.complete(mockFile);

        expect(await op.file, equals(mockFile));
        expect(op.didStall, isFalse);
      });

      test('isCancelled is false before cancel is called', () async {
        final completer = Completer<File?>();
        final op = CancellableCacheOperation.fromFuture(completer.future);

        expect(op.isCancelled, isFalse);

        completer.complete(null);
      });
    });

    group('cancel', () {
      test('sets isCancelled to true', () {
        final op =
            CancellableCacheOperation.fromFuture(Completer<File?>().future)
              ..cancel();

        expect(op.isCancelled, isTrue);
      });

      test('file future completes with null', () async {
        final op =
            CancellableCacheOperation.fromFuture(Completer<File?>().future)
              ..cancel();

        expect(await op.file, isNull);
      });

      test('is idempotent when called multiple times', () {
        final op =
            CancellableCacheOperation.fromFuture(Completer<File?>().future)
              ..cancel()
              ..cancel();

        expect(op.isCancelled, isTrue);
      });

      test('is a no-op on an already-completed operation', () async {
        final mockFile = MockFile();
        final op = CancellableCacheOperation.completed(mockFile)..cancel();

        // File was already resolved; cancel must not override it.
        expect(await op.file, equals(mockFile));
      });
    });
  });
}

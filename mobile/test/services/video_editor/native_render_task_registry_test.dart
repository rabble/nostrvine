import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/native_render_task_registry.dart';

void main() {
  group(NativeRenderTaskRegistry, () {
    tearDown(NativeRenderTaskRegistry.reset);

    group('track', () {
      test('exposes the task as active while it is in flight', () async {
        final gate = Completer<String>();

        final tracked = NativeRenderTaskRegistry.track(
          'task-1',
          () => gate.future,
        );

        expect(NativeRenderTaskRegistry.activeTaskIds, contains('task-1'));

        gate.complete('done');
        await tracked;

        expect(NativeRenderTaskRegistry.activeTaskIds, isEmpty);
      });

      test('returns the operation result', () async {
        final result = await NativeRenderTaskRegistry.track(
          'task-1',
          () async => '/tmp/out.mp4',
        );

        expect(result, equals('/tmp/out.mp4'));
      });

      test('stops tracking a task that throws, and rethrows', () async {
        await expectLater(
          NativeRenderTaskRegistry.track<void>(
            'task-1',
            () async => throw StateError('render failed'),
          ),
          throwsStateError,
        );

        expect(NativeRenderTaskRegistry.activeTaskIds, isEmpty);
      });

      test('tracks concurrent tasks independently', () async {
        final first = Completer<void>();
        final second = Completer<void>();

        final tracked = [
          NativeRenderTaskRegistry.track('task-1', () => first.future),
          NativeRenderTaskRegistry.track('task-2', () => second.future),
        ];

        expect(
          NativeRenderTaskRegistry.activeTaskIds,
          containsAll(<String>['task-1', 'task-2']),
        );

        first.complete();
        await tracked.first;

        expect(NativeRenderTaskRegistry.activeTaskIds, equals({'task-2'}));

        second.complete();
        await Future.wait(tracked);
      });

      // A re-registered id belongs to the newer call, so the displaced one
      // must not remove it on the way out — otherwise the live task silently
      // stops being cancellable at teardown.
      test('keeps the newer registration when an id is reused', () async {
        final first = Completer<void>();
        final second = Completer<void>();

        final firstTracked = NativeRenderTaskRegistry.track(
          'task-1',
          () => first.future,
        );
        final secondTracked = NativeRenderTaskRegistry.track(
          'task-1',
          () => second.future,
        );

        first.complete();
        await firstTracked;

        expect(NativeRenderTaskRegistry.activeTaskIds, contains('task-1'));

        second.complete();
        await secondTracked;

        expect(NativeRenderTaskRegistry.activeTaskIds, isEmpty);
      });
    });
  });
}

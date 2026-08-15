import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/render_cancellation_registry.dart';

void main() {
  group(RenderCancellationRegistry, () {
    tearDown(RenderCancellationRegistry.reset);

    test('records cancellation for the current render generation', () {
      final token = RenderCancellationRegistry.start('render-task');

      RenderCancellationRegistry.cancel('render-task');

      expect(
        RenderCancellationRegistry.isCancellationRequested('render-task'),
        isTrue,
      );
      expect(
        RenderCancellationRegistry.consumeCancellation('render-task'),
        isTrue,
      );
      expect(
        RenderCancellationRegistry.isCancellationRequested('render-task'),
        isFalse,
      );
      RenderCancellationRegistry.finish('render-task', token);
    });

    test('new generations clear stale cancellations', () {
      final oldToken = RenderCancellationRegistry.start('render-task');
      RenderCancellationRegistry.cancel('render-task');

      final newToken = RenderCancellationRegistry.start('render-task');

      expect(
        RenderCancellationRegistry.isCancellationRequested('render-task'),
        isFalse,
      );
      RenderCancellationRegistry.finish('render-task', oldToken);
      expect(
        RenderCancellationRegistry.isCancellationRequested('render-task'),
        isFalse,
      );
      RenderCancellationRegistry.finish('render-task', newToken);
    });

    test('startIfIdle reuses an active generation', () {
      final token = RenderCancellationRegistry.start('render-task');

      final generation = RenderCancellationRegistry.startIfIdle('render-task');

      expect(generation.started, isFalse);
      expect(identical(generation.token, token), isTrue);
    });
  });
}

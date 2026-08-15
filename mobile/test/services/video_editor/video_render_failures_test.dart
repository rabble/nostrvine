import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';

void main() {
  group(VideoRenderFailedException, () {
    test('traceValue uses the stable reason when there is no cause', () {
      const failure = VideoRenderFailedException(
        VideoRenderFailureReason.emptyClips,
      );

      expect(failure.traceValue, 'empty_clips');
    });

    test('traceValue adds the cause type without its message', () {
      final failure = VideoRenderFailedException(
        VideoRenderFailureReason.nativeRender,
        cause: PlatformException(code: 'x', message: 'device path'),
      );

      expect(failure.traceValue, 'native_render:PlatformException');
      expect(failure.traceValue, isNot(contains('device path')));
    });
  });
}

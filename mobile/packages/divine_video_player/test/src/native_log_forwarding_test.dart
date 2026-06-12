import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Constructing a controller installs the one-time global-channel handler
    // that receives `onNativeLog` from the platform side.
    DivineVideoPlayerController();
  });

  Future<void> dispatchNativeLog(Object? arguments) {
    const codec = StandardMethodCodec();
    final envelope = codec.encodeMethodCall(
      MethodCall('onNativeLog', arguments),
    );
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage('divine_video_player', envelope, (_) {});
  }

  LogEntry? latestEntryWithMessage(String message) {
    final matches = LogCaptureService().getRecentLogs().where(
      (entry) => entry.message == message,
    );
    return matches.isEmpty ? null : matches.last;
  }

  group('DivineVideoPlayer onNativeLog forwarding', () {
    test(
      'forwards a warning into UnifiedLogger under the video category',
      () async {
        const message = 'dvp-onNativeLog-warning-unique';
        await dispatchNativeLog({
          'level': 'warning',
          'message': message,
          'name': 'DivineVideoPlayer.Load',
        });

        final entry = latestEntryWithMessage(message);
        expect(entry, isNotNull);
        expect(entry!.level, LogLevel.warning);
        expect(entry.name, 'DivineVideoPlayer.Load');
        expect(entry.category, LogCategory.video);
      },
    );

    test('maps the error level', () async {
      const message = 'dvp-onNativeLog-error-unique';
      await dispatchNativeLog({
        'level': 'error',
        'message': message,
        'name': 'DivineVideoPlayer.Playback',
      });

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.level, LogLevel.error);
    });

    test('maps the info level', () async {
      const message = 'dvp-onNativeLog-info-unique';
      await dispatchNativeLog({
        'level': 'info',
        'message': message,
        'name': 'DivineVideoPlayer.Lifecycle',
      });

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.level, LogLevel.info);
    });

    test('maps the debug level', () async {
      const message = 'dvp-onNativeLog-debug-unique';
      await dispatchNativeLog({
        'level': 'debug',
        'message': message,
        'name': 'DivineVideoPlayer',
      });

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.level, LogLevel.debug);
    });

    test('maps the verbose level', () async {
      const message = 'dvp-onNativeLog-verbose-unique';
      await dispatchNativeLog({
        'level': 'verbose',
        'message': message,
        'name': 'DivineVideoPlayer',
      });

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.level, LogLevel.verbose);
    });

    test('falls back to info for an unknown level', () async {
      const message = 'dvp-onNativeLog-unknown-level-unique';
      await dispatchNativeLog({
        'level': 'something-unexpected',
        'message': message,
        'name': 'DivineVideoPlayer',
      });

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.level, LogLevel.info);
    });

    test('falls back to the native name when none is provided', () async {
      const message = 'dvp-onNativeLog-default-name-unique';
      await dispatchNativeLog({'level': 'info', 'message': message});

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.name, 'DivineVideoPlayerNative');
    });

    test('ignores an entry with an empty message', () async {
      final before = LogCaptureService().bufferSize;
      await dispatchNativeLog({
        'level': 'warning',
        'message': '',
        'name': 'DivineVideoPlayer',
      });

      expect(LogCaptureService().bufferSize, before);
    });

    test('ignores a call with non-map arguments without throwing', () async {
      await expectLater(dispatchNativeLog('not-a-map'), completes);
    });

    test('ignores an unknown global method without throwing', () async {
      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        const MethodCall('unknownMethod'),
      );
      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage('divine_video_player', envelope, (_) {}),
        completes,
      );
    });
  });
}

// ABOUTME: Tests for the platform app-icon badge clear service.
// ABOUTME: Verifies iOS channel invocation and best-effort failure handling.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/app_badge_service.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'divine/app_badge';
  const defaultChannel = MethodChannel(channelName);
  const testChannel = MethodChannel('divine/app_badge_test');

  Future<void> withPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group(AppBadgeService, () {
    setUp(() => LogCaptureService().clearAllLogs());

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(defaultChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
      debugDefaultTargetPlatformOverride = null;
      await LogCaptureService().clearAllLogs();
    });

    test('invokes the clear method channel on iOS', () async {
      await withPlatform(TargetPlatform.iOS, () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (call) async {
              calls.add(call);
              return null;
            });

        await const AppBadgeService(channel: testChannel).clear();

        expect(calls, hasLength(1));
        expect(calls.single.method, 'clear');
      });
    });

    test('defaults to the channel name the native side registers', () async {
      await withPlatform(TargetPlatform.iOS, () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(defaultChannel, (call) async {
              calls.add(call);
              return null;
            });

        // Exercises the production constructor rather than an injected
        // channel, so renaming `_channelName` fails here instead of surfacing
        // only on device as a swallowed MissingPluginException. Nothing in CI
        // compiles the iOS half, so keep `channelName` above in step with
        // `setupAppBadgeChannel` in ios/Runner/AppDelegate.swift.
        await const AppBadgeService().clear();

        expect(calls, hasLength(1));
        expect(calls.single.method, 'clear');
      });
    });

    test('does not invoke the channel on non-iOS platforms', () async {
      await withPlatform(TargetPlatform.android, () async {
        var callCount = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (call) async {
              callCount++;
              return null;
            });

        await const AppBadgeService(channel: testChannel).clear();

        expect(callCount, 0);
      });
    });

    test('logs the native reason and swallows PlatformException', () async {
      await withPlatform(TargetPlatform.iOS, () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (call) async {
              throw PlatformException(
                code: 'BADGE_CLEAR_FAILED',
                message: 'Notifications are unavailable',
              );
            });

        await expectLater(
          const AppBadgeService(channel: testChannel).clear(),
          completes,
        );

        final warning = LogCaptureService().getRecentLogs().singleWhere(
          (log) => log.message.contains('App badge clear failed'),
        );
        expect(warning.message, contains('Notifications are unavailable'));
      });
    });

    test(
      'swallows MissingPluginException when the native channel is absent',
      () async {
        await withPlatform(TargetPlatform.iOS, () async {
          await expectLater(
            const AppBadgeService(channel: testChannel).clear(),
            completes,
          );
        });
      },
    );
  });
}

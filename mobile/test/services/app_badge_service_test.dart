// ABOUTME: Tests for the platform app-icon badge clear service.
// ABOUTME: Verifies iOS channel invocation and best-effort failure handling.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/app_badge_service.dart';

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
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(defaultChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(testChannel, null);
      debugDefaultTargetPlatformOverride = null;
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

    test('swallows PlatformException from the native badge clear', () async {
      await withPlatform(TargetPlatform.iOS, () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(testChannel, (call) async {
              throw PlatformException(code: 'BADGE_CLEAR_FAILED');
            });

        await expectLater(
          const AppBadgeService(channel: testChannel).clear(),
          completes,
        );
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

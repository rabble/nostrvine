// ABOUTME: Tests for InstallSourceService method-channel mapping.
// ABOUTME: Verifies the Android installer-name and iOS sandbox mappings, plus
// ABOUTME: the sideload / failure fallbacks.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/install_source_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = 'divine/install_source';

  /// Installs a fake handler for [channelName] that returns [androidResult]
  /// for `getInstallerPackageName` and [iosSandbox] for `isSandboxReceipt`.
  void installFakeChannel({
    String? androidResult,
    bool? iosSandbox = false,
    Object? androidError,
    Object? iosError,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(channelName), (
          MethodCall call,
        ) async {
          if (call.method == 'getInstallerPackageName') {
            if (androidError != null) throw androidError;
            return androidResult;
          }
          if (call.method == 'isSandboxReceipt') {
            if (iosError != null) throw iosError;
            return iosSandbox;
          }
          return null;
        });
  }

  /// Runs [body] with [defaultTargetPlatform] set to [platform], restoring the
  /// real platform afterwards.
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

  group(InstallSourceService, () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), null);
    });

    test('maps Android Play Store installer to playStore', () async {
      await withPlatform(TargetPlatform.android, () async {
        installFakeChannel(androidResult: 'com.android.vending');
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.playStore);
      });
    });

    test('maps Android Zapstore installer to zapstore', () async {
      await withPlatform(TargetPlatform.android, () async {
        installFakeChannel(androidResult: 'com.zapstore.app');
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.zapstore);
      });
    });

    test('maps an unknown Android installer to sideload', () async {
      await withPlatform(TargetPlatform.android, () async {
        installFakeChannel(androidResult: 'com.unknown.installer');
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.sideload);
      });
    });

    test('maps a null Android installer to sideload', () async {
      await withPlatform(TargetPlatform.android, () async {
        // installFakeChannel's default androidResult is null.
        installFakeChannel();
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.sideload);
      });
    });

    test('falls back to sideload on Android PlatformException', () async {
      await withPlatform(TargetPlatform.android, () async {
        installFakeChannel(
          androidError: PlatformException(code: 'UNAVAILABLE'),
        );
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.sideload);
      });
    });

    test('maps iOS production receipt to appStore', () async {
      await withPlatform(TargetPlatform.iOS, () async {
        // installFakeChannel's default iosSandbox is false (production receipt).
        installFakeChannel();
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.appStore);
      });
    });

    test('maps iOS sandbox receipt to testFlight', () async {
      await withPlatform(TargetPlatform.iOS, () async {
        installFakeChannel(iosSandbox: true);
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.testFlight);
      });
    });

    test('maps a null iOS receipt response to sideload', () async {
      await withPlatform(TargetPlatform.iOS, () async {
        installFakeChannel(iosSandbox: null);
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.sideload);
      });
    });

    test('falls back to sideload on iOS PlatformException', () async {
      await withPlatform(TargetPlatform.iOS, () async {
        installFakeChannel(iosError: PlatformException(code: 'UNAVAILABLE'));
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.sideload);
      });
    });

    test('falls back to sideload when the native channel is missing', () async {
      await withPlatform(TargetPlatform.iOS, () async {
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.sideload);
      });
    });

    test('returns sideload on unsupported platforms (macOS)', () async {
      await withPlatform(TargetPlatform.macOS, () async {
        installFakeChannel(androidResult: 'com.android.vending');
        final source = await const InstallSourceService().resolve();
        expect(source, InstallSource.sideload);
      });
    });
  });
}

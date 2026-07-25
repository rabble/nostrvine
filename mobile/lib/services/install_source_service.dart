// ABOUTME: Resolves how the app was installed (Play Store, App Store,
// ABOUTME: TestFlight, Zapstore, sideload) via a native method channel.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Contract for resolving the app's [InstallSource].
///
/// Surfaces as an interface so tests can inject a deterministic source
/// without going through the native method channel.
abstract interface class InstallSourceResolver {
  /// Resolves the install source. Returns [InstallSource.sideload] when the
  /// platform does not expose install-source info (web, desktop, failures).
  Future<InstallSource> resolve();
}

/// Method-channel-backed implementation.
///
/// Android: queries the installer package name
/// (`com.android.vending` → Play Store, `com.zapstore.app` → Zapstore).
/// iOS: inspects the app-store receipt URL (`sandboxReceipt` → TestFlight).
/// On web/desktop/unsupported platforms it returns [InstallSource.sideload].
class InstallSourceService implements InstallSourceResolver {
  const InstallSourceService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'divine/install_source';

  final MethodChannel _channel;

  @override
  Future<InstallSource> resolve() async {
    // Web and desktop builds have no native install-referrer channel.
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return InstallSource.sideload;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final installer = await _channel.invokeMethod<String>(
          'getInstallerPackageName',
        );
        return resolveAndroidInstallSource(installer);
      }
      // iOS.
      final isSandbox =
          await _channel.invokeMethod<bool>('isSandboxReceipt') ?? false;
      return resolveIosInstallSource(isSandbox: isSandbox);
    } on PlatformException catch (e, st) {
      // A missing channel (e.g. an older native shell) or a revoked installer
      // permission must never block app launch — fall back to sideload and let
      // the in-app review gate (which only matches Play/App Store) no-op.
      debugPrint('InstallSourceService.resolve failed: $e\n$st');
      return InstallSource.sideload;
    } on MissingPluginException {
      return InstallSource.sideload;
    }
  }
}

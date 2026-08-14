// ABOUTME: Clears the platform app-icon notification badge through native code.
// ABOUTME: Keeps badge cleanup best-effort so app launch and inbox rendering proceed.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:unified_logger/unified_logger.dart';

/// Contract for best-effort platform app-icon badge cleanup.
abstract interface class AppBadgeClearer {
  /// Clears the app-icon badge when the current platform supports it.
  Future<void> clear();
}

/// Method-channel-backed app-icon badge service.
class AppBadgeService implements AppBadgeClearer {
  const AppBadgeService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'divine/app_badge';

  final MethodChannel _channel;

  @override
  Future<void> clear() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('clear');
    } on PlatformException catch (e) {
      Log.warning(
        'App badge clear failed: ${e.code}',
        name: 'AppBadgeService',
        category: LogCategory.system,
      );
    } on MissingPluginException catch (e) {
      Log.warning(
        'App badge channel missing; skipping clear: $e',
        name: 'AppBadgeService',
        category: LogCategory.system,
      );
    }
  }
}

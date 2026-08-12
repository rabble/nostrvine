// ABOUTME: Whether this platform can deliver Divine's HTTPS OAuth callback.
// ABOUTME: Shared by every in-app OAuth flow, since they all ride the same
// ABOUTME: universal link and inherit the same iOS floor.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimum iOS version whose `ASWebAuthenticationSession.Callback.https`
/// API can deliver the HTTPS OAuth callback.
const _minOAuthIosMajor = 17;
const _minOAuthIosMinor = 4;

/// Whether [systemVersion] (e.g. "17.4.1") meets the iOS OAuth floor.
///
/// Pure so the version matrix is unit-testable off-device. Fails closed on
/// unparseable input: an unknown iOS may carry the silent-cancel bug, and a
/// hidden flow is the recoverable failure.
bool iosVersionSupportsAppOAuth(String systemVersion) {
  final parts = systemVersion.split('.');
  final major = int.tryParse(parts.first);
  if (major == null) return false;
  final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? -1 : 0;
  if (minor < 0) return false;
  return major > _minOAuthIosMajor ||
      (major == _minOAuthIosMajor && minor >= _minOAuthIosMinor);
}

/// Whether the current platform can deliver the HTTPS OAuth callback that
/// in-app OAuth connect flows depend on.
///
/// Always true off iOS. On iOS, flutter_web_auth_2 only uses
/// `ASWebAuthenticationSession.Callback.https(host:path:)` on 17.4+, and
/// older versions can silently report a completed connection as a cancel —
/// so the flow is hidden there rather than offered. Fails closed when the
/// system version cannot be determined.
final appOAuthSupportProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb || !Platform.isIOS) return true;
  try {
    final deviceInfo = await DeviceInfoPlugin().iosInfo;
    return iosVersionSupportsAppOAuth(deviceInfo.systemVersion);
  } catch (_) {
    return false;
  }
});

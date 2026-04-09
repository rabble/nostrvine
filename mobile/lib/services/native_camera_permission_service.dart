import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum NativeCameraPermissionStatus {
  granted,
  denied,
  requiresSettings,
  unavailable,
}

abstract class NativeCameraPermissionService {
  Future<bool> hasPermission();

  Future<NativeCameraPermissionStatus> requestPermission();

  Future<bool> openSystemSettings();
}

class MethodChannelNativeCameraPermissionService
    implements NativeCameraPermissionService {
  const MethodChannelNativeCameraPermissionService();

  @visibleForTesting
  static const MethodChannel channel = MethodChannel('openvine/native_camera');

  @override
  Future<bool> hasPermission() async {
    final hasPermission = await channel.invokeMethod<bool>('hasPermission');
    return hasPermission ?? false;
  }

  @override
  Future<NativeCameraPermissionStatus> requestPermission() async {
    try {
      final granted = await channel.invokeMethod<bool>('requestPermission');
      return granted == true
          ? NativeCameraPermissionStatus.granted
          : NativeCameraPermissionStatus.denied;
    } on PlatformException catch (error) {
      if (error.code == 'PERMISSION_DENIED') {
        return NativeCameraPermissionStatus.requiresSettings;
      }

      return NativeCameraPermissionStatus.unavailable;
    }
  }

  @override
  Future<bool> openSystemSettings() async {
    final opened = await channel.invokeMethod<bool>('openSystemSettings');
    return opened ?? false;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum NativeCameraPermissionStatus {
  granted,
  denied,
  requiresSettings,
  unavailable,
}

enum NativeCameraAuthorizationStatus {
  authorized,
  notDetermined,
  denied,
  restricted,
  unavailable,
}

abstract class NativeCameraPermissionService {
  Future<bool> hasPermission();

  Future<NativeCameraAuthorizationStatus> authorizationStatus();

  Future<NativeCameraAuthorizationStatus> microphoneAuthorizationStatus();

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
  Future<NativeCameraAuthorizationStatus> authorizationStatus() async {
    final status = await channel.invokeMethod<String>('getAuthorizationStatus');
    return switch (status) {
      'authorized' => NativeCameraAuthorizationStatus.authorized,
      'notDetermined' => NativeCameraAuthorizationStatus.notDetermined,
      'denied' => NativeCameraAuthorizationStatus.denied,
      'restricted' => NativeCameraAuthorizationStatus.restricted,
      _ => NativeCameraAuthorizationStatus.unavailable,
    };
  }

  @override
  Future<NativeCameraAuthorizationStatus>
  microphoneAuthorizationStatus() async {
    final status = await channel.invokeMethod<String>(
      'getMicrophoneAuthorizationStatus',
    );
    return switch (status) {
      'authorized' => NativeCameraAuthorizationStatus.authorized,
      'notDetermined' => NativeCameraAuthorizationStatus.notDetermined,
      'denied' => NativeCameraAuthorizationStatus.denied,
      'restricted' => NativeCameraAuthorizationStatus.restricted,
      _ => NativeCameraAuthorizationStatus.unavailable,
    };
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

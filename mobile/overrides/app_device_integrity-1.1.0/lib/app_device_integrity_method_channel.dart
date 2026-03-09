import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_device_integrity_platform_interface.dart';

/// An implementation of [AppDeviceIntegrityPlatform] that uses method channels.
class MethodChannelAppDeviceIntegrity extends AppDeviceIntegrityPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('app_attestation');

  @override
  Future<String?> getAttestationServiceSupport(
      {required String challengeString, int? gcp}) async {
    final token = await methodChannel.invokeMethod<String>(
        'getAttestationServiceSupport',
        <String, dynamic>{'challengeString': challengeString, 'gcp': gcp});
    return token;
  }
}

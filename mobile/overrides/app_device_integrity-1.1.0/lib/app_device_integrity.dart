import 'dart:io';

import 'app_device_integrity_platform_interface.dart';

class AppDeviceIntegrity {
  Future<String?> getAttestationServiceSupport(
      {required String challengeString, int? gcp}) {
    if (Platform.isAndroid) {
      return AppDeviceIntegrityPlatform.instance.getAttestationServiceSupport(
          challengeString: challengeString, gcp: gcp!);
    }

    return AppDeviceIntegrityPlatform.instance
        .getAttestationServiceSupport(challengeString: challengeString);
  }
}

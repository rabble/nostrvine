import 'dart:io';

import 'app_device_integrity_platform_interface.dart';

class AppDeviceIntegrity {
  /// [keyScope] selects which cached App Attest key answers the challenge on
  /// iOS. Apple's guidance is against sharing one key among several users of a
  /// device, so callers pass the identity the attestation speaks for. Ignored
  /// on Android, which mints a throwaway key per call.
  Future<String?> getAttestationServiceSupport(
      {required String challengeString, int? gcp, String? keyScope}) {
    if (Platform.isAndroid) {
      return AppDeviceIntegrityPlatform.instance.getAttestationServiceSupport(
          challengeString: challengeString, gcp: gcp!);
    }

    return AppDeviceIntegrityPlatform.instance.getAttestationServiceSupport(
        challengeString: challengeString, keyScope: keyScope);
  }
}

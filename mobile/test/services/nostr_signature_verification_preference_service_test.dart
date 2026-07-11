// ABOUTME: Tests persistence and SDK mapping for Nostr signature policy prefs.
// ABOUTME: Covers default, invalid stored values, and round-trip storage.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/services/nostr_signature_verification_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(NostrSignatureVerificationPreferenceService, () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to verifying all relays', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = NostrSignatureVerificationPreferenceService(prefs);

      expect(
        service.currentPolicy,
        NostrSignatureVerificationPolicy.all,
      );
    });

    test('round-trips every policy through storage', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = NostrSignatureVerificationPreferenceService(prefs);

      for (final policy in NostrSignatureVerificationPolicy.values) {
        await service.setPolicy(policy);
        expect(service.currentPolicy, policy);
        expect(
          prefs.getString(NostrSignatureVerificationPreferenceService.prefsKey),
          policy.storageValue,
        );
      }
    });

    test('falls back to default for unknown stored values', () async {
      SharedPreferences.setMockInitialValues({
        NostrSignatureVerificationPreferenceService.prefsKey: 'mystery',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = NostrSignatureVerificationPreferenceService(prefs);

      expect(
        service.currentPolicy,
        NostrSignatureVerificationPolicy.all,
      );
    });

    test('maps app policies to SDK policies', () {
      expect(
        NostrSignatureVerificationPolicy.all.toSdkPolicy(),
        nostr_sdk.SignatureVerificationPolicy.all,
      );
      expect(
        NostrSignatureVerificationPolicy.untrustedRelays.toSdkPolicy(),
        nostr_sdk.SignatureVerificationPolicy.untrustedRelays,
      );
      expect(
        NostrSignatureVerificationPolicy.nonDivineRelays.toSdkPolicy(),
        nostr_sdk.SignatureVerificationPolicy.nonDivineRelays,
      );
    });
  });
}

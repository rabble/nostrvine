import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:openvine/services/auth_service_signer.dart';

@immutable
class CreatorSocialHandle {
  const CreatorSocialHandle({
    required this.platform,
    required this.handle,
  });

  final String platform;
  final String handle;

  Map<String, String> toJson() => {
    'platform': platform,
    'handle': handle,
  };
}

@immutable
class CreatorBindingClaims {
  const CreatorBindingClaims({
    this.nip05,
    this.website,
    this.socialHandles = const <CreatorSocialHandle>[],
  });

  final String? nip05;
  final String? website;
  final List<CreatorSocialHandle> socialHandles;

  Map<String, dynamic> toJson() {
    final sortedHandles = List<CreatorSocialHandle>.of(socialHandles)
      ..sort((left, right) {
        final platformCompare = left.platform.compareTo(right.platform);
        if (platformCompare != 0) {
          return platformCompare;
        }
        return left.handle.compareTo(right.handle);
      });

    return <String, dynamic>{
      if (nip05 != null) 'nip05': nip05,
      if (website != null) 'website': website,
      if (sortedHandles.isNotEmpty)
        'social_handles': sortedHandles
            .map((handle) => handle.toJson())
            .toList(growable: false),
    };
  }
}

@immutable
class CreatorBindingHardBinding {
  const CreatorBindingHardBinding({
    required this.alg,
    required this.value,
  });

  final String alg;
  final String value;

  Map<String, String> toJson() => {
    'alg': alg,
    'value': value,
  };
}

@immutable
class NostrCreatorBindingAssertion {
  const NostrCreatorBindingAssertion({
    required this.assertionLabel,
    required this.payloadJson,
    required this.signature,
    required this.pubkey,
  });

  final String assertionLabel;
  final String payloadJson;
  final String signature;
  final String pubkey;
}

class NostrCreatorBindingService {
  NostrCreatorBindingService({
    required AuthServiceSigner signer,
    DateTime Function()? now,
  }) : _signer = signer,
       _now = now ?? DateTime.now;

  static const assertionLabel = 'video.divine.nostr.creator_binding';
  static const signatureAlgorithm = 'nostr.secp256k1';

  final AuthServiceSigner _signer;
  final DateTime Function() _now;

  Future<NostrCreatorBindingAssertion> createAssertion({
    required CreatorBindingClaims claims,
    required CreatorBindingHardBinding hardBinding,
    required List<String> referencedAssertions,
  }) async {
    final pubkey = await _signer.currentPubkey();
    if (pubkey.isEmpty) {
      throw StateError('No authenticated Nostr signer available');
    }

    final normalizedAssertions = List<String>.of(referencedAssertions)..sort();

    final unsignedPayload = <String, dynamic>{
      'version': 1,
      'pubkey': pubkey,
      'sig_alg': signatureAlgorithm,
      'created_at': _now().toUtc().toIso8601String(),
      'claims': claims.toJson(),
      'referenced_assertions': normalizedAssertions,
      'hard_binding': hardBinding.toJson(),
    };

    final unsignedPayloadJson = jsonEncode(unsignedPayload);
    final payloadBytes = Uint8List.fromList(utf8.encode(unsignedPayloadJson));
    final signature = await _signer.signCanonicalPayload(payloadBytes);

    if (signature == null || signature.isEmpty) {
      throw StateError('Failed to sign canonical creator-binding payload');
    }

    final payloadJson = jsonEncode(<String, dynamic>{
      ...unsignedPayload,
      'signature': signature,
    });

    return NostrCreatorBindingAssertion(
      assertionLabel: assertionLabel,
      payloadJson: payloadJson,
      signature: signature,
      pubkey: pubkey,
    );
  }
}

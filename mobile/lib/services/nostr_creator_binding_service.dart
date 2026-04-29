import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:openvine/services/nostr_identity.dart';

@immutable
class CreatorSocialHandle {
  const CreatorSocialHandle({required this.platform, required this.handle});

  final String platform;
  final String handle;

  Map<String, String> toJson() => {'platform': platform, 'handle': handle};
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
  const CreatorBindingHardBinding({required this.alg, required this.value});

  final String alg;
  final String value;

  Map<String, String> toJson() => {'alg': alg, 'value': value};
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
    required NostrIdentity? identity,
    DateTime Function()? now,
  }) : _identity = identity,
       _now = now ?? DateTime.now;

  static const assertionLabel = 'video.divine.nostr.creator_binding';
  static const signatureAlgorithm = 'nostr.secp256k1';

  final NostrIdentity? _identity;
  final DateTime Function() _now;

  /// Builds a signed creator-binding assertion for the C2PA proof manifest.
  ///
  /// Returns `null` when the active identity does not support canonical
  /// payload signing (e.g. Divine OAuth without a local key and without a
  /// backend `sign_canonical` RPC method, NIP-46 bunker, NIP-55 amber).
  /// Callers treat null as "skip the binding" and proceed without it.
  ///
  /// Throws [StateError] only when there is no authenticated identity at
  /// all, which indicates a programmer error in the calling flow.
  Future<NostrCreatorBindingAssertion?> createAssertion({
    required CreatorBindingClaims claims,
    required CreatorBindingHardBinding hardBinding,
    required List<String> referencedAssertions,
  }) async {
    final identity = _identity;
    if (identity == null) {
      throw StateError('No authenticated Nostr identity available');
    }

    final pubkey = identity.pubkey;
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
    final signature = await identity.signCanonicalPayload(payloadBytes);

    if (signature == null || signature.isEmpty) {
      // Identity can't produce a canonical signature (RPC-only without
      // backend support, or remote signers whose protocol lacks it).
      // Caller skips the binding rather than aborting the publish.
      return null;
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

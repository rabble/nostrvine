// ABOUTME: Wraps IdentityVerificationClient with session cache and dedup.
// ABOUTME: Returns verified claims without propagating client errors.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:identity_verification_client/identity_verification_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// Wraps [IdentityVerificationClient] with session cache and request deduping.
class IdentityVerificationRepository {
  /// Creates an identity verification repository backed by [client].
  IdentityVerificationRepository({
    required IdentityVerificationClient client,
  }) : _client = client;

  final IdentityVerificationClient _client;

  /// Cache keyed by `pubkey`. Value is the verified subset.
  final Map<String, List<NostrIdentityClaim>> _cache = {};

  /// In-flight call dedupe.
  final Map<String, Future<List<NostrIdentityClaim>>> _inflight = {};

  /// Returns the verified subset of [claims] for [pubkey].
  ///
  /// Caches results in-memory for the session. Concurrent calls for the
  /// same [pubkey] share a single in-flight Future. On client error, logs
  /// at info level and returns an empty list — never propagates.
  Future<List<NostrIdentityClaim>> verifyClaims({
    required String pubkey,
    required List<NostrIdentityClaim> claims,
  }) async {
    if (claims.isEmpty) return const [];

    final cached = _cache[pubkey];
    if (cached != null) return cached;

    final pending = _inflight[pubkey];
    if (pending != null) return pending;

    final future = _runVerify(pubkey: pubkey, claims: claims);
    _inflight[pubkey] = future;
    try {
      return await future;
    } finally {
      unawaited(future.whenComplete(() => _inflight.remove(pubkey)));
    }
  }

  Future<List<NostrIdentityClaim>> _runVerify({
    required String pubkey,
    required List<NostrIdentityClaim> claims,
  }) async {
    try {
      final verified = await _client.verifyClaims(
        pubkey: pubkey,
        claims: claims,
      );
      _cache[pubkey] = verified;
      return verified;
    } on Object catch (error, stackTrace) {
      developer.log(
        'identity verification failed',
        name: 'identity_verification_repository',
        level: 800,
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// Clears all cached verifications. Call on logout / nsec switch.
  @visibleForTesting
  void clearCache() {
    _cache.clear();
    _inflight.clear();
  }
}

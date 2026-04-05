// ABOUTME: Top-level function for off-main-isolate NIP-17 gift-wrap
// ABOUTME: unwrap. Used by DmRepository when the active signer is a
// ABOUTME: local key signer that can safely expose raw private key bytes.
// ABOUTME: Remote signers (Amber, Keycast RPC, NIP-46) fall back to the
// ABOUTME: main-isolate decryptor path because they cannot cross an
// ABOUTME: isolate boundary. See docs/plans/2026-04-05-dm-isolate-spike-findings.md.

import 'dart:convert';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip44/nip44_v2.dart';

/// Input payload for [decryptGiftWrapBatch].
///
/// Both fields are sendable across a Dart isolate boundary: [events] is a
/// list of plain JSON maps (the output of [Event.toJson]) and
/// [privateKeyHex] is a raw hex string extracted from the caller's
/// secure key container under a scoped callback.
class DecryptBatchRequest {
  const DecryptBatchRequest({
    required this.events,
    required this.privateKeyHex,
  });

  /// Raw gift-wrap events (kind 1059) serialized via [Event.toJson].
  final List<Map<String, dynamic>> events;

  /// Hex-encoded recipient private key used for NIP-44 ECDH.
  final String privateKeyHex;
}

/// Per-event decrypt result. Either holds the decrypted rumor as JSON
/// (the shape produced by [Event.toJson]) or an error description.
///
/// The batch helper NEVER throws — every failure becomes a
/// [DecryptedRumorResult.failure] entry so one malformed event cannot
/// tank the entire batch.
class DecryptedRumorResult {
  const DecryptedRumorResult._({this.rumor, this.error});

  const DecryptedRumorResult.success(Map<String, dynamic> rumor)
    : this._(rumor: rumor);

  const DecryptedRumorResult.failure(String error) : this._(error: error);

  /// Successfully decrypted rumor as JSON (null on failure).
  final Map<String, dynamic>? rumor;

  /// Human-readable failure reason (null on success).
  final String? error;

  /// Whether this entry represents a successful decrypt.
  bool get isSuccess => rumor != null;
}

/// Decrypts a batch of NIP-17 gift-wrap events (kind 1059) to their
/// inner rumors, running the two-layer unwrap (gift wrap → seal →
/// rumor) entirely with pure functions so it is safe to invoke inside
/// [compute()].
///
/// Results are returned in the same order as [DecryptBatchRequest.events].
/// Malformed events, crypto failures, seal/rumor validation mismatches,
/// and JSON parse errors all become [DecryptedRumorResult.failure]
/// entries — this function never throws.
Future<List<DecryptedRumorResult>> decryptGiftWrapBatch(
  DecryptBatchRequest request,
) async {
  final results = <DecryptedRumorResult>[];
  for (final raw in request.events) {
    try {
      final result = await _decryptOne(raw, request.privateKeyHex);
      results.add(result);
    } on Object catch (e) {
      results.add(DecryptedRumorResult.failure('unexpected error: $e'));
    }
  }
  return results;
}

Future<DecryptedRumorResult> _decryptOne(
  Map<String, dynamic> rawGiftWrap,
  String privateKeyHex,
) async {
  // Step 0: reconstruct the gift wrap event.
  final Event giftWrap;
  try {
    giftWrap = Event.fromJson(rawGiftWrap);
  } on Object catch (e) {
    return DecryptedRumorResult.failure('invalid gift wrap json: $e');
  }

  // Step 1: gift wrap → seal. The gift wrap is encrypted to the
  // recipient by an ephemeral key advertised as the event's pubkey.
  final String sealJsonText;
  try {
    final giftKey = NIP44V2.shareSecret(privateKeyHex, giftWrap.pubkey);
    sealJsonText = await NIP44V2.decrypt(giftWrap.content, giftKey);
  } on Object catch (e) {
    return DecryptedRumorResult.failure(
      'gift wrap decrypt failed for ${giftWrap.id}: $e',
    );
  }

  final Event sealEvent;
  try {
    final sealJson = jsonDecode(sealJsonText) as Map<String, dynamic>;
    sealEvent = Event.fromJson(sealJson);
  } on Object catch (e) {
    return DecryptedRumorResult.failure(
      'seal parse failed for ${giftWrap.id}: $e',
    );
  }

  if (!sealEvent.isValid || !sealEvent.isSigned) {
    return DecryptedRumorResult.failure(
      'seal signature invalid for gift wrap ${giftWrap.id}',
    );
  }

  // Step 2: seal → rumor. The seal is encrypted by the true sender
  // (authenticated via the seal's Schnorr signature).
  final String rumorJsonText;
  try {
    final sealKey = NIP44V2.shareSecret(privateKeyHex, sealEvent.pubkey);
    rumorJsonText = await NIP44V2.decrypt(sealEvent.content, sealKey);
  } on Object catch (e) {
    return DecryptedRumorResult.failure(
      'seal decrypt failed for ${giftWrap.id}: $e',
    );
  }

  final Map<String, dynamic> rumorJson;
  try {
    rumorJson = jsonDecode(rumorJsonText) as Map<String, dynamic>;
  } on Object catch (e) {
    return DecryptedRumorResult.failure(
      'rumor parse failed for ${giftWrap.id}: $e',
    );
  }

  // NIP-17 sender verification: the rumor's claimed author is NOT
  // cryptographically authenticated — the seal's pubkey IS (it signed
  // the seal). When they differ, override the rumor's pubkey with the
  // seal's to prevent impersonation. This mirrors the logic in
  // GiftWrapUtil.getRumorEvent.
  final rumorPubkey = rumorJson['pubkey'];
  if (rumorPubkey is String && rumorPubkey != sealEvent.pubkey) {
    rumorJson['pubkey'] = sealEvent.pubkey;
  }

  // Round-trip through Event to normalize shape and re-emit toJson so
  // the main isolate receives exactly what Event.fromJson expects back.
  try {
    final rumor = Event.fromJson(rumorJson);
    return DecryptedRumorResult.success(rumor.toJson());
  } on Object catch (e) {
    return DecryptedRumorResult.failure(
      'rumor reconstruct failed for ${giftWrap.id}: $e',
    );
  }
}

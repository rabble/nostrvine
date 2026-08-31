// ABOUTME: Builds DM relay subscription ids that stay inside NIP-01's
// ABOUTME: 64-character cap while remaining distinct per account and page.

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// NIP-01: "`<subscription_id>` is an arbitrary, non-empty string of max
/// length 64 chars."
///
/// A relay that enforces this refuses the `REQ` outright, and the only trace
/// is one `invalid subscription id length` line — DM receive then degrades
/// silently on that relay.
const int nip01MaxSubscriptionIdLength = 64;

/// A short, stable, per-account tag for a subscription id.
///
/// A full 64-character hex pubkey behind any prefix already exceeds the cap on
/// its own, so the account component is hashed rather than shortened. That is
/// also the reason to hash instead of taking a prefix of the pubkey: a
/// shortened public identifier looks correlatable and is not, whereas a digest
/// is honestly opaque and never mistaken for the key itself.
String dmSubscriptionAccountTag(String pubkey) =>
    sha256.convert(utf8.encode(pubkey)).toString().substring(0, 16);

/// Subscription id for the live gift-wrap inbox of [pubkey].
String dmInboxSubscriptionId(String pubkey) =>
    'dm_inbox_${dmSubscriptionAccountTag(pubkey)}';

/// Subscription id for page [page] of the NIP-17 history drain of [pubkey].
String dmHistoryDrainSubscriptionId(String pubkey, int page) =>
    'dm_drain_${dmSubscriptionAccountTag(pubkey)}_$page';

/// Subscription id for page [page] of the NIP-04 history drain of [pubkey].
String dmNip04DrainSubscriptionId(String pubkey, int page) =>
    'dm_drain_nip04_${dmSubscriptionAccountTag(pubkey)}_$page';

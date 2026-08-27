// ABOUTME: Shared naming chain for inbox and request DM conversation peers.
// ABOUTME: Vanished first, so a row and the sheet it opens cannot name two
// ABOUTME: different accounts.

import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';

/// The peer's name when it resolves without a profile lookup.
///
/// A NIP-62 vanish comes first because it is the only branch that contradicts
/// the ones below it: applying one evicts the cached profile and short-circuits
/// every later fetch, so a surface that skips this check does not fall back to
/// the peer's last known name — it falls all the way through to
/// [UserProfile.defaultDisplayNameFor], a generated "Adjective Animal N" the
/// viewer has never seen before.
///
/// Returns null when only the profile can name the peer, which is the caller's
/// signal that a lookup is worth paying for.
String? dmPeerNameWithoutProfile(
  BuildContext context, {
  required String pubkeyHex,
  required bool isVanished,
  String? displayNameOverride,
}) => isVanished
    ? context.l10n.profileDeletedAccountName
    : displayNameOverride ?? moderationDisplayName(context, pubkeyHex);

/// The full chain: vanished, then [displayNameOverride], then moderation, then
/// [profile], then the generated fallback.
///
/// [isVanished] is required rather than defaulted so every caller has to decide
/// what to pass. Reactive widgets read it from `profileVanishedProvider`, with
/// `ConversationTile` as the reference call site.
String dmPeerDisplayName(
  BuildContext context, {
  required String pubkeyHex,
  required bool isVanished,
  UserProfile? profile,
  String? displayNameOverride,
}) =>
    dmPeerNameWithoutProfile(
      context,
      pubkeyHex: pubkeyHex,
      isVanished: isVanished,
      displayNameOverride: displayNameOverride,
    ) ??
    profile?.bestDisplayName ??
    UserProfile.defaultDisplayNameFor(pubkeyHex);

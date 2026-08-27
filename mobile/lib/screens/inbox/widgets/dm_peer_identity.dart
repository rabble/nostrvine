// ABOUTME: Shared naming chain for inbox and request DM conversation peers.
// ABOUTME: Vanished first, so a row and the sheet it opens cannot name two
// ABOUTME: different accounts.

import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';

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
}) => dmPeerSubstituteName(
  isVanished: isVanished,
  isModeration: isModerationAccount(pubkeyHex),
  labels: dmPeerLabels(context),
  displayNameOverride: displayNameOverride,
);

/// The localized labels [dmPeerName] needs, read from this [context].
///
/// The one place the ARB keys behind the chain are named, so the inbox search
/// index — which matches on the same strings from a BLoC — cannot drift onto
/// different ones.
DmPeerLabels dmPeerLabels(BuildContext context) => DmPeerLabels(
  deletedAccount: context.l10n.profileDeletedAccountName,
  moderation: context.l10n.inboxSupportRowTitle,
  retiredConversationClosed: context.l10n.dmRetiredThreadClosedTitle,
);

/// The full chain: vanished, then [displayNameOverride], then moderation, then
/// [profile], then the generated fallback.
///
/// Thin `BuildContext` wrapper over [dmPeerName]; the precedence itself lives
/// there so a non-widget caller can share it (#8204).
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
}) => dmPeerName(
  pubkeyHex: pubkeyHex,
  isVanished: isVanished,
  isModeration: isModerationAccount(pubkeyHex),
  labels: dmPeerLabels(context),
  profileName: profile?.bestDisplayName,
  displayNameOverride: displayNameOverride,
);

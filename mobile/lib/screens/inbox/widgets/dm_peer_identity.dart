// ABOUTME: Shared naming chain for inbox and request DM conversation peers.
// ABOUTME: Vanished first, so a row and the sheet it opens cannot name two
// ABOUTME: different accounts.

import 'package:flutter/widgets.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';
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

/// The conversation's own title: [dmPeerDisplayName] for a 1:1, and for a group
/// the NIP-17 `subject` when the room carries one, else `"<peer> and N others"`.
///
/// Thin `BuildContext` wrapper over [dmConversationTitle]; the precedence lives
/// there so `ConversationListBloc` can index rows by the string they render
/// (#8204).
///
/// [peerName] is what [dmPeerDisplayName] resolved for the row's first peer. It
/// is passed in rather than resolved here because a 1:1 name needs a profile
/// lookup this function has no business performing.
String dmConversationDisplayTitle(
  BuildContext context, {
  required List<String> participantPubkeys,
  required String currentUserPubkey,
  required bool isGroup,
  required String peerName,
  String? subject,
}) => dmConversationTitle(
  isGroup: isGroup,
  subject: subject,
  peerName: peerName,
  groupFallbackName: context.l10n.inboxGroupConversationTitle(
    peerName,
    dmGroupOtherCount(
      participantPubkeys: participantPubkeys,
      currentUserPubkey: currentUserPubkey,
    ),
  ),
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
  bool isResolving = false,
}) => dmPeerName(
  pubkeyHex: pubkeyHex,
  isVanished: isVanished,
  isModeration: isModerationAccount(pubkeyHex),
  labels: dmPeerLabels(context),
  profileName: switch (profile) {
    UserProfile(displayName: final name?) when name.isNotEmpty =>
      UserProfile.sanitizeDisplayName(name),
    UserProfile(name: final name?) when name.isNotEmpty =>
      UserProfile.sanitizeDisplayName(name),
    _ => null,
  },
  displayNameOverride: displayNameOverride,
  isResolving: isResolving,
);

/// The avatar artwork a DM peer surface shows, resolved the same way
/// [dmPeerDisplayName] resolves the name beside it.
///
/// The two halves have to agree or a row contradicts itself — a vanished peer
/// named "Deleted account" over their own photo still identifies them, and the
/// moderation account named "Divine Moderation" beside a generic placeholder
/// reads as an impersonator. Both substitutions were already written out by
/// hand at every inbox row ([ConversationTile] is the reference); this is that
/// pair in one place so a new surface cannot ship with the name step and
/// without the picture step, which is exactly how #8421's send-target pickers
/// diverged.
///
/// [contentOverride] carries the bundled moderation wordmark because the
/// account's kind-0 `picture` is a hosted SVG whose `<style>` block
/// `vector_graphics_compiler` discards — see [ModerationAvatar]. Pass the
/// record straight into [UserAvatar]'s matching parameters.
({String? imageUrl, Widget? contentOverride}) dmPeerAvatar({
  required String pubkeyHex,
  required bool isVanished,
  String? pictureUrl,
}) => (
  // A vanish is the one branch that must also drop the artwork: the name
  // substitution alone would leave the account recognisable by its face.
  imageUrl: isVanished ? null : pictureUrl,
  contentOverride: isModerationAccount(pubkeyHex)
      ? const ModerationAvatar()
      : null,
);

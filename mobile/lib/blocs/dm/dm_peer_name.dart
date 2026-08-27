// ABOUTME: The one naming precedence every DM surface resolves a peer through.
// ABOUTME: Pure and Flutter-free, so the inbox search index in
// ABOUTME: ConversationListBloc matches the string the row actually renders.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';

/// The localized strings [dmPeerName] substitutes for a peer whose own name
/// must not be shown.
///
/// Injected rather than read from `context.l10n`, because the search index
/// that matches on them lives in a BLoC. Both values are already-translated
/// ARB keys: [deletedAccount] is `profileDeletedAccountName`, [moderation] is
/// `inboxSupportRowTitle`.
class DmPeerLabels extends Equatable {
  const DmPeerLabels({required this.deletedAccount, required this.moderation});

  /// Shown instead of the name of an account that published a NIP-62 vanish.
  final String deletedAccount;

  /// Shown instead of the kind-0 name of a Divine Moderation key.
  final String moderation;

  @override
  List<Object?> get props => [deletedAccount, moderation];
}

/// The peer's name, in the precedence every DM surface has to agree on:
/// vanished, override, moderation, profile, generated.
///
/// This function exists because that precedence used to be written twice — the
/// widget chain rendered all five steps while `ConversationListBloc` matched on
/// the last two, so a vanished peer's row read "Deleted account" while inbox
/// search indexed a generated "Adjective Animal N" the viewer had never seen
/// (#8204). Keeping it in one pure place is what stops the next branch
/// diverging the same way.
///
/// A vanish comes first because it is the only branch that contradicts the ones
/// below it: applying one evicts the cached profile and short-circuits every
/// later fetch, so a caller that skips this check does not fall back to the
/// peer's last known name — it falls all the way through to
/// [UserProfile.defaultDisplayNameFor].
///
/// [profileName] is the caller's already-resolved step-4 value: the widget
/// chain passes `profile?.bestDisplayName`, and the BLoC passes its cached
/// entry. Both may be null, and the generated fallback answers for them.
String dmPeerName({
  required String pubkeyHex,
  required bool isVanished,
  required DmPeerLabels labels,
  String? profileName,
  String? displayNameOverride,
}) {
  if (isVanished) return labels.deletedAccount;
  if (displayNameOverride != null) return displayNameOverride;
  // Answers for retired keys too, via `isModerationAccount`: a rotated-away
  // thread stays an ordinary inbox row and has no kind 0 of its own.
  if (isModerationAccount(pubkeyHex)) return labels.moderation;
  return profileName ?? UserProfile.defaultDisplayNameFor(pubkeyHex);
}

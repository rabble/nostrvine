// ABOUTME: The name and picture a NON-DM surface shows for a NIP-62 vanished
// ABOUTME: account. Deliberately narrower than the DM chain: no moderation
// ABOUTME: step, because that substitution is scoped to inbox surfaces.

import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// The name to render for [fallbackName]'s account, substituting the
/// deleted-account label when the account published a NIP-62 request to vanish.
///
/// Four non-DM surfaces already spell this out by hand — `other_profile_screen`,
/// `profile_header_widget`, `profile_header_identity` and `profile_banner_layer`
/// — and the people picker and the shared people row shipped without it. This is
/// that one line, in one place, so a new people surface gets it by calling
/// rather than by remembering.
///
/// Deliberately **not** `dmPeerName`. That chain carries a moderation step bound
/// to the inbox-namespaced `inboxSupportRowTitle`, and
/// `moderation_identity.dart` scopes the substitution to DM surfaces: a badge
/// picker naming an account "Divine Moderation" would be inventing an identity
/// the rest of the app does not use outside the inbox.
///
/// [fallbackName] is the caller's already-resolved name — `bestDisplayName`, or
/// whatever placeholder that surface uses when no profile has arrived. It is
/// only consulted when the account has not vanished, so a caller may pass a
/// stale value without leaking it.
String vanishedAccountName(
  BuildContext context, {
  required bool isVanished,
  required String fallbackName,
}) => vanishedAccountNameFrom(
  isVanished: isVanished,
  deletedAccountLabel: context.l10n.profileDeletedAccountName,
  fallbackName: fallbackName,
);

/// [vanishedAccountName] without a [BuildContext], for a caller that sorts or
/// filters on the rendered name outside a `build`.
///
/// The split exists for the same reason `dmPeerName` sits apart from
/// `dmPeerDisplayName`: an ordering has to key on the string the row shows, and
/// the code that computes an ordering is not always holding a context. Pass the
/// already-resolved `profileDeletedAccountName` as [deletedAccountLabel] so both
/// paths substitute the same string.
String vanishedAccountNameFrom({
  required bool isVanished,
  required String deletedAccountLabel,
  required String fallbackName,
}) => isVanished ? deletedAccountLabel : fallbackName;

/// The avatar URL to render, dropped for a vanished account.
///
/// The name substitution alone is not enough: a row reading "Deleted account"
/// over the account's own photo still identifies them to anyone who recognises
/// the face. Returns null so `UserAvatar` falls back to its pubkey-seeded
/// placeholder, which is what the profile header already does.
String? vanishedAccountPictureUrl({
  required bool isVanished,
  String? pictureUrl,
}) => isVanished ? null : pictureUrl;

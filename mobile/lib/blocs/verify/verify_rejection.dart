// ABOUTME: Turns the verifier's stable rejection code into the error the
// ABOUTME: connect flow shows, falling back for anything it does not know.

import 'package:openvine/blocs/verify/verify_connect_cubit.dart';

/// Resolves the verifier's [code] to the error the connect flow should show.
///
/// Mirrors the codes set in
/// `divine-identify-verification-service/src/platforms/discord.ts`.
///
/// An unknown or absent code falls back to [VerifyConnectError.proofRejected].
/// That is not defensive padding: the service owns this vocabulary and adds to
/// it independently of the app, and every deployment older than the codes
/// answers without one. A build that could not absorb an unfamiliar value
/// would show the user nothing at all.
///
/// Four real codes are deliberately unmapped — `discord_invite_refused`,
/// `discord_not_configured`, `discord_invalid_proof_format` and
/// `discord_api_error`. The first is already covered by the form's own
/// explainer, and the rest name a service-side condition the user cannot act
/// on, so the generic rejection is the honest answer.
VerifyConnectError verifyErrorForCode(String? code) => switch (code) {
  'discord_npub_not_in_message' => VerifyConnectError.proofMissingNpub,
  'discord_dm_link' => VerifyConnectError.discordDmLink,
  'discord_channel_link' => VerifyConnectError.discordChannelLink,
  'discord_message_not_found' => VerifyConnectError.discordMessageNotFound,
  'discord_bot_no_access' => VerifyConnectError.discordBotNoAccess,
  'discord_author_mismatch' => VerifyConnectError.discordAuthorMismatch,
  'discord_message_content_unavailable' =>
    VerifyConnectError.discordContentUnavailable,
  _ => VerifyConnectError.proofRejected,
};

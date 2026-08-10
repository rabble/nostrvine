// ABOUTME: Divine Moderation's name and avatar for DM surfaces. One place, so
// ABOUTME: the inbox list, the message-requests flow and the conversation
// ABOUTME: header all recognise the account instead of only the inbox list.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';

/// Divine's own name for [pubkeyHex], or `null` for any other account.
///
/// Every DM surface otherwise resolves the peer as
/// `profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey)`.
/// That is wrong for moderation twice over: the account's kind-0 is not on the
/// single relay production reads, and a retired key has no kind-0 at all — so
/// the profile is `null` and the fallback is a generated "Adjective Animal N".
/// An enforcement notice then arrives from a random-looking stranger.
///
/// Answers for retired keys too, via [isModerationAccount]: it is the same team
/// on the other end of a pre-rotation thread. Callers that need a *send target*
/// must not use this — see [isRetiredModerationAccount].
String? moderationDisplayName(BuildContext context, String pubkeyHex) =>
    isModerationAccount(pubkeyHex) ? context.l10n.inboxSupportRowTitle : null;

/// Brand artwork for the Divine moderation account's avatar.
///
/// Pass as [UserAvatar.contentOverride] so it inherits the shared avatar
/// chrome. That slot is laid out with `StackFit.expand`, so this fills the
/// avatar box at whatever size the call site asked for and needs no size of
/// its own.
///
/// The account's kind-0 `picture` is the hosted `divine-logo.svg`, which
/// colours its paths through a `<style>` block. `vector_graphics_compiler` has
/// no `<style>` parser, so it discards the stylesheet and every path falls
/// back to opaque black — 1.1:1 against the inbox surface. The bundled
/// `logo.svg` is the same wordmark carrying presentational `fill` attributes
/// instead, so it survives the parser and renders in brand green.
///
/// `BoxFit.cover` matches how divine-web frames the same artwork: the wordmark
/// is 3.8:1, so filling a square avatar crops it to the middle "Vi". Contain
/// would letterbox the whole lockup into an illegible sliver.
class ModerationAvatar extends StatelessWidget {
  const ModerationAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.containerLow,
      child: const DivineIcon(icon: DivineIconName.logo, fit: BoxFit.cover),
    );
  }
}

// ABOUTME: "Who reacted" bottom sheet for a DM message — one row per reactor
// ABOUTME: (avatar + name + emoji). The current account's row removes its
// ABOUTME: reaction (or retries when failed); other rows are read-only.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Modal sheet listing every reactor on a DM message.
///
/// The sheet is built under the root [Navigator], outside the conversation's
/// `BlocProvider<ConversationReactionsCubit>` scope, so [show] re-provides the
/// captured [cubit] above the sheet subtree via `contentWrapper` — without it
/// the own-row remove / retry dispatch throws `ProviderNotFoundException`.
/// Riverpod resolves normally (the app `ProviderScope` is above the Navigator),
/// so only the bloc needs re-providing.
abstract class ReactionsDetailSheet {
  /// Show the sheet. [cubit] must be captured from the caller's context
  /// (`context.read<ConversationReactionsCubit>()`) before calling.
  static Future<void> show({
    required BuildContext context,
    required ConversationReactionsCubit cubit,
    required String conversationId,
    required String messageId,
    required String messageAuthorPubkey,
    required String ownerPubkey,
    Set<String> blockedPubkeys = const <String>{},
  }) {
    return VineBottomSheet.show<void>(
      context: context,
      title: Text(
        context.l10n.dmReactionsSheetTitle,
        style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
      ),
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      contentWrapper: (_, child) =>
          BlocProvider<ConversationReactionsCubit>.value(
            value: cubit,
            child: child,
          ),
      buildScrollBody: (scrollController) => _ReactionsDetailBody(
        scrollController: scrollController,
        conversationId: conversationId,
        messageId: messageId,
        messageAuthorPubkey: messageAuthorPubkey,
        ownerPubkey: ownerPubkey,
        blockedPubkeys: blockedPubkeys,
      ),
    );
  }
}

class _ReactionsDetailBody extends StatelessWidget {
  const _ReactionsDetailBody({
    required this.scrollController,
    required this.conversationId,
    required this.messageId,
    required this.messageAuthorPubkey,
    required this.ownerPubkey,
    required this.blockedPubkeys,
  });

  final ScrollController scrollController;
  final String conversationId;
  final String messageId;
  final String messageAuthorPubkey;
  final String ownerPubkey;
  final Set<String> blockedPubkeys;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationReactionsCubit, ConversationReactionsState>(
      builder: (context, state) {
        final reactions =
            state
                .reactionsFor(messageId)
                .where((r) => !blockedPubkeys.contains(r.reactorPubkey))
                .toList()
              // Most-recent reactor first, matching the pill's avatar order.
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (reactions.isEmpty) {
          // The last reaction was just removed — close the sheet, but only
          // when this sheet is still the topmost route. Removing your own
          // (only) reaction already pops the sheet in `_onOwnTap`; without the
          // `isCurrent` guard the post-frame pop below would fall through and
          // dismiss the conversation screen too — a spurious back-navigation.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (ModalRoute.of(context)?.isCurrent ?? false) {
              Navigator.of(context).maybePop();
            }
          });
          return const SizedBox.shrink();
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: reactions.length,
          itemBuilder: (context, index) {
            final reaction = reactions[index];
            return _ReactorRow(
              reaction: reaction,
              isOwn: reaction.reactorPubkey == ownerPubkey,
              conversationId: conversationId,
              messageAuthorPubkey: messageAuthorPubkey,
            );
          },
        );
      },
    );
  }
}

class _ReactorRow extends ConsumerWidget {
  const _ReactorRow({
    required this.reaction,
    required this.isOwn,
    required this.conversationId,
    required this.messageAuthorPubkey,
  });

  final DmReaction reaction;
  final bool isOwn;
  final String conversationId;
  final String messageAuthorPubkey;

  static const double _avatarSize = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(
      userProfileReactiveProvider(reaction.reactorPubkey),
    );
    final profile = profileAsync.asData?.value;
    final name =
        profile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(reaction.reactorPubkey);

    final isFailed = reaction.publishStatus == DmReactionPublishStatus.failed;
    final isPending = reaction.publishStatus == DmReactionPublishStatus.pending;

    final label = isOwn
        ? switch (reaction.publishStatus) {
            DmReactionPublishStatus.pending =>
              context.l10n.dmReactionChipPendingA11yLabel(reaction.emoji),
            DmReactionPublishStatus.failed =>
              context.l10n.dmReactionChipFailedA11yLabel,
            _ => context.l10n.dmReactionChipOwnA11yLabel(reaction.emoji),
          }
        : context.l10n.dmReactionChipOtherA11yLabel(name, reaction.emoji);

    return Semantics(
      button: isOwn && !isPending,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          // cornerRadius == size / 2 renders a true circle whose border is
          // also circular. Wrapping the rounded-square UserAvatar in ClipOval
          // would slice its border into arcs (the "cut border" artifact).
          leading: UserAvatar(
            imageUrl: profile?.picture,
            name: name,
            size: _avatarSize,
            cornerRadius: _avatarSize / 2,
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
          ),
          trailing: _Trailing(
            emoji: reaction.emoji,
            isOwn: isOwn,
            isFailed: isFailed,
            isPending: isPending,
          ),
          onTap: (isOwn && !isPending)
              ? () => _onOwnTap(context, isFailed: isFailed)
              : null,
        ),
      ),
    );
  }

  void _onOwnTap(BuildContext context, {required bool isFailed}) {
    final cubit = context.read<ConversationReactionsCubit>();
    if (isFailed) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.dmReactionChipRetryAnnouncement,
        Directionality.of(context),
      );
      cubit.add(
        ConversationReactionRetryRequested(
          rumorId: reaction.id,
          messageId: reaction.targetMessageId,
          messageAuthorPubkey: messageAuthorPubkey,
          emoji: reaction.emoji,
        ),
      );
      return;
    }
    cubit.add(
      ConversationReactionToggled(
        conversationId: conversationId,
        messageId: reaction.targetMessageId,
        messageAuthorPubkey: messageAuthorPubkey,
        emoji: reaction.emoji,
      ),
    );
    Navigator.of(context).maybePop();
  }
}

class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.emoji,
    required this.isOwn,
    required this.isFailed,
    required this.isPending,
  });

  final String emoji;
  final bool isOwn;
  final bool isFailed;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    // Natural leading — a forced line-height drops the colour-emoji glyph low
    // on Android (see ReactionsRow emoji styling).
    final emojiText = Text(emoji, style: const TextStyle(fontSize: 18));
    if (!isOwn) return emojiText;

    final Widget action;
    if (isPending) {
      action = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: VineTheme.onSurfaceVariant,
        ),
      );
    } else if (isFailed) {
      action = _ActionLabel(
        text: context.l10n.dmReactionRetryAction,
        color: VineTheme.error,
        icon: DivineIconName.arrowClockwise,
      );
    } else {
      action = _ActionLabel(
        text: context.l10n.dmReactionRemoveAction,
        color: VineTheme.onSurfaceVariant,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [emojiText, action],
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final DivineIconName? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        if (icon != null) DivineIcon(icon: icon!, size: 14, color: color),
        Text(text, style: VineTheme.labelMediumFont(color: color)),
      ],
    );
  }
}

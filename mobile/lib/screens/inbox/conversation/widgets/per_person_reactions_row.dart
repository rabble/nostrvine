// ABOUTME: Per-person reaction display for a shared reel in a group DM —
// ABOUTME: one [avatar + emoji] chip per reactor (vs the aggregated counts).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/reactions/conversation_reactions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Shows each group member's reaction on a shared reel individually
/// (`[avatar]❤️`), rather than the aggregated emoji+count chips. Used only for
/// the shared-reel bubble in a group conversation; 1:1 keeps the aggregated row.
class PerPersonReactionsRow extends StatelessWidget {
  /// Construct the row.
  const PerPersonReactionsRow({
    required this.messageId,
    required this.ownerPubkey,
    required this.isSentByMe,
    this.blockedPubkeys = const <String>{},
    super.key,
  });

  /// Rumor id of the reel message whose reactions are shown.
  final String messageId;

  /// The current account (to highlight + label own reactions).
  final String ownerPubkey;

  /// Whether the reel bubble is on the sent (end) side, for alignment.
  final bool isSentByMe;

  /// Reactors to hide (blocks ∪ mutes).
  final Set<String> blockedPubkeys;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationReactionsCubit, ConversationReactionsState>(
      buildWhen: (prev, curr) => !identical(
        prev.reactionsFor(messageId),
        curr.reactionsFor(messageId),
      ),
      builder: (context, state) {
        final reactions = state
            .reactionsFor(messageId)
            .where((r) => !blockedPubkeys.contains(r.reactorPubkey))
            .toList();
        if (reactions.isEmpty) return const SizedBox.shrink();

        return Align(
          alignment: isSentByMe
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final reaction in reactions)
                  _PersonReactionChip(
                    reaction: reaction,
                    isOwn: reaction.reactorPubkey == ownerPubkey,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PersonReactionChip extends ConsumerWidget {
  const _PersonReactionChip({required this.reaction, required this.isOwn});

  final DmReaction reaction;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(
      userProfileReactiveProvider(reaction.reactorPubkey),
    );
    final name = switch (profileAsync) {
      AsyncData(:final value) when value != null => value.bestDisplayName,
      _ => UserProfile.defaultDisplayNameFor(reaction.reactorPubkey),
    };
    final imageUrl = switch (profileAsync) {
      AsyncData(:final value) when value != null => value.picture,
      _ => null,
    };

    final label = isOwn
        ? context.l10n.dmReactionChipOwnA11yLabel(reaction.emoji)
        : context.l10n.dmReactionChipOtherA11yLabel(name, reaction.emoji);

    return MergeSemantics(
      child: Semantics(
        label: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isOwn
                ? VineTheme.primary.withValues(alpha: 0.14)
                : VineTheme.iconButtonBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(3, 3, 8, 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(imageUrl: imageUrl, name: name, size: 20),
                const SizedBox(width: 4),
                Text(reaction.emoji, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

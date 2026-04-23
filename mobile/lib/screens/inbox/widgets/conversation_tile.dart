// ABOUTME: Individual conversation list item for the inbox screen.
// ABOUTME: Shows avatar, display name, last message preview, and relative time.
// ABOUTME: Unread conversations show a red dot indicator next to the timestamp.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

/// A single conversation row in the DM conversation list.
///
/// Layout matches the Figma "preview" component:
/// 40px avatar | 20px gap | content (name + timestamp row, message preview)
/// with a bottom border divider.
class ConversationTile extends ConsumerWidget {
  const ConversationTile({
    required this.conversation,
    required this.currentUserPubkey,
    required this.onTap,
    this.onLongPress,
    this.highlighted = false,
    super.key,
  });

  final DmConversation conversation;
  final String currentUserPubkey;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// When true, applies a [VineTheme.containerLow] background tint to
  /// indicate this row is the target of an open long-press action sheet.
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherPubkey = conversation.participantPubkeys.firstWhere(
      (pk) => pk != currentUserPubkey,
      orElse: () => conversation.participantPubkeys.first,
    );

    final profileAsync = ref.watch(fetchUserProfileProvider(otherPubkey));

    final displayName = profileAsync.maybeWhen(
      data: (profile) => profile?.displayName?.isNotEmpty == true
          ? profile!.displayName!
          : profile?.name ?? NostrKeyUtils.truncateNpub(otherPubkey),
      orElse: () => NostrKeyUtils.truncateNpub(otherPubkey),
    );

    final imageUrl = profileAsync.maybeWhen(
      data: (profile) => profile?.picture,
      orElse: () => null,
    );

    final relativeTime = conversation.lastMessageTimestamp != null
        ? LocalizedTimeFormatter.formatConversationTimestamp(
            context.l10n,
            conversation.lastMessageTimestamp!,
            locale: Localizations.localeOf(context).toLanguageTag(),
          )
        : '';

    return Semantics(
      button: true,
      label: '$displayName conversation',
      onLongPressHint: 'Show conversation actions',
      child: GestureDetector(
        onTap: () {
          Log.debug(
            '🎯 ConversationTile tapped: ${conversation.id}',
            name: 'ConversationTile',
            category: LogCategory.ui,
          );
          onTap();
        },
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: highlighted ? VineTheme.containerLow : null,
            border: const Border(
              bottom: BorderSide(color: VineTheme.outlineDisabled),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: UserAvatar(
                    imageUrl: imageUrl,
                    name: displayName,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + timestamp row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: VineTheme.titleMediumFont(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (relativeTime.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            Text(
                              relativeTime,
                              style: VineTheme.bodyMediumFont(
                                color: VineTheme.onSurfaceMuted,
                              ),
                            ),
                          ],
                          if (!conversation.isRead) ...[
                            const SizedBox(width: 8),
                            const _UnreadDot(),
                          ],
                        ],
                      ),
                      if (conversation.lastMessageContent != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          conversation.lastMessageContent!,
                          style: VineTheme.bodyMediumFont(
                            color: VineTheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: VineTheme.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

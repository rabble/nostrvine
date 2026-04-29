// ABOUTME: Conversation tile variant for message requests.
// ABOUTME: Always shows "Sent a message request" as the subtitle.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

/// A conversation row in the message requests list.
///
/// Layout matches [ConversationTile] but the subtitle always reads
/// "Sent a message request" regardless of last message content.
class RequestTile extends ConsumerWidget {
  const RequestTile({
    required this.conversation,
    required this.currentUserPubkey,
    required this.onTap,
    super.key,
  });

  final DmConversation conversation;
  final String currentUserPubkey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherPubkey = conversation.participantPubkeys.firstWhere(
      (pk) => pk != currentUserPubkey,
      orElse: () => conversation.participantPubkeys.first,
    );

    final profileAsync = ref.watch(userProfileReactiveProvider(otherPubkey));

    final displayName = profileAsync.maybeWhen(
      data: (profile) =>
          profile?.bestDisplayName ??
          UserProfile.defaultDisplayNameFor(otherPubkey),
      orElse: () => UserProfile.defaultDisplayNameFor(otherPubkey),
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
      label: '$displayName message request',
      child: GestureDetector(
        onTap: () {
          Log.debug(
            'RequestTile tapped: ${conversation.id}',
            name: 'RequestTile',
            category: LogCategory.ui,
          );
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: VineTheme.outlineDisabled),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              spacing: 20,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: UserAvatar(
                    imageUrl: imageUrl,
                    name: displayName,
                    placeholderSeed: otherPubkey,
                    size: 40,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 4),
                      Text(
                        'Sent a message request',
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

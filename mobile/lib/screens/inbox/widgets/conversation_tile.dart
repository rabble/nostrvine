// ABOUTME: Individual conversation list item for the inbox screen.
// ABOUTME: Shows avatar, display name, last message preview, and relative time.
// ABOUTME: Unread conversations show a red dot indicator next to the timestamp.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

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

    final profileAsync = ref.watch(fetchUserProfileProvider(otherPubkey));

    final displayName = profileAsync.maybeWhen(
      data: (profile) => profile?.displayName?.isNotEmpty == true
          ? profile!.displayName!
          : profile?.name ?? _fallbackName(otherPubkey),
      orElse: () => _fallbackName(otherPubkey),
    );

    final imageUrl = profileAsync.maybeWhen(
      data: (profile) => profile?.picture,
      orElse: () => null,
    );

    final relativeTime = conversation.lastMessageTimestamp != null
        ? _formatRelativeTime(conversation.lastMessageTimestamp!)
        : '';

    return GestureDetector(
      onTap: onTap,
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
                            style: VineTheme.titleMediumFont(
                              fontSize: 16,
                              height: 24 / 16,
                            ),
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
    );
  }

  static String _fallbackName(String pubkey) =>
      NostrKeyUtils.truncateNpub(pubkey);

  /// Formats a unix timestamp into a relative/calendar string.
  ///
  /// Rules (from Figma annotation):
  /// 1. Under 1 hour: '1m', '5m', '59m'
  /// 2. 1–24 hours: '1h', '3h', '23h'
  /// 3. Yesterday (calendar day): 'Yesterday'
  /// 4. 2–6 days ago: day of week — 'Monday', 'Tuesday', etc.
  /// 5. 7–364 days (same year): 'Mar 3', 'Jan 15'
  /// 6. 1+ years ago: 'Mar 3, 2025'
  static String _formatRelativeTime(int unixTimestamp) {
    final now = DateTime.now();
    final time = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
    final diff = now.difference(time);

    if (diff.isNegative || diff.inSeconds < 60) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';

    // Calendar-based from here.
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);
    final dayDiff = today.difference(messageDay).inDays;

    if (dayDiff == 1) return 'Yesterday';

    if (dayDiff >= 2 && dayDiff <= 6) {
      return _dayName(time.weekday);
    }

    if (time.year == now.year) {
      return '${_monthAbbr(time.month)} ${time.day}';
    }

    return '${_monthAbbr(time.month)} ${time.day}, ${time.year}';
  }

  static String _dayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  static String _monthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
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

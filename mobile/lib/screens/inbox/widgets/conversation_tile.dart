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
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/utils/divine_video_url.dart';
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
      label: context.l10n.inboxConversationTileLabel(displayName),
      onLongPressHint: context.l10n.inboxConversationTileLongPressHint,
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
              // Top-anchored so the avatar lines up with the name on the
              // first line whether the preview wraps to a second line or
              // not, instead of drifting down with a centered column.
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        _ConversationPreviewText(
                          payload: _previewPayload(
                            context,
                            conversation.lastMessageContent!,
                          ),
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

class _PreviewPayload {
  const _PreviewPayload({required this.text, required this.isDivineVideoShare});

  final String text;
  final bool isDivineVideoShare;
}

_PreviewPayload _previewPayload(BuildContext context, String content) {
  // The structured collaborator-invite card carries a deterministic
  // plaintext fallback ("...Open diVine to review and accept.") so old
  // clients can still see something. Inside diVine that copy is misleading
  // — show a localized label instead (#3662, follows up on #3559 Phase 2).
  if (content.endsWith(CollaboratorInviteService.invitePlaintextSuffix)) {
    return _PreviewPayload(
      text: context.l10n.inboxConversationCollabInvitePreview,
      isDivineVideoShare: false,
    );
  }
  // Drop blank lines and trim each remaining line. Shared-video DMs and
  // similar payloads arrive with a blank line between title and URL —
  // without this, `Text(maxLines: 2)` reserves height for the empty line
  // and the tile renders taller than a true one-line preview.
  final lines = content
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final isDivineVideoShare = lines.any(divineVideoUrlLineRegex.hasMatch);
  if (isDivineVideoShare) {
    final nonUrlLines = lines
        .where((line) => !divineVideoUrlLineRegex.hasMatch(line))
        .toList();
    return _PreviewPayload(
      text: nonUrlLines.join('\n'),
      isDivineVideoShare: true,
    );
  }
  return _PreviewPayload(text: lines.join('\n'), isDivineVideoShare: false);
}

/// Two-line preview text with an optional inline camera icon prefix when
/// the last message in the conversation is a divine-video share.
class _ConversationPreviewText extends StatelessWidget {
  const _ConversationPreviewText({required this.payload});

  final _PreviewPayload payload;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant);
    if (!payload.isDivineVideoShare) {
      return Text(
        payload.text,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    // Icon sized to the preview text's line height so it occupies exactly
    // one line of vertical space; rendered white per design.
    final iconSize = style.fontSize! * (style.height ?? 1);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: DivineIcon(
                icon: DivineIconName.cameraRetro,
                color: VineTheme.whiteText,
                size: iconSize,
              ),
            ),
          ),
          if (payload.text.isNotEmpty) TextSpan(text: payload.text),
        ],
      ),
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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

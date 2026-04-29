// ABOUTME: Individual comment widget for flat list display
// ABOUTME: Renders a single comment with author info, content, like button,
// ABOUTME: and reply indicator. Long-press shows options (delete/report/block).

import 'dart:math';

import 'package:comments_repository/comments_repository.dart';
import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/comments/widgets/comment_options_modal.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Widget that renders a single comment in a flat list.
///
/// Replies are distinguished by a 16px left padding and "Re: npub..." indicator.
/// Shows author avatar, name, timestamp, and content.
/// Includes a reply button and like button in the actions row.
/// Long press opens options menu for any comment:
/// - Own comments: Delete
/// - Other users' comments: Flag Content, Block User
///
/// Uses [Comment] from the comments_repository package,
/// following clean architecture separation of UI and repository layers.
class CommentItem extends ConsumerStatefulWidget {
  const CommentItem({required this.comment, this.depth = 0, super.key});

  /// The comment to display.
  final Comment comment;

  /// Nesting depth (0 = top-level, 1+ = reply).
  final int depth;

  @override
  ConsumerState<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends ConsumerState<CommentItem> {
  bool _isHeld = false;

  @override
  Widget build(BuildContext context) {
    // Check if this comment is from the current user
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;
    final isCurrentUser =
        currentUserPubkey.isNotEmpty &&
        currentUserPubkey == widget.comment.authorPubkey;
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.5);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: GestureDetector(
        onLongPressStart: (_) {
          setState(() {
            _isHeld = true;
          });
        },
        onLongPress: () async {
          setState(() {
            _isHeld = false;
          });
          await _showOptionsModal(context, isCurrentUser: isCurrentUser);
        },
        onLongPressCancel: () {
          setState(() {
            _isHeld = false;
          });
        },
        child: ColoredBox(
          color: _isHeld ? VineTheme.containerLow : VineTheme.transparent,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thread lines for nested comments
                if (widget.depth > 0)
                  ...List.generate(
                    min(widget.depth, 4),
                    (i) => Container(
                      width: 24,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: VineTheme.containerLow,
                            width: i == min(widget.depth, 4) - 1 ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Comment content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: widget.depth > 0 ? 8 : 16,
                      right: 16,
                      top: widget.depth > 0 ? 10 : 16,
                      bottom: widget.depth > 0 ? 12 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CommentHeader(
                          authorPubkey: widget.comment.authorPubkey,
                          relativeTime:
                              LocalizedTimeFormatter.formatRelativeVerbose(
                                context.l10n,
                                widget
                                        .comment
                                        .createdAt
                                        .millisecondsSinceEpoch ~/
                                    1000,
                              ),
                          avatarSize: widget.depth >= 2 ? 28.0 : 36.0,
                        ),
                        const SizedBox(height: 12),
                        // Show reply indicator only for orphaned
                        // replies at depth 0
                        if (widget.depth == 0 &&
                            widget.comment.replyToAuthorPubkey != null)
                          _ReplyIndicator(
                            parentAuthorPubkey:
                                widget.comment.replyToAuthorPubkey!,
                          ),
                        Padding(
                          padding: EdgeInsets.only(
                            top:
                                widget.depth == 0 &&
                                    widget.comment.replyToAuthorPubkey != null
                                ? 4
                                : 0,
                          ),
                          child: _CommentContent(
                            commentId: widget.comment.id,
                            content: widget.comment.content,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ActionsRow(
                          commentId: widget.comment.id,
                          authorPubkey: widget.comment.authorPubkey,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showOptionsModal(
    BuildContext context, {
    required bool isCurrentUser,
  }) async {
    if (!mounted) return;

    // Capture BLoC reference before async gap to avoid using context
    // after the widget may have been unmounted
    final bloc = context.read<CommentsBloc>();

    final CommentOptionResult? result;

    if (isCurrentUser) {
      result = await CommentOptionsModal.showForOwnComment(
        context,
        commentId: widget.comment.id,
        commentContent: widget.comment.content,
      );
    } else {
      result = await CommentOptionsModal.showForOtherUserIntegrated(
        context,
        authorPubkey: widget.comment.authorPubkey,
      );
    }

    if (result == null || !mounted) return;

    switch (result) {
      case CommentDeleteResult():
        bloc.add(CommentDeleteRequested(widget.comment.id));
      case CommentReportResult(:final reason, :final details):
        bloc.add(
          CommentReportRequested(
            commentId: widget.comment.id,
            authorPubkey: widget.comment.authorPubkey,
            reason: reason,
            details: details,
          ),
        );
      case CommentBlockUserResult(:final authorPubkey):
        bloc.add(CommentBlockUserRequested(authorPubkey));
      case CommentEditResult(:final commentId, :final content):
        bloc.add(
          CommentEditModeEntered(
            commentId: commentId,
            originalContent: content,
          ),
        );
    }
  }
}

/// Header for a comment showing avatar, user info, timestamp, and "You" indicator.
///
/// Fetches author profile and determines if the comment is from the current user.
class _CommentHeader extends ConsumerWidget {
  const _CommentHeader({
    required this.authorPubkey,
    required this.relativeTime,
    this.avatarSize = 36,
  });

  /// Public key of the comment author
  final String authorPubkey;

  /// Relative time string (e.g., "2h ago")
  final String relativeTime;

  /// Avatar size (smaller for deeply nested comments)
  final double avatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(authorPubkey)).value;

    // Check if this comment is from the current user
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;
    final isCurrentUser =
        currentUserPubkey.isNotEmpty && currentUserPubkey == authorPubkey;

    return Row(
      spacing: 8,
      children: [
        UserAvatar(
          size: avatarSize,
          imageUrl: profile?.picture,
          placeholderSeed: authorPubkey,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    relativeTime,
                    style: VineTheme.labelSmallFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                  ),
                  if (isCurrentUser) ...[
                    Text(
                      ' • ',
                      style: VineTheme.labelSmallFont(
                        color: VineTheme.onSurfaceMuted,
                      ),
                    ),
                    Text(
                      'You',
                      style: VineTheme.labelSmallFont(
                        color: VineTheme.onSurfaceMuted,
                      ),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: () {
                  final npub = NostrKeyUtils.encodePubKey(authorPubkey);
                  context.push(OtherProfileScreen.pathForNpub(npub));
                },
                child: profile == null
                    ? Text(
                        UserProfile.generatedNameFor(authorPubkey),
                        style: const TextStyle(
                          color: VineTheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : UserName.fromUserProfile(
                        profile,
                        style: const TextStyle(
                          color: VineTheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Returns true if [text] contains only emoji characters (up to 3 grapheme
/// clusters) with no text, mentions, or other content.
///
/// Handles compound emojis correctly: Dart's `.characters` segments ZWJ
/// sequences (e.g. 👨‍👩‍👧‍👦), skin-tone variants (👋🏿), flags (🇺🇸),
/// and keycap sequences (1️⃣) as single grapheme clusters. The regex then
/// validates that each grapheme consists only of emoji-related code points.
bool _isEmojiOnly(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  final graphemes = trimmed.characters;
  if (graphemes.length > 3) return false;
  // Check each grapheme is emoji (no ASCII text, no nostr: mentions).
  // Includes Emoji_Component for keycap (\u20e3) and tag sequences,
  // and Regional_Indicator for flag emojis.
  final emojiRegex = RegExp(
    // Emoji component chars (ZWJ, VS-16, keycap, skin tones, digits/#/*)
    r'^[\u200d\ufe0f\u20e30-9#*\u{1F3FB}-\u{1F3FF}'
    // BMP emoji symbols and dingbats
    r'\u00a9\u00ae\u203c\u2049'
    r'\u2194-\u2199\u21a9-\u21aa\u231a-\u231b\u2328\u23cf'
    r'\u23e9-\u23f3\u23f8-\u23fa\u24c2\u25aa-\u25ab\u25b6\u25c0'
    r'\u25fb-\u25fe\u2600-\u27bf\u2934-\u2935\u2b05-\u2b07'
    r'\u2b1b-\u2b1c\u2b50\u2b55\u3030\u303d\u3297\u3299'
    // Supplementary plane emoji (plane 1: mahjong through symbols extended-a)
    r'\u{1F000}-\u{1FFFF}'
    r']+$',
    unicode: true,
  );
  // Exclude bare ASCII digits/symbols that have \p{Emoji} but aren't
  // visually emoji (e.g. "0"-"9", "#", "*").
  final asciiTextRegex = RegExp(r'^[0-9#*]$');
  return graphemes.every(
    (g) => emojiRegex.hasMatch(g) && !asciiTextRegex.hasMatch(g),
  );
}

/// Font size for emoji-only comments (1-3 emoji with no text).
const _emojiOnlyFontSize = 40.0;

/// Content section of a comment showing text with parsed @mentions.
class _CommentContent extends StatelessWidget {
  const _CommentContent({required this.commentId, required this.content});

  /// ID of the comment (for reply targeting)
  final String commentId;

  /// Text content of the comment
  final String content;

  @override
  Widget build(BuildContext context) {
    final isEmoji = _isEmojiOnly(content);
    final baseStyle = TextStyle(
      color: VineTheme.onSurface,
      fontSize: isEmoji ? _emojiOnlyFontSize : 14,
      height: isEmoji ? null : 20 / 14,
    );
    return TapRegion(
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      child: ClickableHashtagText(
        text: content,
        style: baseStyle,
        hashtagStyle: baseStyle.copyWith(
          color: VineTheme.info,
          fontWeight: FontWeight.w500,
        ),
        mentionStyle: baseStyle.copyWith(
          color: VineTheme.tabIndicatorGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.commentId, required this.authorPubkey});

  /// ID of the comment (for reply targeting and vote toggling)
  final String commentId;

  /// Pubkey of the comment author (for vote toggling)
  final String authorPubkey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          identifier: 'reply_button',
          button: true,
          label: 'Reply to comment',
          child: InkWell(
            onTap: () {
              context.read<CommentsBloc>().add(CommentReplyToggled(commentId));
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    DivineIconName.arrowBendDownRight.assetPath,
                    height: MediaQuery.textScalerOf(context).scale(11),
                    colorFilter: const ColorFilter.mode(
                      VineTheme.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reply',
                    style: VineTheme.labelLargeFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        _CommentVoteButtons(commentId: commentId, authorPubkey: authorPubkey),
      ],
    );
  }
}

/// Upvote/downvote buttons for a comment, using BlocSelector for efficient
/// rebuilds.
///
/// Layout: [↑ arrow] [net_score] [↓ arrow]
class _CommentVoteButtons extends StatelessWidget {
  const _CommentVoteButtons({
    required this.commentId,
    required this.authorPubkey,
  });

  final String commentId;
  final String authorPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CommentsBloc,
      CommentsState,
      ({bool isUpvoted, bool isDownvoted, int upvotes, int downvotes})
    >(
      selector: (state) => (
        isUpvoted: state.upvotedCommentIds.contains(commentId),
        isDownvoted: state.downvotedCommentIds.contains(commentId),
        upvotes: state.commentUpvoteCounts[commentId] ?? 0,
        downvotes: state.commentDownvoteCounts[commentId] ?? 0,
      ),
      builder: (context, voteState) {
        final netScore = voteState.upvotes - voteState.downvotes;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Upvote arrow
            Semantics(
              identifier: 'upvote_button',
              button: true,
              label: voteState.isUpvoted ? 'Remove upvote' : 'Upvote comment',
              child: InkWell(
                onTap: () {
                  context.read<CommentsBloc>().add(
                    CommentVoteToggled(
                      commentId: commentId,
                      authorPubkey: authorPubkey,
                      vote: Vote.up,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: SvgPicture.asset(
                    DivineIconName.arrowFatUp.assetPath,
                    height: MediaQuery.textScalerOf(context).scale(16),
                    colorFilter: ColorFilter.mode(
                      voteState.isUpvoted
                          ? VineTheme.vineGreen
                          : VineTheme.onSurfaceMuted,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            // Net score
            if (netScore != 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  netScore.formatScore,
                  style: VineTheme.labelMediumFont(
                    color: voteState.isUpvoted
                        ? VineTheme.vineGreen
                        : voteState.isDownvoted
                        ? VineTheme.likeRed
                        : VineTheme.onSurfaceMuted,
                  ),
                ),
              ),
            // Downvote arrow
            Semantics(
              identifier: 'downvote_button',
              button: true,
              label: voteState.isDownvoted
                  ? 'Remove downvote'
                  : 'Downvote comment',
              child: InkWell(
                onTap: () {
                  context.read<CommentsBloc>().add(
                    CommentVoteToggled(
                      commentId: commentId,
                      authorPubkey: authorPubkey,
                      vote: Vote.down,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: SvgPicture.asset(
                    DivineIconName.arrowFatDown.assetPath,
                    height: MediaQuery.textScalerOf(context).scale(16),
                    colorFilter: ColorFilter.mode(
                      voteState.isDownvoted
                          ? VineTheme.likeRed
                          : VineTheme.onSurfaceMuted,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Formats an [int] score with locale-aware compact suffixes.
extension _ScoreFormatting on int {
  String get formatScore {
    final abs = this.abs();
    final prefix = this < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$prefix${CountFormatter.formatCompact(abs)}';
    }
    return '$this';
  }
}

/// Shows "Re: {display_name}" indicator for replies
/// Fetches parent author profile and displays their name
class _ReplyIndicator extends ConsumerWidget {
  const _ReplyIndicator({required this.parentAuthorPubkey});

  final String parentAuthorPubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(parentAuthorPubkey))
        .value;

    // Get display name with fallback chain
    final displayName =
        profile?.displayName ??
        profile?.name ??
        UserProfile.generatedNameFor(parentAuthorPubkey);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 20,
          padding: const EdgeInsets.symmetric(vertical: 2),
          alignment: Alignment.center,
          child: Text(
            'Re:',
            style: VineTheme.bodyMediumFont(color: VineTheme.tabIndicatorGreen),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: VineTheme.containerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Text(
              displayName,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.tabIndicatorGreen,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}

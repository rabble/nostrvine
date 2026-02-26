// ABOUTME: Options modal for comment actions (delete, report, block)
// ABOUTME: Shows different options for own vs other users' comments

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/services/content_moderation_service.dart';

/// Result of a comment options modal action.
sealed class CommentOptionResult {
  const CommentOptionResult();
}

/// User chose to delete their own comment.
class CommentDeleteResult extends CommentOptionResult {
  const CommentDeleteResult();
}

/// User chose to report another user's comment.
class CommentReportResult extends CommentOptionResult {
  const CommentReportResult({required this.reason, this.details = ''});

  final ContentFilterReason reason;
  final String details;
}

/// User chose to block another user from comments.
class CommentBlockUserResult extends CommentOptionResult {
  const CommentBlockUserResult({required this.authorPubkey});

  final String authorPubkey;
}

/// Modal bottom sheet displaying options for a comment.
///
/// Shows different menus depending on whether the comment is from the
/// current user or another user:
/// - Own comments: Delete
/// - Other users' comments: Flag Content, Block User
///
/// Returns a [CommentOptionResult] or `null` if cancelled.
class CommentOptionsModal {
  /// Shows the options modal for the current user's own comment.
  static Future<CommentOptionResult?> showForOwnComment(
    BuildContext modalContext,
  ) {
    return VineBottomSheet.show<CommentOptionResult>(
      context: modalContext,
      scrollable: false,
      expanded: false,
      title: Text(
        'Options',
        style: VineTheme.titleFont(fontSize: 16, color: VineTheme.onSurface),
      ),
      body: _OptionTile(
        identifier: 'delete_comment_option',
        label: 'Delete',
        semanticLabel: 'Delete comment',
        iconPath: 'assets/icon/delete.svg',
        isDestructive: true,
        onTap: () => modalContext.pop(const CommentDeleteResult()),
      ),
    );
  }

  /// Shows the options modal for another user's comment with an integrated
  /// flag content flow. Closes the modal and returns the result directly.
  static Future<CommentOptionResult?> showForOtherUserIntegrated(
    BuildContext context, {
    required String authorPubkey,
  }) async {
    final action = await VineBottomSheet.show<String>(
      context: context,
      scrollable: false,
      expanded: false,
      title: Text(
        'Options',
        style: VineTheme.titleFont(fontSize: 16, color: VineTheme.onSurface),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OptionTile(
            identifier: 'flag_content_option',
            label: 'Flag Content',
            semanticLabel: 'Flag this content',
            iconPath: 'assets/icon/flag.svg',
            onTap: () => context.pop('flag'),
          ),
          _OptionTile(
            identifier: 'block_user_option',
            label: 'Block User',
            semanticLabel: 'Block this user',
            iconPath: 'assets/icon/flag.svg',
            isDestructive: true,
            onTap: () => context.pop('block'),
          ),
        ],
      ),
    );

    if (action == null) return null;

    if (action == 'block') {
      return CommentBlockUserResult(authorPubkey: authorPubkey);
    }

    if (action == 'flag') {
      // Show flag content sheet as a follow-up
      final reportResult = await _FlagContentSheet.show(context);
      return reportResult;
    }

    return null;
  }
}

/// A single option row in the options sheet.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.identifier,
    required this.label,
    required this.semanticLabel,
    required this.iconPath,
    required this.onTap,
    this.isDestructive = false,
  });

  final String identifier;
  final String label;
  final String semanticLabel;
  final String iconPath;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? VineTheme.likeRed : VineTheme.onSurface;

    return Semantics(
      identifier: identifier,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SvgPicture.asset(
                iconPath,
                height: 18,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: VineTheme.bodyFont(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for selecting a report reason when flagging content.
class _FlagContentSheet extends StatefulWidget {
  const _FlagContentSheet();

  static Future<CommentReportResult?> show(BuildContext context) {
    return showModalBottomSheet<CommentReportResult>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _FlagContentSheet(),
    );
  }

  @override
  State<_FlagContentSheet> createState() => _FlagContentSheetState();
}

class _FlagContentSheetState extends State<_FlagContentSheet> {
  ContentFilterReason? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
      decoration: const BoxDecoration(
        color: VineTheme.backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Flag Content',
                    style: VineTheme.titleFont(
                      fontSize: 18,
                      color: VineTheme.onSurface,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: VineTheme.onSurfaceMuted,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Select a reason for flagging this comment',
                style: VineTheme.bodyFont(
                  fontSize: 14,
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final reason in ContentFilterReason.values)
                      _ReasonRadioTile(
                        reason: reason,
                        isSelected: _selectedReason == reason,
                        onTap: () {
                          setState(() {
                            _selectedReason = reason;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedReason != null
                      ? () {
                          Navigator.pop(
                            context,
                            CommentReportResult(
                              reason: _selectedReason!,
                              details: _getReasonDisplayName(_selectedReason!),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedReason != null
                        ? VineTheme.vineGreen
                        : VineTheme.containerLow,
                    foregroundColor: _selectedReason != null
                        ? VineTheme.backgroundColor
                        : VineTheme.onSurfaceMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Submit',
                    style: VineTheme.bodyFont(
                      fontWeight: FontWeight.w700,
                      color: _selectedReason != null
                          ? VineTheme.backgroundColor
                          : VineTheme.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRadioTile extends StatelessWidget {
  const _ReasonRadioTile({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  final ContentFilterReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? VineTheme.vineGreen
                      : VineTheme.onSurfaceMuted,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: VineTheme.vineGreen,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getReasonDisplayName(reason),
                style: VineTheme.bodyFont(
                  color: isSelected
                      ? VineTheme.onSurface
                      : VineTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _getReasonDisplayName(ContentFilterReason reason) {
  return switch (reason) {
    ContentFilterReason.spam => 'Spam or Unwanted Content',
    ContentFilterReason.harassment => 'Harassment, Bullying, or Threats',
    ContentFilterReason.violence => 'Violent or Extremist Content',
    ContentFilterReason.sexualContent => 'Sexual or Adult Content',
    ContentFilterReason.copyright => 'Copyright Violation',
    ContentFilterReason.falseInformation => 'False Information',
    ContentFilterReason.csam => 'Child Safety Violation',
    ContentFilterReason.aiGenerated => 'AI-Generated Content',
    ContentFilterReason.other => 'Other Policy Violation',
  };
}

// ABOUTME: Three-dots more action button for video feed overlay.
// ABOUTME: Opens bottom sheet with Report, Mute, Block, View JSON, Copy Event ID.

import 'dart:convert';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Three-dots more action button for the video overlay.
///
/// Opens a bottom sheet with moderation and developer actions:
/// Report, Mute, Block, View Nostr event JSON, Copy Nostr event ID.
class MoreActionButton extends StatelessWidget {
  const MoreActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'more_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'More options',
          child: GestureDetector(
            onTap: () {
              Log.info(
                'More button tapped for ${video.id}',
                name: 'MoreActionButton',
                category: LogCategory.ui,
              );
              context.showVideoPausingVineBottomSheet<void>(
                builder: (context) => _VideoMoreMenu(video: video),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VineTheme.scrim30,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const DivineIcon(
                icon: DivineIconName.dotsThree,
                size: 24,
                color: VineTheme.whiteText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoMoreMenu extends ConsumerWidget {
  const _VideoMoreMenu({required this.video});

  final VideoEvent video;

  void _safePop(BuildContext ctx) {
    if (ctx.canPop()) {
      ctx.pop();
    } else {
      Navigator.of(ctx).maybePop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: VineTheme.surfaceBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MoreMenuHeader(video: video),
            const Divider(color: VineTheme.cardBackground, height: 1),
            _MoreMenuItems(
              video: video,
              onReport: () => _handleReport(context),
              onMute: () => _handleMute(context, ref),
              onBlock: () => _handleBlock(context, ref),
              onViewSource: () => _handleViewSource(context),
              onCopyEventId: () => _handleCopyEventId(context),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => ReportContentDialog(video: video),
    );
  }

  Future<void> _handleMute(BuildContext context, WidgetRef ref) async {
    try {
      final muteService = await ref.read(muteServiceProvider.future);
      await muteService.muteUser(video.pubkey);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User muted')));
        _safePop(context);
      }
    } catch (e) {
      Log.error(
        'Failed to mute user: $e',
        name: 'VideoMoreMenu',
        category: LogCategory.ui,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to mute user')));
        _safePop(context);
      }
    }
  }

  void _handleBlock(BuildContext context, WidgetRef ref) {
    final blocklistService = ref.read(contentBlocklistServiceProvider);
    final nostrClient = ref.read(nostrServiceProvider);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Block User?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: const Text(
          "You won't see their content in feeds. "
          "They won't be notified.",
          style: TextStyle(color: VineTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: dialogContext.pop,
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () {
              try {
                blocklistService.blockUser(
                  video.pubkey,
                  ourPubkey: nostrClient.publicKey,
                );
                dialogContext.pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('User blocked')));
                  _safePop(context);
                }
              } catch (e) {
                Log.error(
                  'Failed to block user: $e',
                  name: 'VideoMoreMenu',
                  category: LogCategory.ui,
                );
                if (dialogContext.mounted) dialogContext.pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to block user')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: VineTheme.error),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _handleViewSource(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _ViewSourceDialog(video: video),
    );
  }

  Future<void> _handleCopyEventId(BuildContext context) async {
    try {
      final nevent = NIP19Tlv.encodeNevent(
        Nevent(
          id: video.id,
          author: video.pubkey,
          relays: ['wss://relay.divine.video'],
        ),
      );
      await Clipboard.setData(ClipboardData(text: nevent));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event ID copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
        _safePop(context);
      }
    } catch (e) {
      Log.error(
        'Failed to copy event ID: $e',
        name: 'VideoMoreMenu',
        category: LogCategory.ui,
      );
    }
  }
}

class _MoreMenuHeader extends ConsumerWidget {
  const _MoreMenuHeader({required this.video});

  static const double _avatarSize = 40;

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileReactiveProvider(video.pubkey));

    final videoTitle = video.title?.isNotEmpty == true
        ? video.title!
        : video.content;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        spacing: 12,
        children: [
          profileAsync.when(
            data: (profile) => UserAvatar(
              imageUrl: profile?.picture,
              name: profile?.displayName,
              size: _avatarSize,
            ),
            loading: () => const UserAvatar(size: _avatarSize),
            error: (_, __) => const UserAvatar(size: _avatarSize),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (videoTitle.isNotEmpty)
                  Text(
                    videoTitle,
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                UserName.fromPubKey(
                  video.pubkey,
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreMenuItems extends ConsumerWidget {
  const _MoreMenuItems({
    required this.video,
    required this.onReport,
    required this.onMute,
    required this.onBlock,
    required this.onViewSource,
    required this.onCopyEventId,
  });

  final VideoEvent video;
  final VoidCallback onReport;
  final VoidCallback onMute;
  final VoidCallback onBlock;
  final VoidCallback onViewSource;
  final VoidCallback onCopyEventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileReactiveProvider(video.pubkey));
    final displayName =
        profileAsync.whenOrNull(data: (profile) => profile?.bestDisplayName) ??
        '';
    final showDebugTools = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.debugTools),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MoreMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.flag,
            color: VineTheme.error,
          ),
          label: 'Report content',
          labelColor: VineTheme.error,
          onTap: onReport,
        ),
        _MoreMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.eyeSlash,
            color: VineTheme.error,
          ),
          label: displayName.isNotEmpty ? 'Mute $displayName' : 'Mute user',
          labelColor: VineTheme.error,
          onTap: onMute,
        ),
        _MoreMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.prohibit,
            color: VineTheme.error,
          ),
          label: displayName.isNotEmpty ? 'Block $displayName' : 'Block user',
          labelColor: VineTheme.error,
          onTap: onBlock,
        ),
        if (showDebugTools) ...[
          const Divider(color: VineTheme.cardBackground, height: 1),
          _MoreMenuItem(
            icon: const DivineIcon(
              icon: DivineIconName.bracketsAngle,
              color: VineTheme.whiteText,
            ),
            label: 'View Nostr event JSON',
            labelColor: VineTheme.whiteText,
            onTap: onViewSource,
          ),
          _MoreMenuItem(
            icon: const DivineIcon(
              icon: DivineIconName.copySimple,
              color: VineTheme.whiteText,
            ),
            label: 'Copy Nostr event ID',
            labelColor: VineTheme.whiteText,
            onTap: onCopyEventId,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          spacing: 16,
          children: [
            icon,
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for viewing raw Nostr event JSON.
class _ViewSourceDialog extends StatelessWidget {
  const _ViewSourceDialog({required this.video});
  final VideoEvent video;

  // Warning color for the explainer note
  static const _warningColor = VineTheme.accentOrange;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Row(
        spacing: 12,
        children: [
          DivineIcon(
            icon: DivineIconName.bracketsAngle,
            color: VineTheme.vineGreen,
          ),
          Text('Event Source', style: TextStyle(color: VineTheme.whiteText)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Row(
              spacing: 4,
              children: [
                const Text(
                  'Event ID: ',
                  style: TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text(
                    video.id,
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  color: VineTheme.vineGreen,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: video.id));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Event ID copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _warningColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Parsed event data, not raw Nostr source',
                style: TextStyle(
                  color: _warningColor,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VineTheme.lightText),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _getEventJson(),
                    style: const TextStyle(
                      color: VineTheme.whiteText,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final json = _getEventJson();
            await Clipboard.setData(ClipboardData(text: json));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('JSON copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: const Text('Copy JSON'),
        ),
        TextButton(onPressed: context.pop, child: const Text('Close')),
      ],
    );
  }

  String _getEventJson() {
    return const JsonEncoder.withIndent('  ').convert(video.toJson());
  }
}

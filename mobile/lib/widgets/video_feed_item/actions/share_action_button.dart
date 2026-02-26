// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Displays share icon, opens simplified share bottom sheet.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/send_to_user_dialog.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:share_plus/share_plus.dart';

/// Share action button for video overlay.
///
/// Shows a share icon that opens a simplified share bottom sheet with:
/// Share with user, Add to list, Add to bookmarks, More options (native share).
class ShareActionButton extends StatelessWidget {
  const ShareActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'share_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'Share video',
          child: IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            style: IconButton.styleFrom(
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () {
              Log.info(
                'Share button tapped for ${video.id}',
                name: 'ShareActionButton',
                category: LogCategory.ui,
              );
              context.showVideoPausingVineBottomSheet<void>(
                builder: (context) => _SimpleShareMenu(video: video),
              );
            },
            icon: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: VineTheme.backgroundColor.withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const DivineIcon(
                icon: DivineIconName.shareFat,
                size: 32,
                color: VineTheme.whiteText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SimpleShareMenu extends ConsumerStatefulWidget {
  const _SimpleShareMenu({required this.video});

  final VideoEvent video;

  @override
  ConsumerState<_SimpleShareMenu> createState() => _SimpleShareMenuState();
}

class _SimpleShareMenuState extends ConsumerState<_SimpleShareMenu> {
  void _safePop(BuildContext ctx) {
    if (ctx.canPop()) {
      ctx.pop();
    } else {
      Navigator.of(ctx).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCuratedLists = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );

    return Material(
      color: VineTheme.surfaceBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DragIndicator(),
            _ShareMenuHeader(video: widget.video),
            const Divider(color: VineTheme.cardBackground, height: 1),
            _ShareMenuItems(
              onShareWithUser: _handleShareWithUser,
              onAddToList: showCuratedLists ? _handleAddToList : null,
              onAddToBookmarks: _handleAddToBookmarks,
              onMoreOptions: _handleMoreOptions,
            ),
          ],
        ),
      ),
    );
  }

  void _handleShareWithUser() {
    _safePop(context);
    showDialog<void>(
      context: context,
      builder: (context) => SendToUserDialog(video: widget.video),
    );
  }

  void _handleAddToList() {
    _safePop(context);
    showDialog<void>(
      context: context,
      builder: (context) => SelectListDialog(video: widget.video),
    );
  }

  Future<void> _handleAddToBookmarks() async {
    try {
      final bookmarkService = await ref.read(bookmarkServiceProvider.future);
      final success = await bookmarkService.addVideoToGlobalBookmarks(
        widget.video.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Added to bookmarks!' : 'Failed to add bookmark',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _safePop(context);
      }
    } catch (e) {
      Log.error(
        'Failed to add bookmark: $e',
        name: 'SimpleShareMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add bookmark'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleMoreOptions() async {
    try {
      final sharingService = ref.read(videoSharingServiceProvider);
      final shareText = sharingService.generateShareText(widget.video);

      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (e) {
      Log.error(
        'Failed to share externally: $e',
        name: 'SimpleShareMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share video'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _DragIndicator extends StatelessWidget {
  const _DragIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: VineTheme.secondaryText,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ShareMenuHeader extends ConsumerWidget {
  const _ShareMenuHeader({required this.video});

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
        children: [
          profileAsync.when(
            data: (profile) => UserAvatar(
              imageUrl: profile?.picture,
              name: profile?.displayName,
              size: 40,
            ),
            loading: () => const UserAvatar(size: 40),
            error: (_, _) => const UserAvatar(size: 40),
          ),
          const SizedBox(width: 12),
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

class _ShareMenuItems extends StatelessWidget {
  const _ShareMenuItems({
    required this.onShareWithUser,
    required this.onAddToBookmarks,
    required this.onMoreOptions,
    this.onAddToList,
  });

  final VoidCallback onShareWithUser;
  final VoidCallback? onAddToList;
  final VoidCallback onAddToBookmarks;
  final VoidCallback onMoreOptions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShareMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.chats,
            color: VineTheme.whiteText,
          ),
          label: 'Share with user',
          onTap: onShareWithUser,
        ),
        if (onAddToList != null)
          _ShareMenuItem(
            icon: const DivineIcon(
              icon: DivineIconName.listPlus,
              color: VineTheme.whiteText,
            ),
            label: 'Add to list',
            onTap: onAddToList!,
          ),
        _ShareMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.bookmarkSimple,
            color: VineTheme.whiteText,
          ),
          label: 'Add to bookmarks',
          onTap: onAddToBookmarks,
        ),
        _ShareMenuItem(
          icon: const DivineIcon(
            icon: DivineIconName.shareFat,
            color: VineTheme.whiteText,
          ),
          label: 'More options',
          onTap: onMoreOptions,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ShareMenuItem extends StatelessWidget {
  const _ShareMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: VineTheme.whiteText,
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

// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Opens unified share sheet with horizontal contacts row, message
// ABOUTME: input, and more actions (save, copy, share via, report, etc.).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/find_people_sheet.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:share_plus/share_plus.dart';

/// Share action button for video overlay.
///
/// Shows a share icon that opens a unified share bottom sheet with:
/// - Video context/preview header
/// - "Share with" horizontal contact row with "Find people" search
/// - Optional message input when a recipient is selected
/// - "More actions" horizontal row (Save, Add to List, Copy, Share via,
///   Report, Mute, Block, Event JSON, Event ID)
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
                builder: (context) => _UnifiedShareSheet(video: video),
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

// ---------------------------------------------------------------------------
// Unified Share Sheet (Page — creates BLoC, handles side effects)
// ---------------------------------------------------------------------------

class _UnifiedShareSheet extends ConsumerStatefulWidget {
  const _UnifiedShareSheet({required this.video});

  final VideoEvent video;

  @override
  ConsumerState<_UnifiedShareSheet> createState() => _UnifiedShareSheetState();
}

class _UnifiedShareSheetState extends ConsumerState<_UnifiedShareSheet> {
  final TextEditingController _messageController = TextEditingController();
  late final ShareSheetBloc _bloc;

  @override
  void initState() {
    super.initState();
    final bookmarkService = ref.read(bookmarkServiceProvider).value;

    _bloc = ShareSheetBloc(
      video: widget.video,
      videoSharingService: ref.read(videoSharingServiceProvider),
      userProfileService: ref.read(userProfileServiceProvider),
      followRepository: ref.read(followRepositoryProvider),
      bookmarkService: bookmarkService,
    )..add(const ShareSheetContactsLoadRequested());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _safePop(BuildContext ctx) {
    try {
      if (ctx.canPop()) {
        ctx.pop();
        return;
      }
    } catch (_) {
      // GoRouter not found; fall through to Navigator.
    }
    Navigator.of(ctx).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<ShareSheetBloc, ShareSheetState>(
        listenWhen: (prev, curr) =>
            curr.actionResult != null && prev.actionResult != curr.actionResult,
        listener: _handleActionResult,
        child: _UnifiedShareSheetView(
          video: widget.video,
          messageController: _messageController,
          onFindPeople: _handleFindPeople,
          onAddToList: _handleAddToList,
          onReport: _handleReport,
        ),
      ),
    );
  }

  void _handleActionResult(BuildContext context, ShareSheetState state) {
    final result = state.actionResult;
    if (result == null) return;

    final messenger = ScaffoldMessenger.of(context);

    switch (result) {
      case ShareSheetSendSuccess(:final recipientName, :final shouldDismiss):
        if (shouldDismiss) _safePop(context);
        messenger.showSnackBar(_shareSuccessSnackBar(messenger, recipientName));
      case ShareSheetSendFailure(:final error):
        messenger.showSnackBar(_styledSnackBar(error));
      case ShareSheetSaveSuccess():
        _safePop(context);
        messenger.showSnackBar(_styledSnackBar('Added to bookmarks'));
      case ShareSheetSaveFailure():
        _safePop(context);
        messenger.showSnackBar(_styledSnackBar('Failed to add bookmark'));
      case ShareSheetCopiedToClipboard(:final label, :final text):
        Clipboard.setData(ClipboardData(text: text));
        _safePop(context);
        messenger.showSnackBar(_styledSnackBar(label));
      case ShareSheetShareViaTriggered(:final shareText):
        SharePlus.instance.share(ShareParams(text: shareText));
    }
  }

  Future<void> _handleFindPeople() async {
    final selectedUser = await FindPeopleSheet.show(context);
    if (selectedUser != null && mounted) {
      _bloc.add(ShareSheetRecipientSelected(selectedUser));
    }
  }

  void _handleAddToList() {
    _safePop(context);
    showDialog<void>(
      context: context,
      builder: (context) => SelectListDialog(video: widget.video),
    );
  }

  void _handleReport() {
    _safePop(context);
    showDialog<void>(
      context: context,
      builder: (context) => ReportContentDialog(video: widget.video),
    );
  }

  SnackBar _styledSnackBar(String message) => SnackBar(
    content: Text(message, style: const TextStyle(color: VineTheme.whiteText)),
    backgroundColor: VineTheme.containerLow,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  );

  SnackBar _shareSuccessSnackBar(
    ScaffoldMessengerState messenger,
    String recipientName,
  ) => SnackBar(
    content: Row(
      children: [
        Expanded(
          child: Text(
            'Post shared with $recipientName',
            style: const TextStyle(color: VineTheme.whiteText),
          ),
        ),
        GestureDetector(
          onTap: () {
            messenger.hideCurrentSnackBar();
            // TODO: navigate to chat screen when implemented
          },
          child: Text(
            'View Chat',
            style: VineTheme.bodyMediumFont(
              color: VineTheme.vineGreen,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
    backgroundColor: VineTheme.containerLow,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 4),
  );
}

// ---------------------------------------------------------------------------
// Unified Share Sheet View (pure UI — reads BLoC state)
// ---------------------------------------------------------------------------

class _UnifiedShareSheetView extends StatelessWidget {
  const _UnifiedShareSheetView({
    required this.video,
    required this.messageController,
    required this.onFindPeople,
    required this.onAddToList,
    required this.onReport,
  });

  final VideoEvent video;
  final TextEditingController messageController;
  final VoidCallback onFindPeople;
  final VoidCallback onAddToList;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VineTheme.surfaceBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        child: SingleChildScrollView(
          child: BlocBuilder<ShareSheetBloc, ShareSheetState>(
            builder: (context, state) {
              final bloc = context.read<ShareSheetBloc>();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _DragIndicator(),
                  _ShareSheetHeader(video: video),
                  const Divider(color: VineTheme.cardBackground, height: 1),
                  _ShareWithSection(
                    contacts: state.contacts,
                    contactsLoaded: state.contactsLoaded,
                    selectedRecipient: state.selectedRecipient,
                    sentPubkeys: state.sentPubkeys,
                    onFindPeople: onFindPeople,
                    onContactTapped: (user) =>
                        bloc.add(ShareSheetQuickSendRequested(user)),
                  ),
                  if (state.selectedRecipient != null)
                    _MessageInput(
                      controller: messageController,
                      recipient: state.selectedRecipient!,
                      isSending: state.isSending,
                      onSend: () => bloc.add(
                        ShareSheetSendRequested(
                          message: messageController.text,
                        ),
                      ),
                    ),
                  if (state.selectedRecipient == null) ...[
                    const Divider(color: VineTheme.cardBackground, height: 1),
                    _MoreActionsSection(
                      video: video,
                      onSave: () => bloc.add(const ShareSheetSaveRequested()),
                      onAddToList: onAddToList,
                      onCopyLink: () =>
                          bloc.add(const ShareSheetCopyLinkRequested()),
                      onShareVia: () =>
                          bloc.add(const ShareSheetShareViaRequested()),
                      onReport: onReport,
                      onCopyEventJson: () =>
                          bloc.add(const ShareSheetCopyEventJsonRequested()),
                      onCopyEventId: () =>
                          bloc.add(const ShareSheetCopyEventIdRequested()),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

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

class _ShareSheetHeader extends ConsumerWidget {
  const _ShareSheetHeader({required this.video});

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
            error: (_, __) => const UserAvatar(size: 40),
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
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: VideoThumbnailWidget(video: video, width: 40, height: 56),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Share with" horizontal contact row
// ---------------------------------------------------------------------------

class _ShareWithSection extends StatelessWidget {
  const _ShareWithSection({
    required this.contacts,
    required this.contactsLoaded,
    required this.selectedRecipient,
    required this.sentPubkeys,
    required this.onFindPeople,
    required this.onContactTapped,
  });

  final List<ShareableUser> contacts;
  final bool contactsLoaded;
  final ShareableUser? selectedRecipient;
  final Set<String> sentPubkeys;
  final VoidCallback onFindPeople;
  final ValueChanged<ShareableUser> onContactTapped;

  static const double _itemWidth = 72;
  static const double _avatarSize = 48;
  static const double _rowHeight = 90;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Share with',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _rowHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: contactsLoaded ? contacts.length + 1 : 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FindPeopleItem(onTap: onFindPeople);
                }

                final contact = contacts[index - 1];
                final isSelected = selectedRecipient?.pubkey == contact.pubkey;
                final isSent = sentPubkeys.contains(contact.pubkey);

                return _ContactItem(
                  user: contact,
                  isSelected: isSelected,
                  isSent: isSent,
                  onTap: () => onContactTapped(contact),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FindPeopleItem extends StatelessWidget {
  const _FindPeopleItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _ShareWithSection._itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _ShareWithSection._avatarSize,
              height: _ShareWithSection._avatarSize,
              decoration: BoxDecoration(
                color: VineTheme.vineGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(
                  _ShareWithSection._avatarSize * 0.286,
                ),
              ),
              child: const Center(
                child: DivineIcon(
                  icon: DivineIconName.search,
                  size: 24,
                  color: VineTheme.vineGreen,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Find\npeople',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({
    required this.user,
    required this.isSelected,
    required this.isSent,
    required this.onTap,
  });

  final ShareableUser user;
  final bool isSelected;
  final bool isSent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSent ? null : onTap,
      child: SizedBox(
        width: _ShareWithSection._itemWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Opacity(
                  opacity: isSent ? 0.5 : 1.0,
                  child: UserAvatar(
                    imageUrl: user.picture,
                    name: user.displayName,
                    size: _ShareWithSection._avatarSize,
                  ),
                ),
                if (isSelected || isSent)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: VineTheme.vineGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: VineTheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isSent ? 'Sent' : (user.displayName ?? 'User'),
              style: TextStyle(
                color: (isSelected || isSent)
                    ? VineTheme.vineGreen
                    : VineTheme.secondaryText,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message input (shown when a recipient is selected)
// ---------------------------------------------------------------------------

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.recipient,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final ShareableUser recipient;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                UserAvatar(
                  imageUrl: recipient.picture,
                  name: recipient.displayName,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sending to ${recipient.displayName ?? 'user'}',
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add optional message...',
                    hintStyle: const TextStyle(color: VineTheme.secondaryText),
                    filled: true,
                    fillColor: VineTheme.containerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(isSending: isSending, onTap: onSend),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending, required this.onTap});

  final bool isSending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSending ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSending
              ? VineTheme.vineGreen.withValues(alpha: 0.5)
              : VineTheme.vineGreen,
          shape: BoxShape.circle,
        ),
        child: isSending
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VineTheme.onPrimary,
                ),
              )
            : const Icon(
                Icons.arrow_upward,
                size: 22,
                color: VineTheme.onPrimary,
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "More actions" horizontal row
// ---------------------------------------------------------------------------

class _MoreActionsSection extends ConsumerWidget {
  const _MoreActionsSection({
    required this.video,
    required this.onSave,
    required this.onAddToList,
    required this.onCopyLink,
    required this.onShareVia,
    required this.onReport,
    required this.onCopyEventJson,
    required this.onCopyEventId,
  });

  final VideoEvent video;
  final VoidCallback onSave;
  final VoidCallback onAddToList;
  final VoidCallback onCopyLink;
  final VoidCallback onShareVia;
  final VoidCallback onReport;
  final VoidCallback onCopyEventJson;
  final VoidCallback onCopyEventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCuratedLists = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    final showDebugTools = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.debugTools),
    );

    final actions = <_ActionData>[
      _ActionData(
        icon: DivineIconName.bookmarkSimple,
        label: 'Save',
        onTap: onSave,
      ),
      if (showCuratedLists)
        _ActionData(
          icon: DivineIconName.listPlus,
          label: 'Add to List',
          onTap: onAddToList,
        ),
      _ActionData(
        icon: DivineIconName.linkSimple,
        label: 'Copy',
        onTap: onCopyLink,
      ),
      _ActionData(
        icon: DivineIconName.shareFat,
        label: 'Share via',
        onTap: onShareVia,
      ),
      _ActionData(
        icon: DivineIconName.flag,
        label: 'Report',
        onTap: onReport,
        isDestructive: true,
      ),
      if (showDebugTools) ...[
        _ActionData(
          icon: DivineIconName.bracketsAngle,
          label: 'Event JSON',
          onTap: onCopyEventJson,
        ),
        _ActionData(
          icon: DivineIconName.copySimple,
          label: 'Event ID',
          onTap: onCopyEventId,
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'More actions',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: actions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final action = actions[index];
                return _ActionCircle(
                  icon: action.icon,
                  label: action.label,
                  isDestructive: action.isDestructive,
                  onTap: action.onTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionData {
  const _ActionData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  static const double _circleSize = 48;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDestructive
        ? VineTheme.error.withValues(alpha: 0.15)
        : VineTheme.vineGreen.withValues(alpha: 0.15);
    final iconColor = isDestructive ? VineTheme.error : VineTheme.vineGreen;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _circleSize,
              height: _circleSize,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Center(
                child: DivineIcon(icon: icon, size: 22, color: iconColor),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isDestructive
                    ? VineTheme.error
                    : VineTheme.secondaryText,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

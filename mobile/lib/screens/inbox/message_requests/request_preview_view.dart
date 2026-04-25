// ABOUTME: View for the message request preview screen.
// ABOUTME: Shows sender profile info, message count, and accept/decline actions.

import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// View for the message request preview screen.
///
/// Displays the sender's profile (avatar, name, NIP-05, stats),
/// a "View profile" button, message count text, and two action buttons:
/// "View messages" (accept) and "Decline and remove".
class RequestPreviewView extends ConsumerWidget {
  const RequestPreviewView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantPubkeys = context.select(
      (RequestPreviewCubit cubit) => cubit.state.participantPubkeys,
    );
    final messageCount = context.select(
      (RequestPreviewCubit cubit) => cubit.state.messageCount,
    );

    final otherPubkey = participantPubkeys.isNotEmpty
        ? participantPubkeys.first
        : '';

    final profileAsync = ref.watch(userProfileReactiveProvider(otherPubkey));

    final profile = profileAsync.asData?.value;

    final displayName =
        profile?.bestDisplayName ?? NostrKeyUtils.truncateNpub(otherPubkey);

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        title: displayName,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VineTheme.bottomSheetBorderRadius),
        ),
        child: ColoredBox(
          color: VineTheme.surfaceContainerHigh,
          child: Column(
            children: [
              Expanded(
                child: _ProfileContent(
                  displayName: displayName,
                  profile: profile,
                  otherPubkey: otherPubkey,
                  messageCount: messageCount,
                ),
              ),
              _ActionButtons(participantPubkeys: participantPubkeys),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.displayName,
    required this.profile,
    required this.otherPubkey,
    required this.messageCount,
  });

  final String displayName;
  final UserProfile? profile;
  final String otherPubkey;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    final imageUrl = profile?.picture;
    final nip05 = profile?.displayNip05;
    final followerCount = profile?.followerCount;
    final videoCount = profile?.videoCount;

    return ColoredBox(
      color: VineTheme.scrim15,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(imageUrl: imageUrl, name: displayName, size: 96),
              const SizedBox(height: 32),
              Text(
                displayName,
                style: VineTheme.titleLargeFont(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (nip05 != null && nip05.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  nip05,
                  style: VineTheme.bodySmallFont(
                    color: VineTheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (followerCount != null || videoCount != null) ...[
                const SizedBox(height: 4),
                _StatsLine(
                  followerCount: followerCount,
                  videoCount: videoCount,
                ),
              ],
              const SizedBox(height: 16),
              _OutlinedActionButton(
                label: 'View profile',
                onTap: () => context.push(
                  OtherProfileScreen.pathForNpub(
                    NostrKeyUtils.encodePubKey(otherPubkey),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _MessageCountDescription(
                displayName: displayName,
                messageCount: messageCount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsLine extends StatelessWidget {
  const _StatsLine({this.followerCount, this.videoCount});

  final int? followerCount;
  final int? videoCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (followerCount != null) {
      parts.add('${CountFormatter.formatCompact(followerCount!)} Followers');
    }
    if (videoCount != null) {
      parts.add('${CountFormatter.formatCompact(videoCount!)} videos');
    }

    return Text(
      parts.join(' \u2022 '),
      style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
      textAlign: TextAlign.center,
    );
  }
}

class _MessageCountDescription extends StatelessWidget {
  const _MessageCountDescription({
    required this.displayName,
    required this.messageCount,
  });

  final String displayName;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    final msgText = messageCount == 1 ? '1 message' : '$messageCount messages';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        "$displayName wants to message you, they've sent $msgText.",
        style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.participantPubkeys});

  final List<String> participantPubkeys;

  @override
  Widget build(BuildContext context) {
    final conversationId = context.read<RequestPreviewCubit>().conversationId;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            _PrimaryActionButton(
              label: 'View messages',
              onTap: () {
                context.pushReplacementNamed(
                  ConversationPage.routeName,
                  pathParameters: {'id': conversationId},
                  extra: participantPubkeys,
                );
              },
            ),
            _SecondaryActionButton(
              label: 'Decline and remove',
              onTap: () async {
                await context.read<MessageRequestActionsCubit>().declineRequest(
                  conversationId,
                );
                if (context.mounted) context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                label,
                style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            border: Border.all(color: VineTheme.outlineMuted, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: VineTheme.titleMediumFont(color: VineTheme.primary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainer,
              border: Border.all(color: VineTheme.outlineMuted, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                label,
                style: VineTheme.titleMediumFont(color: VineTheme.primary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ABOUTME: Hard-gate screen shown when an authenticated account is restricted
// ABOUTME: pending parental consent / minor-account review.

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';

class MinorAccountReviewScreen extends ConsumerWidget {
  static const routeName = 'minor-account-review';
  static const path = '/account-review';

  const MinorAccountReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(currentMinorAccountReviewStatusProvider);

    return Scaffold(
      appBar: const DiVineAppBar(
        title: 'Account Review',
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: statusAsync.when(
              data: (status) => _LoadedView(status: status),
              loading: () => const Center(
                child: PartialCircleSpinner(progress: 0.33),
              ),
              error: (error, _) => _ErrorView(
                error: error,
                onRetry: () =>
                    ref.invalidate(currentMinorAccountReviewStatusProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadedView extends ConsumerWidget {
  const _LoadedView({required this.status});

  final MinorAccountReviewStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewCase = status.currentCase;
    final title = reviewCase?.instructions.title ?? 'Account review required';
    final body =
        reviewCase?.instructions.body ??
        'We need to review this account before it can use Divine normally.';
    final supportEmail = reviewCase?.supportEmail ?? 'support@divine.video';
    final caseId = reviewCase?.id;
    final primaryAction = _primaryAction(reviewCase);
    final infoCard = _infoCardForCase(reviewCase, supportEmail);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: VineTheme.vineGreen.withValues(alpha: .2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: VineTheme.headlineMediumFont()),
              const SizedBox(height: 12),
              Text(
                body,
                style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
              ),
              if (caseId != null && caseId.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Case ID: $caseId',
                  style: VineTheme.labelMediumFont(
                    color: VineTheme.secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'What is restricted right now',
          style: VineTheme.titleMediumFont(),
        ),
        const SizedBox(height: 12),
        ...const [
          _RestrictionLine('Posting and publishing are paused'),
          _RestrictionLine('Comments, likes, reposts, and follows are paused'),
          _RestrictionLine('Starting or replying to regular messages is paused'),
          _RestrictionLine('Support and your moderation message remain available'),
        ],
        const SizedBox(height: 24),
        _InfoCard(
          title: infoCard.title,
          body: infoCard.body,
        ),
        const SizedBox(height: 24),
        if (primaryAction != null) ...[
          DivineButton(
            label: primaryAction.label,
            expanded: true,
            onPressed: () => primaryAction.onPressed(context),
          ),
          const SizedBox(height: 12),
        ],
        DivineButton(
          label: 'Open Support Center',
          leadingIcon: DivineIconName.headphones,
          expanded: true,
          onPressed: () => context.push(SupportCenterScreen.path),
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: 'Open Moderation Message',
          type: DivineButtonType.secondary,
          leadingIcon: DivineIconName.chatCircle,
          expanded: true,
          onPressed: reviewCase?.moderationConversationPubkey == null
              ? null
              : () => _openModerationConversation(context, ref, reviewCase!),
        ),
        const SizedBox(height: 12),
        DivineButton(
          label: 'Check Again',
          type: DivineButtonType.ghost,
          expanded: true,
          onPressed: () => ref.invalidate(currentMinorAccountReviewStatusProvider),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => ref.read(authServiceProvider).signOut(),
          child: Text(
            'Log out',
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
        ),
      ],
    );
  }

  void _openModerationConversation(
    BuildContext context,
    WidgetRef ref,
    MinorReviewCase reviewCase,
  ) {
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;
    final moderationPubkey = reviewCase.moderationConversationPubkey;
    if (currentPubkey == null || moderationPubkey == null) {
      return;
    }

    final conversationId =
        reviewCase.moderationConversationId ??
        DmRepository.computeConversationId([currentPubkey, moderationPubkey]);

    context.push(
      ConversationPage.pathForId(conversationId),
      extra: [moderationPubkey],
    );
  }

  _MinorReviewInfoCardCopy _infoCardForCase(
    MinorReviewCase? reviewCase,
    String supportEmail,
  ) {
    if (reviewCase == null) {
      return const _MinorReviewInfoCardCopy(
        title: 'Next step',
        body:
            'Open the support center or your moderation message if you need help with this review.',
      );
    }

    if (reviewCase.isAwaitingModeratorDecision) {
      return const _MinorReviewInfoCardCopy(
        title: 'Review in progress',
        body:
            'We have what we need for now. Our team is reviewing this case before restoring normal account access.',
      );
    }

    if (reviewCase.isUnder13Path) {
      return _MinorReviewInfoCardCopy(
        title: 'Under-13 accounts',
        body:
            'If this account belongs to someone under 13, a parent or guardian must email $supportEmail and include the case ID.',
      );
    }

    return const _MinorReviewInfoCardCopy(
      title: 'Next step',
      body:
          'If this account belongs to someone 13 to 15, use the moderation message or support path to follow the parental consent instructions.',
    );
  }

  _MinorReviewPrimaryAction? _primaryAction(MinorReviewCase? reviewCase) {
    if (reviewCase == null || reviewCase.isAwaitingModeratorDecision) {
      return null;
    }

    if (!reviewCase.needsUserAction) {
      return const _MinorReviewPrimaryAction(
        label: 'Open Support Center',
        onPressed: _openSupportCenter,
      );
    }

    return _MinorReviewPrimaryAction(
      label: reviewCase.isUnder13Path
          ? 'Parent Support Instructions'
          : 'Continue',
      onPressed: (context) => _continueToNextStep(context, reviewCase),
    );
  }

  static void _openSupportCenter(BuildContext context) {
    context.push(SupportCenterScreen.path);
  }

  void _continueToNextStep(
    BuildContext context,
    MinorReviewCase reviewCase,
  ) {
    if (reviewCase.isUnder13Path) {
      context.push(MinorAccountReviewUnder13SupportScreen.path);
      return;
    }

    switch (reviewCase.allowedResolution) {
      case MinorReviewResolutionType.parentVideoOrEmail:
        context.push(MinorAccountReviewParentContactScreen.path);
      case MinorReviewResolutionType.supportEmailOnly:
        context.push(MinorAccountReviewUnder13SupportScreen.path);
      case MinorReviewResolutionType.supportReviewOnly:
      case MinorReviewResolutionType.unknown:
        context.push(SupportCenterScreen.path);
    }
  }
}

class _MinorReviewInfoCardCopy {
  const _MinorReviewInfoCardCopy({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class _MinorReviewPrimaryAction {
  const _MinorReviewPrimaryAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final void Function(BuildContext context) onPressed;
}

class _RestrictionLine extends StatelessWidget {
  const _RestrictionLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.remove_circle_outline, size: 16, color: VineTheme.vineGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VineTheme.titleMediumFont()),
          const SizedBox(height: 8),
          Text(
            body,
            style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'We could not load your account review status.',
            style: VineTheme.titleMediumFont(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '$error',
            style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          DivineButton(label: 'Try Again', expanded: true, onPressed: onRetry),
        ],
      ),
    );
  }
}

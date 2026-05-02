// ABOUTME: Badge dashboard for reviewing NIP-58 awards and issued badge status.
// ABOUTME: Offers accept/reject actions plus a bridge into badges.divine.video.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/badges/badges_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/services/badges/badge_repository.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Shows the current user's Nostr badge dashboard.
class BadgesScreen extends ConsumerWidget {
  /// Route name used by GoRouter.
  static const routeName = 'badges';

  /// Route path used by GoRouter.
  static const path = '/badges';

  /// Creates the badges screen.
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(badgeRepositoryProvider);
    return BlocProvider(
      key: ObjectKey(repository),
      create: (_) => BadgesCubit(repository: repository)..load(),
      child: const _BadgesView(),
    );
  }
}

class _BadgesView extends StatelessWidget {
  const _BadgesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.badgesTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      backgroundColor: VineTheme.backgroundColor,
      body: BlocBuilder<BadgesCubit, BadgesState>(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => context.read<BadgesCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BadgesIntro(state: state),
                        const SizedBox(height: 16),
                        if (state.status == BadgesStatus.loading)
                          const _BadgesLoadingCard()
                        else if (state.status == BadgesStatus.error &&
                            state.awarded.isEmpty &&
                            state.issued.isEmpty)
                          const _BadgesErrorCard()
                        else ...[
                          _AwardedBadgesSection(state: state),
                          const SizedBox(height: 20),
                          _IssuedBadgesSection(issued: state.issued),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BadgesIntro extends StatelessWidget {
  const _BadgesIntro({required this.state});

  final BadgesState state;

  @override
  Widget build(BuildContext context) {
    final errorMessage = switch ((state.actionStatus, state.status)) {
      (BadgeActionStatus.error, _) => context.l10n.badgesUpdateError,
      (_, BadgesStatus.error) => context.l10n.badgesLoadError,
      _ => null,
    };
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.badgesIntroTitle,
            style: VineTheme.titleLargeFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.badgesIntroBody,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: VineTheme.bodySmallFont(color: VineTheme.error),
            ),
          ],
          const SizedBox(height: 16),
          DivineButton(
            label: context.l10n.badgesOpenApp,
            leadingIcon: DivineIconName.arrowUpRight,
            onPressed: () {
              final app = _divineBadgesApp();
              context.push(NostrAppSandboxScreen.pathForAppId(app.id));
            },
          ),
        ],
      ),
    );
  }
}

class _AwardedBadgesSection extends StatelessWidget {
  const _AwardedBadgesSection({required this.state});

  final BadgesState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(context.l10n.badgesAwardedSectionTitle),
        if (state.awarded.isEmpty)
          _EmptyPanel(
            title: context.l10n.badgesAwardedEmptyTitle,
            subtitle: context.l10n.badgesAwardedEmptySubtitle,
          )
        else
          for (final award in state.awarded) ...[
            _AwardedBadgeCard(award: award, actionStatus: state.actionStatus),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _AwardedBadgeCard extends StatelessWidget {
  const _AwardedBadgeCard({required this.award, required this.actionStatus});

  final BadgeAwardViewData award;
  final BadgeActionStatus actionStatus;

  bool get _isBusy =>
      actionStatus == BadgeActionStatus.accepting ||
      actionStatus == BadgeActionStatus.removing ||
      actionStatus == BadgeActionStatus.hiding;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BadgesCubit>();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BadgeMedallion(imageUrl: award.imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      award.displayName,
                      style: VineTheme.titleMediumFont(
                        color: VineTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusPill(
                      label: award.isAccepted
                          ? context.l10n.badgesStatusAccepted
                          : context.l10n.badgesStatusNotAccepted,
                      accepted: award.isAccepted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (award.definition?.description != null) ...[
            const SizedBox(height: 12),
            Text(
              award.definition!.description!,
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (award.isAccepted)
                DivineButton(
                  label: context.l10n.badgesActionRemove,
                  type: DivineButtonType.secondary,
                  size: DivineButtonSize.small,
                  isLoading: actionStatus == BadgeActionStatus.removing,
                  onPressed: _isBusy ? null : () => cubit.removeAward(award),
                )
              else ...[
                DivineButton(
                  label: context.l10n.badgesActionAccept,
                  size: DivineButtonSize.small,
                  isLoading: actionStatus == BadgeActionStatus.accepting,
                  onPressed: _isBusy ? null : () => cubit.acceptAward(award),
                ),
                DivineButton(
                  label: context.l10n.badgesActionReject,
                  type: DivineButtonType.secondary,
                  size: DivineButtonSize.small,
                  isLoading: actionStatus == BadgeActionStatus.hiding,
                  onPressed: _isBusy ? null : () => cubit.hideAward(award),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _IssuedBadgesSection extends StatelessWidget {
  const _IssuedBadgesSection({required this.issued});

  final List<IssuedBadgeViewData> issued;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(context.l10n.badgesIssuedSectionTitle),
        if (issued.isEmpty)
          _EmptyPanel(
            title: context.l10n.badgesIssuedEmptyTitle,
            subtitle: context.l10n.badgesIssuedEmptySubtitle,
          )
        else
          for (final badge in issued) ...[
            _IssuedBadgeCard(badge: badge),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _IssuedBadgeCard extends StatelessWidget {
  const _IssuedBadgeCard({required this.badge});

  final IssuedBadgeViewData badge;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            badge.definition?.name ??
                _definitionNameFromCoordinate(badge.award.definitionCoordinate),
            style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
          ),
          const SizedBox(height: 12),
          if (badge.recipients.isEmpty)
            Text(
              context.l10n.badgesIssuedNoRecipients,
              style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
            )
          else
            for (final recipient in badge.recipients) ...[
              _RecipientStatusRow(recipient: recipient),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _RecipientStatusRow extends StatelessWidget {
  const _RecipientStatusRow({required this.recipient});

  final IssuedBadgeRecipientViewData recipient;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            recipient.pubkey,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        _StatusPill(
          label: recipient.isAccepted
              ? context.l10n.badgesRecipientAcceptedStatus
              : context.l10n.badgesRecipientWaitingStatus,
          accepted: recipient.isAccepted,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        label,
        style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VineTheme.outlineMuted),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: VineTheme.titleSmallFont()),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _BadgesLoadingCard extends StatelessWidget {
  const _BadgesLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(child: Center(child: CircularProgressIndicator()));
  }
}

class _BadgesErrorCard extends StatelessWidget {
  const _BadgesErrorCard();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.badgesLoadError, style: VineTheme.titleSmallFont()),
          const SizedBox(height: 12),
          DivineButton(
            label: context.l10n.commonRetry,
            onPressed: () => context.read<BadgesCubit>().load(),
          ),
        ],
      ),
    );
  }
}

class _BadgeMedallion extends StatelessWidget {
  const _BadgeMedallion({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: VineTheme.vineGreen,
      ),
      child: Center(
        child: Text(
          'B',
          style: VineTheme.titleMediumFont(color: VineTheme.primaryDarkGreen),
        ),
      ),
    );

    return SizedBox(
      width: 56,
      height: 56,
      child: imageUrl == null || imageUrl!.isEmpty
          ? fallback
          : ClipOval(
              child: VineCachedImage(
                imageUrl: imageUrl!,
                errorWidget: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.accepted});

  final String label;
  final bool accepted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accepted
            ? VineTheme.vineGreen.withValues(alpha: 0.14)
            : VineTheme.accentYellowBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accepted ? VineTheme.vineGreen : VineTheme.accentYellow,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: VineTheme.labelSmallFont(
            color: accepted ? VineTheme.vineGreen : VineTheme.accentYellow,
          ),
        ),
      ),
    );
  }
}

NostrAppDirectoryEntry _divineBadgesApp() {
  return preloadedNostrApps.where((app) => app.slug == 'badges').single;
}

String _definitionNameFromCoordinate(String coordinate) {
  final parts = coordinate.split(':');
  if (parts.length < 3) return coordinate;
  return parts.sublist(2).join(':');
}

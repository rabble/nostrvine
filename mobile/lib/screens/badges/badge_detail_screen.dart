// ABOUTME: Badge detail page: artwork, description, awardees, and the owner's
// ABOUTME: award/edit actions plus accept or remove for the viewer's own award.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/badges/badge_detail_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/badges/badge_award_screen.dart';
import 'package:openvine/screens/badges/badge_delete_confirmation_sheet.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';
import 'package:openvine/screens/badges/widgets/badge_recipient_row.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/user_profile_tile.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:share_plus/share_plus.dart';

/// Shows one badge, its awardees, and the actions available on it.
class BadgeDetailScreen extends ConsumerWidget {
  /// Route name used by GoRouter.
  static const routeName = 'badgeDetail';

  /// Route path used by GoRouter.
  static const path = '/badges/b/:naddr';

  /// Path that opens the detail page for [coordinate].
  static String pathFor(BadgeCoordinate coordinate) =>
      '/badges/b/${coordinate.toNaddr()}';

  /// Creates the badge detail screen.
  const BadgeDetailScreen({required this.coordinate, super.key});

  /// Address of the badge being shown.
  final BadgeCoordinate coordinate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(badgeRepositoryProvider);
    return BlocProvider(
      key: ValueKey((repository, coordinate)),
      create: (_) =>
          BadgeDetailCubit(repository: repository, coordinate: coordinate)
            ..load(),
      child: const BadgeDetailView(),
    );
  }
}

/// Body of [BadgeDetailScreen].
class BadgeDetailView extends StatelessWidget {
  /// Creates the badge detail view.
  @visibleForTesting
  const BadgeDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<BadgeDetailCubit, BadgeDetailState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus,
      listener: (context, state) {
        // Nothing left to render once the badge is gone.
        if (state.actionStatus == BadgeDetailActionStatus.deleted) {
          context.pop(true);
        }
      },
      builder: (context, state) {
        final detail = state.detail;
        final definition = detail?.definition;
        return Scaffold(
          appBar: DiVineAppBar(
            title: definition?.name ?? l10n.badgeDetailTitle,
            showBackButton: true,
            onBackPressed: context.pop,
            actions: [
              DiVineAppBarAction(
                icon: SvgIconSource(DivineIconName.shareNetwork.assetPath),
                tooltip: l10n.badgeDetailShareAction,
                semanticLabel: l10n.badgeDetailShareAction,
                onPressed: () => _share(context, state.coordinate),
              ),
              if (detail?.isOwner ?? false) ...[
                DiVineAppBarAction(
                  icon: SvgIconSource(DivineIconName.pencilSimple.assetPath),
                  tooltip: l10n.badgeDetailEditAction,
                  semanticLabel: l10n.badgeDetailEditAction,
                  onPressed: () => _openEditor(context, state.coordinate),
                ),
                DiVineAppBarAction(
                  icon: SvgIconSource(DivineIconName.trashSimple.assetPath),
                  tooltip: l10n.badgeDetailDeleteAction,
                  semanticLabel: l10n.badgeDetailDeleteAction,
                  iconColor: VineTheme.error,
                  onPressed: state.isBusy ? null : () => _delete(context),
                ),
              ],
            ],
          ),
          backgroundColor: context.vineColors.background,
          body: switch (state.status) {
            BadgeDetailStatus.initial ||
            BadgeDetailStatus.loading => const Center(
              child: BrandedLoadingIndicator(size: 60),
            ),
            BadgeDetailStatus.failure => _DetailMessage(
              message: l10n.badgeDetailLoadError,
              onRetry: () => context.read<BadgeDetailCubit>().load(),
            ),
            BadgeDetailStatus.loaded => _BadgeDetailBody(state: state),
          },
        );
      },
    );
  }

  static Future<void> _share(
    BuildContext context,
    BadgeCoordinate coordinate,
  ) async {
    final message = context.l10n.badgeDetailShareMessage(
      'https://badges.divine.video/b/${coordinate.toNaddr()}',
    );
    await SharePlus.instance.share(ShareParams(text: message));
  }

  static Future<void> _delete(BuildContext context) async {
    final cubit = context.read<BadgeDetailCubit>();
    final confirmed = await showBadgeDeleteConfirmation(context);
    if (confirmed ?? false) await cubit.deleteBadge();
  }

  static Future<void> _openEditor(
    BuildContext context,
    BadgeCoordinate coordinate,
  ) async {
    final cubit = context.read<BadgeDetailCubit>();
    await context.push<bool>(BadgeEditorScreen.editPathFor(coordinate));
    await cubit.refresh();
  }
}

class _BadgeDetailBody extends StatelessWidget {
  const _BadgeDetailBody({required this.state});

  final BadgeDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = state.detail!;
    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () => context.read<BadgeDetailCubit>().refresh(),
      // Constrains and centres the viewport itself; a sliver has no
      // max-width equivalent.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  32 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: [
                          _BadgeHero(
                            detail: detail,
                            coordinate: state.coordinate,
                          ),
                          if (state.isMissing)
                            Text(
                              l10n.badgeDetailMissing,
                              style: VineTheme.bodySmallFont(
                                color: context.vineColors.onSurfaceVariant,
                              ),
                            ),
                          if (state.actionStatus ==
                              BadgeDetailActionStatus.failure)
                            Text(
                              l10n.badgeDetailActionError,
                              style: VineTheme.bodySmallFont(
                                color: VineTheme.error,
                              ),
                            ),
                          _BadgeActions(state: state),
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(
                              l10n.badgeDetailRecipientsTitle,
                              style: VineTheme.titleSmallFont(
                                color: context.vineColors.primaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (detail.recipients.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.badgeDetailNoRecipients,
                            style: VineTheme.bodySmallFont(
                              color: context.vineColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      // Lazily built: a popular badge can carry a long
                      // awardee list, and every row resolves a profile.
                      SliverList.builder(
                        itemCount: detail.recipients.length,
                        itemBuilder: (context, index) => BadgeRecipientRow(
                          pubkey: detail.recipients[index].pubkey,
                          isAccepted: detail.recipients[index].isAccepted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeHero extends StatelessWidget {
  const _BadgeHero({required this.detail, required this.coordinate});

  final BadgeDetailData detail;
  final BadgeCoordinate coordinate;

  @override
  Widget build(BuildContext context) {
    final definition = detail.definition;
    final imageUrl =
        definition?.imageUrl ??
        (definition?.thumbnails.isNotEmpty ?? false
            ? definition!.thumbnails.first
            : null);
    return Column(
      spacing: 14,
      children: [
        _BadgeArtwork(imageUrl: imageUrl),
        Text(
          definition?.name ?? coordinate.identifier,
          textAlign: TextAlign.center,
          style: VineTheme.titleLargeFont(color: context.vineColors.onSurface),
        ),
        if (definition?.description?.isNotEmpty ?? false)
          Text(
            definition!.description!,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.badgeDetailMadeBy,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            UserProfileTile(
              pubkey: coordinate.pubkey,
              showFollowButton: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _BadgeArtwork extends StatelessWidget {
  const _BadgeArtwork({required this.imageUrl});

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
          style: VineTheme.titleLargeFont(color: VineTheme.primaryDarkGreen),
        ),
      ),
    );

    return SizedBox(
      width: 132,
      height: 132,
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

class _BadgeActions extends StatelessWidget {
  const _BadgeActions({required this.state});

  final BadgeDetailState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BadgeDetailCubit>();
    final detail = state.detail!;
    final viewerAward = detail.viewerAward;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        if (detail.isOwner)
          DivineButton(
            label: l10n.badgeDetailAwardAction,
            leadingIcon: DivineIconName.userPlus,
            isLoading: state.actionStatus == BadgeDetailActionStatus.awarding,
            onPressed: state.isBusy
                ? null
                : () => _openAwardFlow(context, state.coordinate),
          ),
        if (viewerAward != null)
          if (viewerAward.isAccepted)
            DivineButton(
              label: l10n.badgesActionRemove,
              type: DivineButtonType.secondary,
              isLoading: state.actionStatus == BadgeDetailActionStatus.removing,
              onPressed: state.isBusy ? null : cubit.removeAward,
            )
          else
            DivineButton(
              label: l10n.badgesActionAccept,
              isLoading:
                  state.actionStatus == BadgeDetailActionStatus.accepting,
              onPressed: state.isBusy ? null : cubit.acceptAward,
            ),
      ],
    );
  }

  static Future<void> _openAwardFlow(
    BuildContext context,
    BadgeCoordinate coordinate,
  ) async {
    final cubit = context.read<BadgeDetailCubit>();
    await context.push<bool>(BadgeAwardScreen.pathFor(coordinate));
    await cubit.refresh();
  }
}

class _DetailMessage extends StatelessWidget {
  const _DetailMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
            DivineButton(label: context.l10n.commonRetry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

// ABOUTME: Badge dashboard with Awarded / Created / Issued tabs over the
// ABOUTME: user's NIP-58 badges, plus the entry point for making a new one.

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/badges/badges_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/badges/badge_editor_screen.dart';
import 'package:openvine/screens/badges/widgets/badge_recipient_row.dart';
import 'package:openvine/screens/badges/widgets/badge_status_pill.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Shows the current user's Nostr badge dashboard.
class BadgesScreen extends ConsumerWidget {
  /// Route name used by GoRouter.
  static const routeName = 'badges';

  /// Route path used by GoRouter.
  static const String path = RoutePaths.badges;

  /// Creates the badges screen.
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(badgeRepositoryProvider);
    return BlocProvider(
      key: ObjectKey(repository),
      create: (_) => BadgesCubit(repository: repository)..load(),
      child: const BadgesView(),
    );
  }
}

/// Tabbed body of [BadgesScreen].
class BadgesView extends StatefulWidget {
  /// Creates the badges view.
  @visibleForTesting
  const BadgesView({super.key});

  @override
  State<BadgesView> createState() => _BadgesViewState();
}

class _BadgesViewState extends State<BadgesView>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin<BadgesView> {
  @override
  int get tabCount => 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: DiVineAppBar(
        title: l10n.badgesTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
        actions: [
          DiVineAppBarAction(
            icon: SvgIconSource(DivineIconName.plus.assetPath),
            tooltip: l10n.badgesCreateAction,
            semanticLabel: l10n.badgesCreateAction,
            onPressed: () => _openAndRefresh(
              context,
              BadgeEditorScreen.createPath,
            ),
          ),
        ],
      ),
      backgroundColor: context.vineColors.background,
      body: Column(
        children: [
          _BadgesTabBar(controller: tabController),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: const [
                _AwardedTab(),
                _CreatedTab(),
                _IssuedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pushes [path] and reloads the dashboard once it pops.
///
/// Creating, editing, and awarding all change what the tabs show, and none of
/// them run through this screen's cubit.
Future<void> _openAndRefresh(BuildContext context, String path) async {
  final cubit = context.read<BadgesCubit>();
  await context.push<bool>(path);
  // The dashboard can be gone by the time the pushed route pops — a deep link
  // out of it, or a sign-out rebuilding the repository.
  if (cubit.isClosed) return;
  await cubit.refresh();
}

class _BadgesTabBar extends StatelessWidget {
  const _BadgesTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Material is required for the TabBar ink splash.
    return Material(
      color: VineTheme.transparent,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsetsDirectional.only(start: 16),
        indicatorColor: VineTheme.tabIndicatorGreen,
        indicatorWeight: 4,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: VineTheme.transparent,
        labelColor: context.vineColors.primaryText,
        unselectedLabelColor: context.vineColors.onSurfaceMuted,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        labelStyle: VineTheme.titleMediumFont(
          color: context.vineColors.primaryText,
        ),
        unselectedLabelStyle: VineTheme.titleMediumFont(
          color: context.vineColors.onSurfaceMuted,
        ),
        tabs: [
          Tab(text: l10n.badgesTabAwarded),
          Tab(text: l10n.badgesTabCreated),
          Tab(text: l10n.badgesTabIssued),
        ],
      ),
    );
  }
}

/// Shared scaffolding for a tab: pull to refresh, loading, and error states.
///
/// [builder] returns slivers rather than widgets so a tab can hand back a
/// lazily built list. The issued tab needs that: a popular badge can carry
/// thousands of recipients, and every recipient row resolves a profile.
class _BadgesTabBody extends StatelessWidget {
  const _BadgesTabBody({required this.builder});

  final List<Widget> Function(BuildContext context, BadgesState state) builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BadgesCubit, BadgesState>(
      builder: (context, state) {
        return RefreshIndicator(
          color: VineTheme.onPrimary,
          backgroundColor: VineTheme.vineGreen,
          onRefresh: () => context.read<BadgesCubit>().refresh(),
          // Constrains and centres the viewport itself; a sliver has no
          // max-width equivalent, and wrapping each one would repeat the
          // centring on every list.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        if (state.actionStatus == BadgeActionStatus.error)
                          SliverToBoxAdapter(
                            child: _ErrorNote(context.l10n.badgesUpdateError),
                          ),
                        if (state.status == BadgesStatus.loading)
                          const SliverToBoxAdapter(child: _BadgesLoadingCard())
                        else if (state.status == BadgesStatus.error)
                          const SliverToBoxAdapter(child: _BadgesErrorCard())
                        else
                          ...builder(context, state),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A sliver rendering one spaced card per item.
class _BadgeCardList extends StatelessWidget {
  const _BadgeCardList({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: itemBuilder(context, index),
      ),
    );
  }
}

class _AwardedTab extends StatelessWidget {
  const _AwardedTab();

  @override
  Widget build(BuildContext context) {
    return _BadgesTabBody(
      builder: (context, state) => [
        if (state.awarded.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyPanel(
              title: context.l10n.badgesAwardedEmptyTitle,
              subtitle: context.l10n.badgesAwardedEmptySubtitle,
            ),
          )
        else
          _BadgeCardList(
            itemCount: state.awarded.length,
            itemBuilder: (context, index) => _AwardedBadgeCard(
              award: state.awarded[index],
              actionStatus: state.actionStatus,
            ),
          ),
        if (state.hidden.isNotEmpty)
          SliverToBoxAdapter(child: _HiddenAwardsSection(hidden: state.hidden)),
      ],
    );
  }
}

class _CreatedTab extends StatelessWidget {
  const _CreatedTab();

  @override
  Widget build(BuildContext context) {
    return _BadgesTabBody(
      builder: (context, state) => [
        if (state.created.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyPanel(
              title: context.l10n.badgesCreatedEmptyTitle,
              subtitle: context.l10n.badgesCreatedEmptySubtitle,
            ),
          )
        else
          _BadgeCardList(
            itemCount: state.created.length,
            itemBuilder: (context, index) =>
                _CreatedBadgeCard(badge: state.created[index]),
          ),
      ],
    );
  }
}

class _IssuedTab extends StatefulWidget {
  const _IssuedTab();

  @override
  State<_IssuedTab> createState() => _IssuedTabState();
}

class _IssuedTabState extends State<_IssuedTab> {
  /// Coordinates of the badges whose recipient list is open.
  final _expanded = <String>{};

  void _toggle(String coordinate) {
    setState(() {
      if (!_expanded.remove(coordinate)) _expanded.add(coordinate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _BadgesTabBody(
      builder: (context, state) => [
        if (state.issued.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyPanel(
              title: context.l10n.badgesIssuedEmptyTitle,
              subtitle: context.l10n.badgesIssuedEmptySubtitle,
            ),
          )
        else
          for (final badge in state.issued)
            // One sliver group per badge rather than one flattened list, so
            // a badge's header and its recipients stay adjacent without the
            // index arithmetic a single delegate would need.
            SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: _IssuedBadgeCard(
                    badge: badge,
                    isExpanded: _expanded.contains(badge.coordinate),
                    onToggle: () => _toggle(badge.coordinate),
                  ),
                ),
                if (_expanded.contains(badge.coordinate))
                  SliverList.builder(
                    itemCount: badge.recipients.length,
                    itemBuilder: (context, index) => BadgeRecipientRow(
                      pubkey: badge.recipients[index].pubkey,
                      isAccepted: badge.recipients[index].isAccepted,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
            ),
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
    final coordinate = BadgeCoordinate.parse(award.definitionCoordinate);
    return _Panel(
      onTap: coordinate == null
          ? null
          : () => _openAndRefresh(
              context,
              BadgeDetailScreen.pathFor(coordinate),
            ),
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
                        color: context.vineColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    BadgeStatusPill(
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
          if (award.definition?.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(
              award.definition!.description!,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
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
                  onPressed: _isBusy
                      ? null
                      : () => _hideWithUndo(context, award),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Hides [award] and offers an immediate way back.
///
/// Rejecting is local and publishes nothing, so without an undo a mistap
/// would strand the badge until the issuer awarded it again.
Future<void> _hideWithUndo(
  BuildContext context,
  BadgeAwardViewData award,
) async {
  final cubit = context.read<BadgesCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;

  await cubit.hideAward(award);
  if (cubit.state.actionStatus != BadgeActionStatus.completed) return;

  messenger.showSnackBar(
    DivineSnackbarContainer.snackBar(
      l10n.badgesHiddenSnackbar,
      actionLabel: l10n.badgesHiddenSnackbarUndo,
      // The snackbar lives on the app-level messenger, so it outlives this
      // route; undoing into a closed cubit would throw.
      onActionPressed: () {
        if (!cubit.isClosed) cubit.unhideAward(award);
      },
    ),
  );
}

/// Collapsible list of awards the user dismissed, each restorable.
class _HiddenAwardsSection extends StatefulWidget {
  const _HiddenAwardsSection({required this.hidden});

  final List<BadgeAwardViewData> hidden;

  @override
  State<_HiddenAwardsSection> createState() => _HiddenAwardsSectionState();
}

class _HiddenAwardsSectionState extends State<_HiddenAwardsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                spacing: 6,
                children: [
                  DivineIcon(
                    icon: _expanded ? .caretDown : .caretRight,
                    size: 20,
                    color: context.vineColors.onSurfaceMuted,
                  ),
                  Text(
                    l10n.badgesHiddenSectionTitle(widget.hidden.length),
                    style: VineTheme.titleSmallFont(
                      color: context.vineColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final award in widget.hidden) ...[
            _HiddenAwardCard(award: award),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _HiddenAwardCard extends StatelessWidget {
  const _HiddenAwardCard({required this.award});

  final BadgeAwardViewData award;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        spacing: 14,
        children: [
          _BadgeMedallion(imageUrl: award.imageUrl),
          Expanded(
            child: Text(
              award.displayName,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.onSurface,
              ),
            ),
          ),
          DivineButton(
            label: context.l10n.badgesActionRestore,
            type: DivineButtonType.secondary,
            size: DivineButtonSize.small,
            onPressed: () => context.read<BadgesCubit>().unhideAward(award),
          ),
        ],
      ),
    );
  }
}

class _CreatedBadgeCard extends StatelessWidget {
  const _CreatedBadgeCard({required this.badge});

  final CreatedBadgeViewData badge;

  @override
  Widget build(BuildContext context) {
    final coordinate = BadgeCoordinate.parse(badge.coordinate);
    return _Panel(
      onTap: coordinate == null
          ? null
          : () => _openAndRefresh(
              context,
              BadgeDetailScreen.pathFor(coordinate),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BadgeMedallion(imageUrl: badge.imageUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.displayName,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.badgesCreatedAwardSummary(badge.recipientCount),
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header for one issued badge; the recipients themselves are a sibling
/// sliver so they only build once opened, and only as far as they scroll.
class _IssuedBadgeCard extends StatelessWidget {
  const _IssuedBadgeCard({
    required this.badge,
    required this.isExpanded,
    required this.onToggle,
  });

  final IssuedBadgeViewData badge;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final hasRecipients = badge.recipients.isNotEmpty;
    return _Panel(
      onTap: hasRecipients ? onToggle : null,
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(
                  badge.displayName,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
                Text(
                  hasRecipients
                      ? context.l10n.badgesCreatedAwardSummary(
                          badge.recipients.length,
                        )
                      : context.l10n.badgesIssuedNoRecipients,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (hasRecipients)
            DivineIcon(
              icon: isExpanded ? .caretDown : .caretRight,
              size: 20,
              color: context.vineColors.onSurfaceMuted,
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.vineColors.outlineMuted),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
    if (onTap == null) return panel;

    return Semantics(
      button: true,
      child: GestureDetector(onTap: onTap, child: panel),
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
        spacing: 6,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Text(
            subtitle,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message,
        style: VineTheme.bodySmallFont(color: VineTheme.error),
      ),
    );
  }
}

class _BadgesLoadingCard extends StatelessWidget {
  const _BadgesLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Center(child: BrandedLoadingIndicator(size: 60)),
    );
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
          Text(
            context.l10n.badgesLoadError,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
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

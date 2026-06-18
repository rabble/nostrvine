// ABOUTME: Explore "Lists" tab — discover/create lists plus the user's own,
// ABOUTME: people, and subscribed curated lists.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/list_card.dart';
import 'package:unified_logger/unified_logger.dart';

/// The Lists tab shown inside [ExploreScreen].
class ExploreListsTab extends ConsumerWidget {
  /// Creates the Lists tab.
  const ExploreListsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Load data but don't wait for everything - show UI progressively
    final allListsAsync = ref.watch(allListsProvider);

    // Always show the static UI elements immediately
    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        // Invalidate both providers to refresh
        ref.invalidate(userListsProvider);
        ref.invalidate(curatedListsProvider);
      },
      child: ListView(
        key: const Key('lists-tab-content'),
        children: [
          // Discover Lists button - ALWAYS VISIBLE
          Padding(
            padding: const EdgeInsets.all(16),
            child: DivineButton(
              leadingIcon: .search,
              label: context.l10n.exploreDiscoverLists,
              onPressed: () {
                Log.info(
                  'Tapped Discover Lists button',
                  category: LogCategory.ui,
                );
                // Stop any playing videos before navigating
                disposeAllVideoControllers(ref);
                context.push(DiscoverListsScreen.path);
              },
            ),
          ),

          // Create New List button - ALWAYS VISIBLE
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DivineButton(
              leadingIcon: .plus,
              label: context.l10n.listCreateNewList,
              onPressed: () {
                Log.info(
                  'Tapped Create New List button',
                  category: LogCategory.ui,
                );
                showDialog<void>(
                  context: context,
                  builder: (_) => const CreateListDialog(),
                );
              },
            ),
          ),

          // Help text - ALWAYS VISIBLE
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VineTheme.vineGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const DivineIcon(
                      icon: DivineIconName.info,
                      color: VineTheme.vineGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.exploreAboutLists,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.exploreAboutListsDescription,
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DivineIcon(
                      icon: DivineIconName.user,
                      color: VineTheme.vineGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.explorePeopleLists,
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.explorePeopleListsDescription,
                            style: const TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DivineIcon(
                      icon: DivineIconName.playlist,
                      color: VineTheme.vineGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.exploreVideoLists,
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.exploreVideoListsDescription,
                            style: const TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // MY LISTS and PEOPLE LISTS - Show immediately when data available
          allListsAsync.when(
            skipLoadingOnRefresh: true,
            data: (data) {
              final userLists = data.userLists;
              // Owned lists stay visible after publishing — filtering on a
              // null nostrEventId hid lists once they reached the relay.
              final service = ref
                  .read(curatedListsStateProvider.notifier)
                  .service;
              final myLists = service?.myLists ?? const <CuratedList>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // My Lists section
                  if (myLists.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const DivineIcon(
                            icon: DivineIconName.playlist,
                            color: VineTheme.vineGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.exploreMyLists,
                            style: const TextStyle(
                              color: VineTheme.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...myLists.map(
                      (curatedList) => CuratedListCard(
                        curatedList: curatedList,
                        onTap: () {
                          Log.info(
                            'Tapped my curated list: ${curatedList.name}',
                            category: LogCategory.ui,
                          );
                          // Stop any playing videos before navigating
                          disposeAllVideoControllers(ref);
                          context.push(
                            CuratedListFeedScreen.pathForId(curatedList.id),
                            extra: CuratedListRouteExtra(
                              listName: curatedList.name,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // People Lists section
                  if (userLists.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const DivineIcon(
                            icon: DivineIconName.user,
                            color: VineTheme.vineGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.explorePeopleLists,
                            style: const TextStyle(
                              color: VineTheme.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...userLists.map(
                      (userList) => UserListCard(
                        userList: userList,
                        onTap: () {
                          Log.info(
                            'Tapped user list: ${userList.name}',
                            category: LogCategory.ui,
                          );
                          // Stop any playing videos before navigating
                          disposeAllVideoControllers(ref);
                          context.push(
                            '/people-lists/'
                            '${Uri.encodeComponent(userList.id)}',
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: BrandedLoadingIndicator(size: 60)),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.exploreErrorLoadingLists(error),
                style: const TextStyle(color: VineTheme.likeRed),
              ),
            ),
          ),

          // SUBSCRIBED LISTS - Load separately with its own loading state
          const _SubscribedListsSection(),
        ],
      ),
    );
  }
}

/// Subscribed curated lists section with an independent loading state.
class _SubscribedListsSection extends ConsumerWidget {
  const _SubscribedListsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allListsAsync = ref.watch(allListsProvider);
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    // Wait for both to load subscribed lists
    if (!allListsAsync.hasValue || !serviceAsync.hasValue) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DivineIcon(
                  icon: DivineIconName.checks,
                  color: VineTheme.vineGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.exploreSubscribedLists,
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(child: BrandedLoadingIndicator(size: 60)),
          ],
        ),
      );
    }

    final allCuratedLists = allListsAsync.value!.curatedLists;

    // Filter subscribed lists
    final subscribedLists = allCuratedLists.where((list) {
      return service?.isSubscribedToList(list.id) ?? false;
    }).toList();

    if (subscribedLists.isEmpty) {
      // Don't show section if no subscribed lists
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.checks,
                color: VineTheme.vineGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.exploreSubscribedLists,
                style: const TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...subscribedLists.map(
          (curatedList) => CuratedListCard(
            curatedList: curatedList,
            onTap: () {
              Log.info(
                'Tapped subscribed list: ${curatedList.name}',
                category: LogCategory.ui,
              );
              // Stop any playing videos before navigating
              disposeAllVideoControllers(ref);
              context.push(
                CuratedListFeedScreen.pathForId(curatedList.id),
                extra: CuratedListRouteExtra(listName: curatedList.name),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

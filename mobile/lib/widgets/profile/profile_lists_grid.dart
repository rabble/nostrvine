// ABOUTME: Shows the current user's owned video lists on their profile.
// ABOUTME: Replaces the unreachable global-bookmarks surface with editable lists.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/list_card.dart';

/// Owned video-list surface for the current user's profile.
class ProfileListsGrid extends ConsumerWidget {
  const ProfileListsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(curatedListsStateProvider);

    return listsAsync.when(
      data: (_) {
        final lists =
            ref.read(curatedListsStateProvider.notifier).service?.myLists ??
            const <CuratedList>[];
        return _ProfileListsContent(lists: lists);
      },
      loading: () => const Center(child: BrandedLoadingIndicator(size: 60)),
      error: (_, _) => Center(
        child: Text(
          context.l10n.listErrorLoading,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _ProfileListsContent extends StatelessWidget {
  const _ProfileListsContent({required this.lists});

  final List<CuratedList> lists;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DivineButton(
            label: context.l10n.listCreateNewList,
            leadingIcon: DivineIconName.plus,
            expanded: true,
            onPressed: () => context.showVideoPausingDialog<void>(
              builder: (_) => const CreateListDialog(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (lists.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              context.l10n.profileListsEmpty,
              textAlign: TextAlign.center,
              style: VineTheme.bodyLargeFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          )
        else
          for (final list in lists)
            CuratedListCard(
              curatedList: list,
              showVisibility: true,
              onTap: () => context.push(
                CuratedListFeedScreen.pathForId(list.id),
                extra: CuratedListRouteExtra(listName: list.name),
              ),
            ),
      ],
    );
  }
}

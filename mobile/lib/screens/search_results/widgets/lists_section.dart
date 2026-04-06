// ABOUTME: Preview section for list search results in the "All" view.
// ABOUTME: Shows up to 3 curated list results with a "See all" header.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/widgets/list_card.dart';

/// Maximum number of list items shown in the preview.
const _maxListsPreview = 3;

/// Always-visible Lists section with a "Lists" header.
///
/// Returns a [SliverMainAxisGroup] so the header and content participate
/// natively in the parent [CustomScrollView]'s sliver protocol.
class ListsSection extends StatelessWidget {
  const ListsSection({this.onSeeAll, super.key});

  /// Called when the user taps the "See all" chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SectionHeader(title: 'Lists', onTap: onSeeAll),
        ),
        const SliverToBoxAdapter(child: _ListsContent()),
      ],
    );
  }
}

class _ListsContent extends StatelessWidget {
  const _ListsContent();

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (ListSearchBloc bloc) => bloc.state.status,
    );
    final results = context.select(
      (ListSearchBloc bloc) => bloc.state.results,
    );

    if ((status == .initial || status == .loading) && results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    if (results.isEmpty) return const SizedBox.shrink();

    final preview = results.take(_maxListsPreview).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final list in preview)
          CuratedListCard(
            curatedList: list,
            onTap: () => _navigateToCuratedList(context, list),
          ),
      ],
    );
  }

  void _navigateToCuratedList(BuildContext context, CuratedList list) {
    context.push(
      CuratedListFeedScreen.pathForId(list.id),
      extra: CuratedListRouteExtra(
        listName: list.name,
        videoIds: list.videoEventIds,
        authorPubkey: list.pubkey,
      ),
    );
  }
}

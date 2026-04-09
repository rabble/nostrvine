import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/search_user_tile.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';

/// Maximum number of user profiles shown in the People preview.
const _maxPeoplePreview = 3;

/// Always-visible People section with a "People" header.
///
/// Returns a [SliverMainAxisGroup] so the header and content participate
/// natively in the parent [CustomScrollView]'s sliver protocol.
class PeopleSection extends StatelessWidget {
  const PeopleSection({this.showAll = false, this.onSeeAll, super.key});

  /// When true, shows all results instead of a limited preview.
  final bool showAll;

  /// Called when the user taps the "See all" chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (UserSearchBloc bloc) => bloc.state.status,
    );
    final results = context.select(
      (UserSearchBloc bloc) => bloc.state.results,
    );

    // In the All tab, hide entire section when results are empty and loaded.
    if (!showAll && status == .success && results.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        if (!showAll)
          SliverToBoxAdapter(
            child: SectionHeader(title: 'People', onTap: onSeeAll),
          ),
        _PeopleContent(showAll: showAll),
      ],
    );
  }
}

class _PeopleContent extends StatelessWidget {
  const _PeopleContent({this.showAll = false});

  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (UserSearchBloc bloc) => bloc.state.status,
    );
    final results = context.select(
      (UserSearchBloc bloc) => bloc.state.results,
    );
    final query = context.select(
      (UserSearchBloc bloc) => bloc.state.query,
    );

    if ((status == .initial || status == .loading) && results.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        ),
      );
    }

    if (status == .failure) {
      return SearchSectionErrorState(
        onRetry: () => context.read<UserSearchBloc>().add(
          UserSearchQueryChanged(query),
        ),
      );
    }

    if (results.isEmpty) {
      if (showAll) return SearchSectionEmptyState(query: query);
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final profiles = showAll
        ? results
        : results.take(_maxPeoplePreview).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final profile in profiles)
              SearchUserTile(
                profile: profile,
                onTap: () => _navigateToProfile(context, profile),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context, UserProfile profile) {
    final npub = normalizeToNpub(profile.pubkey);
    if (npub != null) {
      context.push(OtherProfileScreen.pathForNpub(npub));
    }
  }
}

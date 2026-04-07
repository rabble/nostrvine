import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/widgets/search_tag_chip.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';

/// Maximum number of hashtag chips shown in the Tags preview.
const _maxTagsPreview = 6;

/// Always-visible Tags section with a "Tags" header.
///
/// Returns a [SliverMainAxisGroup] so the header and content participate
/// natively in the parent [CustomScrollView]'s sliver protocol.
class TagsSection extends StatelessWidget {
  const TagsSection({this.showAll = false, this.onSeeAll, super.key});

  /// When true, shows all results instead of a limited preview.
  final bool showAll;

  /// Called when the user taps the "See all" chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        if (!showAll)
          SliverToBoxAdapter(
            child: SectionHeader(title: 'Tags', onTap: onSeeAll),
          ),
        SliverToBoxAdapter(child: _TagsContent(showAll: showAll)),
      ],
    );
  }
}

class _TagsContent extends StatelessWidget {
  const _TagsContent({this.showAll = false});

  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (HashtagSearchBloc bloc) => bloc.state.status,
    );
    final results = context.select(
      (HashtagSearchBloc bloc) => bloc.state.results,
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

    final tags = showAll ? results : results.take(_maxTagsPreview).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in tags)
            SearchTagChip(
              tag: tag,
              onTap: () => context.push(HashtagScreenRouter.pathForTag(tag)),
            ),
        ],
      ),
    );
  }
}

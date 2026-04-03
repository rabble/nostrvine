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
  const TagsSection({this.onSeeAll, super.key});

  /// Called when the user taps the "See all" chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SectionHeader(title: 'Tags', onTap: onSeeAll),
        ),
        SliverToBoxAdapter(child: _TagsContent()),
      ],
    );
  }
}

class _TagsContent extends StatelessWidget {
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

    final tags = results.take(_maxTagsPreview).toList();

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

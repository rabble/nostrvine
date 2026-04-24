// ABOUTME: Own-profile tab listing locally followed hashtags (plan 1602).
// ABOUTME: Tap opens hashtag page (unfavorite there — same chip look as search).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/widgets/search_tag_chip.dart';
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';

/// Hashtags the user saved for quick nav (device-local), laid out like search Tags.
class ProfileFollowedHashtagsGrid extends ConsumerWidget {
  const ProfileFollowedHashtagsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(followedHashtagsRepositoryProvider);

    return StreamBuilder<List<String>>(
      stream: repo.profileSavedHashtagsStream,
      initialData: repo.profileSavedHashtags,
      builder: (context, snapshot) {
        final tags = snapshot.data ?? const <String>[];
        if (tags.isEmpty) {
          return ProfileTabEmptyState(
            title: context.l10n.profileNoFollowedTagsTitle,
            subtitle: context.l10n.profileNoFollowedTagsSubtitle,
          );
        }

        final sorted = List<String>.from(tags)..sort();

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in sorted)
                      SearchTagChip(
                        tag: normalizeHashtagLabel(label),
                        onTap: () => context.push(
                          HashtagScreenRouter.pathForTag(label),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ABOUTME: Own profile "Saved" tab — plan #1602: bookmarked Videos + Tags sub-filters
// ABOUTME: Replaces separate Saved grid-only tab and a dedicated # tab per Figma alignment

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/profile_followed_hashtags_grid.dart';
import 'package:openvine/widgets/profile/profile_saved_grid.dart';

/// Saved content for the current user: bookmarked videos and profile-saved
/// hashtags in one tab with [Videos] / [Tags] filters.
class ProfileOwnSavedTab extends StatefulWidget {
  const ProfileOwnSavedTab({super.key});

  @override
  State<ProfileOwnSavedTab> createState() => _ProfileOwnSavedTabState();
}

class _ProfileOwnSavedTabState extends State<ProfileOwnSavedTab> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: l10n.profileTabSavedSemantic,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: _SavedFilterChip(
                    label: l10n.profileSavedFilterVideos,
                    selected: _index == 0,
                    onSelected: () => setState(() => _index = 0),
                  ),
                ),
                Expanded(
                  child: _SavedFilterChip(
                    label: l10n.profileSavedFilterTags,
                    selected: _index == 1,
                    onSelected: () => setState(() => _index = 1),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Divider(
            height: 1,
            color: VineTheme.outlineVariant,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: const [
              ProfileSavedGrid(),
              ProfileFollowedHashtagsGrid(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SavedFilterChip extends StatelessWidget {
  const _SavedFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: VineTheme.vineGreen.withValues(alpha: 0.2),
      labelStyle: VineTheme.labelLargeFont(
        color: selected ? VineTheme.whiteText : VineTheme.onSurfaceMuted,
      ),
      side: BorderSide(
        color: selected ? VineTheme.vineGreen : VineTheme.outlineMuted,
      ),
    );
  }
}

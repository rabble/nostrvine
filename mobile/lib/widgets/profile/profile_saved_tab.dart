// ABOUTME: Own profile Saved tab — bookmarked videos and profile-saved hashtags.
// ABOUTME: Videos / Tags sub-filters; inactive filter is plain label, selected is pill.

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              spacing: 8,
              children: [
                _SavedSegmentTab(
                  label: l10n.profileSavedFilterVideos,
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _SavedSegmentTab(
                  label: l10n.profileSavedFilterTags,
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
              ],
            ),
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

/// One secondary Saved filter: label only when inactive; pill fill when active.
class _SavedSegmentTab extends StatelessWidget {
  const _SavedSegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double _pillRadius = 999;
  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 8,
  );

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // Active: vineGreen (same as SearchTagChip `#`). Inactive: onSurfaceMuted — same
      // token as unselected icons in [_ProfileTabBar] (Videos / Liked / …).
      style: selected
          // ? VineTheme.labelLargeFont(color: VineTheme.vineGreen)
          ? VineTheme.titleSmallFont(color: VineTheme.vineGreen)
          // : VineTheme.labelLargeFont(color: VineTheme.onSurfaceMuted),
          : VineTheme.titleSmallFont(color: VineTheme.onSurfaceMuted),
    );

    final padded = Padding(padding: _padding, child: text);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: VineTheme.transparent,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(VineTheme.transparent),
          borderRadius: BorderRadius.circular(_pillRadius),
          child: selected
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: VineTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(_pillRadius),
                  ),
                  child: padded,
                )
              : padded,
        ),
      ),
    );
  }
}

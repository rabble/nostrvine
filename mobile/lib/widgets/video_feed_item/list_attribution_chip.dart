// ABOUTME: Widget displaying curated list attribution chips on video feed items
// ABOUTME: Shows up to 2 tappable chips linking to source curated lists

import 'package:flutter/material.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Callback type for list tap events.
typedef ListTapCallback = void Function(String listId, String listName);

/// Widget that displays attribution chips showing which curated list(s) a video
/// is from. Each chip is tappable and navigates to the source list.
class ListAttributionChip extends StatelessWidget {
  /// Creates a ListAttributionChip widget.
  ///
  /// The [listIds] parameter specifies which lists to display attribution for.
  /// The [listLookup] function resolves list IDs to CuratedList objects.
  /// The optional [onListTap] callback is invoked when a chip is tapped.
  const ListAttributionChip({
    required this.listIds,
    required this.listLookup,
    this.onListTap,
    super.key,
  });

  /// Set of list IDs to display chips for.
  final Set<String> listIds;

  /// Function to look up a CuratedList by its ID.
  final CuratedList? Function(String listId) listLookup;

  /// Optional callback when a list chip is tapped.
  final ListTapCallback? onListTap;

  @override
  Widget build(BuildContext context) {
    if (listIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      children: listIds.take(2).map((listId) {
        final list = listLookup(listId);
        final listName = list?.name ?? 'List';

        return GestureDetector(
          onTap: () {
            onListTap?.call(listId, listName);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VineTheme.vineGreen.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.playlist_play,
                  size: 14,
                  color: VineTheme.vineGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  listName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: VineTheme.vineGreen,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

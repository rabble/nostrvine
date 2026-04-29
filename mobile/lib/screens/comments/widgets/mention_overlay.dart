// ABOUTME: Autocomplete overlay for @mentions in comment input
// ABOUTME: Shows user suggestions from comment participants

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Overlay widget showing mention suggestions above the comment input.
class MentionOverlay extends ConsumerWidget {
  const MentionOverlay({
    required this.suggestions,
    required this.onSelect,
    super.key,
  });

  /// List of mention suggestions to display.
  final List<MentionSuggestion> suggestions;

  /// Callback when a suggestion is selected. Returns (npub, displayName).
  final void Function(String npub, String displayName) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: VineTheme.backgroundColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            return _MentionSuggestionItem(
              suggestion: suggestions[index],
              onTap: () {
                final suggestion = suggestions[index];
                final npub = NostrKeyUtils.encodePubKey(suggestion.pubkey);
                // Use displayName from BLoC search results, fall back to
                // cached profile lookup, then npub as last resort
                final cachedProfile = ref
                    .read(userProfileReactiveProvider(suggestion.pubkey))
                    .value;
                final displayName =
                    suggestion.displayName ??
                    cachedProfile?.displayName ??
                    cachedProfile?.name ??
                    npub;
                onSelect(npub, displayName);
              },
            );
          },
        ),
      ),
    );
  }
}

class _MentionSuggestionItem extends ConsumerWidget {
  const _MentionSuggestionItem({required this.suggestion, required this.onTap});

  final MentionSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(suggestion.pubkey))
        .value;

    final displayName = profile?.displayName ?? profile?.name;
    final npub = NostrKeyUtils.encodePubKey(suggestion.pubkey);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 10,
          children: [
            UserAvatar(
              size: 32,
              imageUrl: profile?.picture,
              placeholderSeed: suggestion.pubkey,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayName != null)
                    Text(
                      displayName,
                      style: VineTheme.labelLargeFont(
                        color: VineTheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    npub,
                    style: VineTheme.bodySmallFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // UI truncation only
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

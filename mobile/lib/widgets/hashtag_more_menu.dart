// ABOUTME: Bottom sheet for saving a hashtag to profile / following feed (#1602).
// ABOUTME: Shared by hashtag feed screen and inline video description hashtag actions.
// ABOUTME: Header layout matches `docs/images/tag_menu.png` (icon + two-line block).

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:followed_hashtags_repository/followed_hashtags_repository.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';

/// Hashtag block: rounded purple `#` mark + [tag name] and optional video count
/// (see `docs/images/tag_menu.png` in the divine repo).
class HashtagActionMenuHeader extends StatelessWidget {
  const HashtagActionMenuHeader({
    required this.hashtag,
    this.videoCount,
    super.key,
  });

  final String hashtag;
  final int? videoCount;

  /// Horizontal inset subtracted from screen width when constraining the header
  /// row (sheet side margins + gutter vs. edge-to-edge title art in mocks).
  static const double horizontalInsetTotal = 64;

  static const double _iconSize = 48;
  static const double _iconRadius = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = normalizeHashtagLabel(hashtag);
    final maxW = MediaQuery.sizeOf(context).width - horizontalInsetTotal;
    final tileColor = hashtagTileBackgroundForLabel(hashtag);
    return DefaultTextStyle(
      style: const TextStyle(),
      child: Semantics(
        label: body.isEmpty
            ? l10n.hashtagOptionsMoreTooltip
            : (videoCount != null
                  ? '$body. ${l10n.hashtagMenuVideoCount(videoCount!)}'
                  : body),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: _iconSize,
                height: _iconSize,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(_iconRadius),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#',
                  style: VineTheme.titleLargeFont(
                    color: VineTheme.primaryDarkGreen,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Text(
                      body.isEmpty ? '…' : body,
                      style: VineTheme.titleLargeFont(
                        color: VineTheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (videoCount != null)
                      Text(
                        l10n.hashtagMenuVideoCount(videoCount!),
                        style: VineTheme.bodySmallFont(
                          color: VineTheme.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the hashtag options menu (save to profile, add to following feed when enabled).
void showHashtagMoreMenu(
  BuildContext context,
  WidgetRef ref, {
  required String hashtag,
  int? videoCount,
}) {
  final repo = ref.read(followedHashtagsRepositoryProvider);
  final isProfileSaved = repo.hasProfileSavedHashtag(hashtag);
  final isInFollowingFeed = repo.hasFollowingFeedHashtag(hashtag);
  final l10n = context.l10n;
  final options = <VineBottomSheetActionData>[
    VineBottomSheetActionData(
      iconPath: isProfileSaved
          ? DivineIconName.bookmarkSimple.assetPath
          : DivineIconName.bookmarkPlus.assetPath,
      label: isProfileSaved
          ? l10n.hashtagOptionRemoveFromProfile
          : l10n.hashtagOptionSaveToProfile,
      isDestructive: isProfileSaved,
      onTap: () async {
        final r = ref.read(followedHashtagsRepositoryProvider);
        final wasSaved = r.hasProfileSavedHashtag(hashtag);
        if (wasSaved) {
          await r.removeProfileSavedHashtag(hashtag);
        } else {
          await r.addProfileSavedHashtag(hashtag);
        }
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            wasSaved
                ? l10n.hashtagRemovedFromProfileSnackbar
                : l10n.hashtagSavedToProfileSnackbar,
          ),
        );
      },
    ),
  ];

  if (FollowedHashtagsRepository.separateFollowingFeedHashtagsEnabled) {
    options.add(
      VineBottomSheetActionData(
        iconPath: DivineIconName.list.assetPath,
        label: isInFollowingFeed
            ? l10n.hashtagOptionRemoveFromFollowingFeed
            : l10n.hashtagOptionAddToFollowingFeed,
        isDestructive: isInFollowingFeed,
        onTap: () async {
          final wasIn = isInFollowingFeed;
          final r = ref.read(followedHashtagsRepositoryProvider);
          if (wasIn) {
            await r.removeFollowingFeedHashtag(hashtag);
          } else {
            await r.addFollowingFeedHashtag(hashtag);
          }
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              wasIn
                  ? l10n.hashtagRemovedFromFollowingFeedSnackbar
                  : l10n.hashtagAddedToFollowingFeedSnackbar,
            ),
          );
        },
      ),
    );
  }

  unawaited(
    VineBottomSheetActionMenu.show(
      context: context,
      title: HashtagActionMenuHeader(
        hashtag: hashtag,
        videoCount: videoCount,
      ),
      options: options,
    ),
  );
}

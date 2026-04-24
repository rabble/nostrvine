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
import 'package:openvine/utils/hashtag_chip_accent.dart';

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

  static const double _iconSize = 48;
  static const double _iconRadius = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = normalizeHashtagLabel(hashtag);
    final maxW = MediaQuery.sizeOf(context).width - 64;
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      body.isEmpty ? '…' : body,
                      style: VineTheme.titleLargeFont(
                        color: VineTheme.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (videoCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.hashtagMenuVideoCount(videoCount!),
                        style: VineTheme.bodySmallFont(
                          color: VineTheme.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
      onTap: () {
        final wasSaved = isProfileSaved;
        unawaited(() async {
          final r = ref.read(followedHashtagsRepositoryProvider);
          if (wasSaved) {
            await r.removeProfileSavedHashtag(hashtag);
          } else {
            await r.addProfileSavedHashtag(hashtag);
          }
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              padding: EdgeInsets.zero,
              backgroundColor: VineTheme.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 68),
              duration: const Duration(seconds: 2),
              content: DivineSnackbarContainer(
                label: wasSaved
                    ? l10n.hashtagRemovedFromProfileSnackbar
                    : l10n.hashtagSavedToProfileSnackbar,
              ),
            ),
          );
        }());
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
        onTap: () {
          final wasIn = isInFollowingFeed;
          unawaited(() async {
            final r = ref.read(followedHashtagsRepositoryProvider);
            if (wasIn) {
              await r.removeFollowingFeedHashtag(hashtag);
            } else {
              await r.addFollowingFeedHashtag(hashtag);
            }
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                padding: EdgeInsets.zero,
                backgroundColor: VineTheme.transparent,
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 68),
                duration: const Duration(seconds: 2),
                content: DivineSnackbarContainer(
                  label: wasIn
                      ? l10n.hashtagRemovedFromFollowingFeedSnackbar
                      : l10n.hashtagAddedToFollowingFeedSnackbar,
                ),
              ),
            );
          }());
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

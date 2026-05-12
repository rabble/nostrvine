// ABOUTME: Bottom sheet for saving a hashtag to profile / home feed list (#1602).
// ABOUTME: Shared by hashtag feed screen and inline video description hashtag actions.
// ABOUTME: Header follows Chardot visual review (#1602): chip + headline + count.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';

/// Hashtag block: rounded accent `#` tile + tag label and optional video count
/// (visual review #1602 / design QA — token alignment with `VineTheme`).
class HashtagActionMenuHeader extends StatelessWidget {
  const HashtagActionMenuHeader({
    required this.hashtag,
    this.videoCount,
    super.key,
  });

  final String hashtag;
  final int? videoCount;

  static const double _iconSize = 40;
  static const double _iconRadius = 10;
  static const double _gapChipToText = 16;
  static const double _titleToCountGap = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final body = normalizeHashtagLabel(hashtag);
    final tileColor = hashtagTileBackgroundForLabel(hashtag);
    final semanticTag = body.isEmpty ? '' : formatHashtagForDisplay(body);
    return SizedBox(
      width: double.infinity,
      child: DefaultTextStyle(
        style: const TextStyle(),
        child: Semantics(
          label: body.isEmpty
              ? l10n.hashtagOptionsMoreTooltip
              : (videoCount != null
                    ? '$semanticTag. ${l10n.hashtagMenuVideoCount(videoCount!)}'
                    : semanticTag),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: _gapChipToText,
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
                  style: VineTheme.titleLargeFont(),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: _titleToCountGap,
                  children: [
                    Text(
                      body.isEmpty ? '…' : body,
                      style: VineTheme.headlineSmallFont(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (videoCount != null)
                      Text(
                        l10n.hashtagMenuVideoCount(videoCount!),
                        style: VineTheme.bodySmallFont(
                          color: VineTheme.onSurfaceMuted55,
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

/// Opens the hashtag options menu (save to profile, add to home feed list when enabled).
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

  if (repo.separateFollowingFeedHashtagsEnabled) {
    options.add(
      VineBottomSheetActionData(
        iconPath: DivineIconName.house.assetPath,
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

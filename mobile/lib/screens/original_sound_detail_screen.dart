// ABOUTME: Detail screen for "original sound" on videos without shared audio.
// ABOUTME: Shows creator info and the source video, no "Use Sound" button.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

/// Screen showing "original sound" details for videos without shared audio.
///
/// Displays the creator's profile info and a note that the audio
/// hasn't been shared for reuse. No "Use Sound" or "Preview" buttons.
class OriginalSoundDetailScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'originalSound';

  /// Base path for original sound routes.
  static const basePath = '/original-sound';

  /// Path pattern for this route.
  static const path = '/original-sound/:pubkey';

  /// Build path for a specific creator pubkey.
  static String pathForPubkey(String pubkey) => '$basePath/$pubkey';

  /// Creates an OriginalSoundDetailScreen.
  const OriginalSoundDetailScreen({
    required this.creatorPubkey,
    this.sourceVideo,
    super.key,
  });

  /// The pubkey of the video creator.
  final String creatorPubkey;

  /// The source video, if available (passed via route extra).
  final VideoEvent? sourceVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorProfile = ref
        .watch(userProfileReactiveProvider(creatorPubkey))
        .value;
    final creatorName =
        creatorProfile?.bestDisplayName ??
        sourceVideo?.authorName ??
        UserProfile.generatedNameFor(creatorPubkey);

    Log.info(
      'Showing original sound detail for creator: $creatorPubkey',
      name: 'OriginalSoundDetailScreen',
      category: LogCategory.ui,
    );

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: 'Sound',
        showBackButton: true,
        onBackPressed: context.pop,
        backgroundColor: VineTheme.cardBackground,
      ),
      body: Semantics(
        identifier: 'original_sound_detail_screen',
        container: true,
        child: Column(
          children: [
            // Sound header
            _OriginalSoundHeader(
              creatorName: creatorName,
              creatorAvatarUrl: creatorProfile?.picture,
              videoTitle: sourceVideo?.title,
              videoThumbnailUrl: sourceVideo?.thumbnailUrl,
            ),

            const Divider(color: VineTheme.cardBackground, height: 1),

            // Info section
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_off_outlined,
                        size: 64,
                        color: VineTheme.lightText.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Original sound',
                        style: TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Audio from this video is not available '
                        'separately.',
                        style: TextStyle(
                          color: VineTheme.onSurfaceMuted,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header section for original sound detail.
class _OriginalSoundHeader extends StatelessWidget {
  const _OriginalSoundHeader({
    required this.creatorName,
    this.creatorAvatarUrl,
    this.videoTitle,
    this.videoThumbnailUrl,
  });

  final String creatorName;
  final String? creatorAvatarUrl;
  final String? videoTitle;
  final String? videoThumbnailUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: VineTheme.cardBackground,
      child: Row(
        children: [
          // Sound icon with thumbnail or placeholder
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: VineTheme.vineGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: videoThumbnailUrl != null
                ? VineCachedImage(
                    imageUrl: videoThumbnailUrl!,
                    errorWidget: (_, _, _) => const Icon(
                      Icons.music_note,
                      color: VineTheme.vineGreen,
                      size: 28,
                    ),
                  )
                : const Icon(
                    Icons.music_note,
                    color: VineTheme.vineGreen,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  'Original sound - $creatorName',
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (videoTitle != null && videoTitle!.isNotEmpty)
                  Text(
                    videoTitle!,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

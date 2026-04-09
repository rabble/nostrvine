// ABOUTME: Audio attribution row shown on every video in the feed.
// ABOUTME: Navigates to SoundDetailScreen (shared audio) or OriginalSoundDetailScreen.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';

/// A tappable row showing audio attribution on every video.
///
/// Two modes:
/// - **Explicit audio**: When [VideoEvent.hasAudioReference] is true, fetches
///   the Kind 1063 audio event and displays "♪ Sound name · creator".
///   Tapping navigates to [SoundDetailScreen].
/// - **Original sound**: When no audio reference exists, displays
///   "♪ Original sound - @creator" using the video author's profile.
///   Tapping navigates to [SoundDetailScreen] in view-only mode.
class AudioAttributionRow extends ConsumerWidget {
  /// Creates an AudioAttributionRow.
  const AudioAttributionRow({required this.video, super.key});

  /// The video event to display audio attribution for.
  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If video has an explicit audio reference, show the fetched audio info
    if (video.hasAudioReference && video.audioEventId != null) {
      return _ExplicitAudioAttribution(video: video);
    }

    // Otherwise show "Original sound - @creator"
    return _OriginalSoundAttribution(video: video);
  }
}

/// Displays attribution for a video with an explicit Kind 1063 audio reference.
class _ExplicitAudioAttribution extends ConsumerWidget {
  const _ExplicitAudioAttribution({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioAsync = ref.watch(soundByIdProvider(video.audioEventId!));

    return audioAsync.when(
      data: (audio) {
        if (audio == null) {
          Log.warning(
            'Audio event not found for video ${video.id} '
            '(audioEventId: ${video.audioEventId})',
            name: 'AudioAttributionRow',
            category: LogCategory.ui,
          );
          // Fall back to original sound display
          return _OriginalSoundAttribution(video: video);
        }

        return _AudioAttributionContent(audio: audio);
      },
      loading: () => const _AudioAttributionSkeleton(),
      error: (error, stack) {
        Log.error(
          'Failed to load audio for video ${video.id}: $error',
          name: 'AudioAttributionRow',
          category: LogCategory.ui,
        );
        // Fall back to original sound display on error
        return _OriginalSoundAttribution(video: video);
      },
    );
  }
}

/// Displays "Original sound - @creator" for videos without explicit audio.
class _OriginalSoundAttribution extends ConsumerWidget {
  const _OriginalSoundAttribution({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorProfile = ref
        .watch(userProfileReactiveProvider(video.pubkey))
        .value;
    final creatorName =
        creatorProfile?.bestDisplayName ??
        video.authorName ??
        UserProfile.generatedNameFor(video.pubkey);

    return GestureDetector(
      onTap: () => _navigateToOriginalSound(context),
      child: Semantics(
        identifier: 'audio_attribution_row_original',
        button: true,
        label:
            'Original sound by $creatorName. '
            'Tap to view sound details.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VineTheme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.music_note,
                size: 14,
                color: VineTheme.vineGreen,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Original sound - $creatorName',
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToOriginalSound(BuildContext context) {
    Log.info(
      'Navigating to original sound for video: ${video.id}',
      name: 'AudioAttributionRow',
      category: LogCategory.ui,
    );

    context.pushWithVideoPause(
      OriginalSoundDetailScreen.pathForPubkey(video.pubkey),
      extra: video,
    );
  }
}

/// The actual content showing audio attribution for an explicit audio event.
class _AudioAttributionContent extends ConsumerWidget {
  const _AudioAttributionContent({required this.audio});

  final AudioEvent audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundName = audio.title ?? 'Original sound';
    final String creatorName;

    if (audio.isBundled) {
      // For bundled sounds, use the source field (e.g. "ThePauny via Freesound")
      creatorName = audio.source ?? 'diVine';
    } else {
      // For Nostr sounds, fetch the creator's profile
      final creatorProfile = ref
          .watch(userProfileReactiveProvider(audio.pubkey))
          .value;
      creatorName =
          creatorProfile?.bestDisplayName ??
          UserProfile.defaultDisplayNameFor(audio.pubkey);
    }

    return GestureDetector(
      onTap: () => _navigateToSoundDetail(context, audio),
      child: Semantics(
        identifier: 'audio_attribution_row',
        button: true,
        label: 'Sound: $soundName by $creatorName. Tap to view sound details.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VineTheme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.music_note,
                size: 14,
                color: VineTheme.vineGreen,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$soundName · $creatorName',
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 14,
                color: VineTheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSoundDetail(BuildContext context, AudioEvent audio) {
    Log.info(
      'Navigating to sound detail: ${audio.id}',
      name: 'AudioAttributionRow',
      category: LogCategory.ui,
    );

    context.pushWithVideoPause(
      SoundDetailScreen.pathForId(audio.id),
      extra: audio,
    );
  }
}

/// Skeleton loading state for audio attribution.
class _AudioAttributionSkeleton extends StatelessWidget {
  const _AudioAttributionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note, size: 14, color: VineTheme.lightText),
          const SizedBox(width: 4),
          Container(
            width: 100,
            height: 12,
            decoration: BoxDecoration(
              color: VineTheme.lightText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

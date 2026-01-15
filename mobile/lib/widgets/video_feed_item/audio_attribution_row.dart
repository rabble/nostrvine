// ABOUTME: Audio attribution row widget for displaying sound info on video feed.
// ABOUTME: Shows sound name and creator with tap navigation to SoundDetailScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// A tappable row showing audio attribution when a video uses external audio.
///
/// Displays the sound name and creator info in the format:
/// "♪ Sound name · @creator"
///
/// Tapping navigates to [SoundDetailScreen] for that audio.
/// Shows nothing if the video has no audio reference or if audio is unavailable.
class AudioAttributionRow extends ConsumerWidget {
  /// Creates an AudioAttributionRow.
  ///
  /// [video] must have a non-null [VideoEvent.audioEventId] for this widget
  /// to display anything.
  const AudioAttributionRow({required this.video, super.key});

  /// The video event to display audio attribution for.
  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show if video has an audio reference
    if (!video.hasAudioReference || video.audioEventId == null) {
      return const SizedBox.shrink();
    }

    // Watch the audio event asynchronously
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
          return const SizedBox.shrink();
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
        return const SizedBox.shrink();
      },
    );
  }
}

/// The actual content showing audio attribution.
class _AudioAttributionContent extends ConsumerWidget {
  const _AudioAttributionContent({required this.audio});

  final AudioEvent audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the creator's profile
    final userProfileService = ref.watch(userProfileServiceProvider);
    final creatorProfile = userProfileService.getCachedProfile(audio.pubkey);

    // Trigger profile fetch if not cached
    if (creatorProfile == null &&
        !userProfileService.shouldSkipProfileFetch(audio.pubkey)) {
      Future.microtask(() {
        ref.read(userProfileProvider.notifier).fetchProfile(audio.pubkey);
      });
    }

    final creatorName =
        creatorProfile?.bestDisplayName ?? _formatPubkeyShort(audio.pubkey);
    final soundName = audio.title ?? 'Original sound';

    return GestureDetector(
      onTap: () => _navigateToSoundDetail(context, audio),
      child: Semantics(
        identifier: 'audio_attribution_row',
        button: true,
        label: 'Sound: $soundName by $creatorName. Tap to view sound details.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
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
                  '$soundName · @$creatorName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 4,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 14, color: Colors.white70),
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

    context.push('/sound/${audio.id}', extra: audio);
  }

  /// Format pubkey for display (short version with ellipsis in middle).
  String _formatPubkeyShort(String pubkey) {
    if (pubkey.length <= 12) return pubkey;
    return '${pubkey.substring(0, 6)}...${pubkey.substring(pubkey.length - 4)}';
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
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Container(
            width: 100,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

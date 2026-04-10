// ABOUTME: Audio attribution row widget for displaying sound info on video feed.
// ABOUTME: Shows shared sound name or "Original sound - @creator" with tap navigation.

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
import 'package:unified_logger/unified_logger.dart';

/// A tappable row showing audio attribution on every video in the feed.
///
/// Two display modes:
/// - **Shared audio**: `♪ Sound name · Creator` → taps to [SoundDetailScreen]
/// - **Original sound**: `♪ Original sound - @creator` → taps to
///   [OriginalSoundDetailScreen]
class AudioAttributionRow extends ConsumerWidget {
  /// Creates an AudioAttributionRow.
  const AudioAttributionRow({required this.video, super.key});

  /// The video event to display audio attribution for.
  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Videos without a shared audio event show "Original sound - @creator"
    if (!video.hasAudioReference || video.audioEventId == null) {
      return _OriginalSoundContent(video: video);
    }

    // Watch the shared audio event asynchronously
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
          // Fall back to original sound when the referenced audio is missing
          return _OriginalSoundContent(video: video);
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
        // Fall back to original sound on error
        return _OriginalSoundContent(video: video);
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

    return Semantics(
      identifier: 'audio_attribution_row',
      button: true,
      label: 'Sound: $soundName by $creatorName. Tap to view sound details.',
      child: GestureDetector(
        onTap: () => _navigateToSoundDetail(context, audio),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VineTheme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              const DivineIcon(
                icon: DivineIconName.musicNote,
                size: 14,
                color: VineTheme.vineGreen,
              ),
              Flexible(
                child: Text(
                  '$soundName · $creatorName',
                  style: VineTheme.labelMediumFont().copyWith(
                    shadows: [const Shadow(blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const DivineIcon(
                icon: DivineIconName.caretRight,
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

/// Original sound attribution for videos without a shared audio event.
///
/// Shows `♪ Original sound - @creator_display_name` and navigates to
/// [OriginalSoundDetailScreen] on tap.
class _OriginalSoundContent extends ConsumerWidget {
  const _OriginalSoundContent({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorProfile = ref
        .watch(userProfileReactiveProvider(video.pubkey))
        .value;
    final creatorName =
        creatorProfile?.bestDisplayName ??
        UserProfile.defaultDisplayNameFor(video.pubkey);

    final label = 'Original sound - $creatorName';

    return Semantics(
      identifier: 'audio_attribution_row',
      button: true,
      label: 'Sound: $label. Tap to view sound details.',
      child: GestureDetector(
        onTap: () {
          Log.info(
            'Navigating to original sound detail: pubkey=${video.pubkey}',
            name: 'AudioAttributionRow',
            category: LogCategory.ui,
          );
          context.pushWithVideoPause(
            OriginalSoundDetailScreen.pathForPubkey(video.pubkey),
            extra: video,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VineTheme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              const DivineIcon(
                icon: DivineIconName.musicNote,
                size: 14,
                color: VineTheme.vineGreen,
              ),
              Flexible(
                child: Text(
                  label,
                  style: VineTheme.labelMediumFont().copyWith(
                    shadows: [const Shadow(blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const DivineIcon(
                icon: DivineIconName.caretRight,
                size: 14,
                color: VineTheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
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
          const DivineIcon(
            icon: DivineIconName.musicNote,
            size: 14,
            color: VineTheme.lightText,
          ),
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

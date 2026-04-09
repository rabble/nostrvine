// ABOUTME: Sounds section for the metadata expanded sheet.
// ABOUTME: Shows audio info for all videos - shared audio or "Original sound".

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_section.dart';

/// Sounds section showing audio attribution in the metadata sheet.
///
/// Two modes:
/// - **Shared audio**: Video has a Kind 1063 audio event — shows sound name,
///   artist, and tapping navigates to [SoundDetailScreen].
/// - **Original sound**: No audio event — shows "Original sound - @creator"
///   as display-only info.
class MetadataSoundsSection extends ConsumerWidget {
  const MetadataSoundsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If video has an explicit audio reference, show the fetched audio info
    if (video.hasAudioReference && video.audioEventId != null) {
      return _SharedAudioSection(video: video);
    }

    // Otherwise show "Original sound - @creator"
    return _OriginalSoundSection(video: video);
  }
}

/// Section for videos with an explicit Kind 1063 audio reference.
class _SharedAudioSection extends ConsumerWidget {
  const _SharedAudioSection({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioAsync = ref.watch(soundByIdProvider(video.audioEventId!));

    return audioAsync.when(
      data: (audio) {
        if (audio == null) {
          // Audio event not found, fall back to original sound display
          return _OriginalSoundSection(video: video);
        }
        return MetadataSection(
          label: 'Sounds',
          child: _SoundListItem(audio: audio),
        );
      },
      loading: () => const MetadataSection(
        label: 'Sounds',
        child: _SoundSkeleton(),
      ),
      error: (error, stack) {
        Log.error(
          'Failed to load audio for metadata sheet: $error',
          name: 'MetadataSoundsSection',
          category: LogCategory.ui,
        );
        return _OriginalSoundSection(video: video);
      },
    );
  }
}

/// Section showing "Original sound - @creator" for videos without shared audio.
///
/// Tapping creates a synthetic [AudioEvent] from the video's audio track
/// and navigates to [SoundDetailScreen] where the user can preview and
/// select the sound for recording.
class _OriginalSoundSection extends ConsumerWidget {
  const _OriginalSoundSection({required this.video});

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

    return MetadataSection(
      label: 'Sounds',
      child: Semantics(
        button: true,
        label: 'Original sound by $creatorName. Tap to use this sound.',
        child: GestureDetector(
          onTap: () => _navigateToSoundDetail(context, creatorName),
          child: Row(
            spacing: 16,
            children: [
              const DivineIcon(
                icon: DivineIconName.waveform,
                color: VineTheme.onSurfaceVariant,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original sound',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.titleMediumFont(),
                    ),
                    Text(
                      creatorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: VineTheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSoundDetail(BuildContext context, String creatorName) {
    Log.info(
      'Navigating to original sound detail for video: ${video.id}',
      name: 'MetadataSoundsSection',
      category: LogCategory.ui,
    );

    final syntheticAudio = AudioEvent.fromVideoOriginalSound(
      video,
      creatorName: creatorName,
    );

    // Dismiss the sheet first, then navigate from the root navigator context.
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero).then((_) {
      if (!hostContext.mounted) return;
      hostContext.pushWithVideoPause(
        SoundDetailScreen.pathForId(syntheticAudio.id),
        extra: <String, dynamic>{
          'sound': syntheticAudio,
          'sourceVideo': video,
        },
      );
    });
  }
}

/// A list item showing audio cover, title, and artist name.
/// Tapping navigates to the [SoundDetailScreen].
class _SoundListItem extends ConsumerWidget {
  const _SoundListItem({required this.audio});

  final AudioEvent audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundName = audio.title ?? 'Original sound';
    final String creatorName;

    if (audio.isBundled) {
      creatorName = audio.source ?? 'diVine';
    } else {
      final creatorProfile = ref
          .watch(userProfileReactiveProvider(audio.pubkey))
          .value;
      creatorName =
          creatorProfile?.bestDisplayName ??
          UserProfile.defaultDisplayNameFor(audio.pubkey);
    }

    return Semantics(
      button: true,
      label: 'Sound: $soundName by $creatorName. Tap to view details.',
      child: GestureDetector(
        onTap: () => _navigateToSoundDetail(context),
        child: Row(
          spacing: 16,
          children: [
            const DivineIcon(
              icon: DivineIconName.waveform,
              color: VineTheme.onSurfaceVariant,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    soundName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.titleMediumFont(),
                  ),
                  Text(
                    creatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodyMediumFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: VineTheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSoundDetail(BuildContext context) {
    Log.info(
      'Navigating to sound detail from metadata: ${audio.id}',
      name: 'MetadataSoundsSection',
      category: LogCategory.ui,
    );

    // Dismiss the sheet first, then navigate from the root navigator context.
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    Future<void>.delayed(Duration.zero).then((_) {
      if (!hostContext.mounted) return;
      hostContext.pushWithVideoPause(SoundDetailScreen.pathForId(audio.id));
    });
  }
}

/// Loading skeleton for the sound list item.
class _SoundSkeleton extends StatelessWidget {
  const _SoundSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 16,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: VineTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 80,
                height: 14,
                decoration: BoxDecoration(
                  color: VineTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

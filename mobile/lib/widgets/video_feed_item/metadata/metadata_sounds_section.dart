// ABOUTME: Sounds section for the metadata expanded sheet.
// ABOUTME: Shows audio cover art, title, and artist in a list-item layout.

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

/// Sounds section showing audio attribution with cover art.
///
/// Returns [SizedBox.shrink] when the video has no audio reference.
///
/// Layout matches Figma node `I11251:226991;9071:175984`: a list item
/// with 40px rounded album cover, title, and artist subtitle.
class MetadataSoundsSection extends ConsumerWidget {
  const MetadataSoundsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!video.hasAudioReference || video.audioEventId == null) {
      return const SizedBox.shrink();
    }

    final audioAsync = ref.watch(soundByIdProvider(video.audioEventId!));

    return audioAsync.when(
      data: (audio) {
        if (audio == null) return const SizedBox.shrink();
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
        return const SizedBox.shrink();
      },
    );
  }
}

/// A list item showing audio cover, title, and artist name.
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
    // GoRouter extensions can throw when called from inside a modal bottom
    // sheet (the router is not in the modal's widget tree).
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    // Defer navigation to the next microtask so the pop animation
    // completes and the modal route is fully removed before pushing.
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

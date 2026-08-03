// ABOUTME: Rich vertical card for a private device-local saved sound record.
// ABOUTME: Shows source context, waveform, and private organization at a glance.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/widgets/stereo_waveform_painter.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

class SavedSoundCard extends StatelessWidget {
  const SavedSoundCard({
    required this.sound,
    required this.onPreview,
    required this.onEdit,
    required this.onRemove,
    super.key,
  });

  final SavedSound sound;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  String _displayTitle(BuildContext context) =>
      sound.personalLabel ??
      sound.sourceContext?.title ??
      sound.audio.title ??
      context.l10n.savedSoundFallbackTitle;

  @override
  Widget build(BuildContext context) {
    final source = sound.sourceContext;
    final duration = sound.audio.formattedDuration;
    final displayTitle = _displayTitle(context);
    return Semantics(
      label: duration.isEmpty ? displayTitle : '$displayTitle, $duration',
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SavedSoundThumbnail(url: source?.thumbnailUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SavedSoundText(
                      displayTitle: displayTitle,
                      sound: sound,
                    ),
                  ),
                ],
              ),
              if (sound.waveformSamples.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SavedSoundWaveform(sound: sound),
              ],
              if (sound.personalHashtags.isNotEmpty ||
                  sound.catalogTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SavedSoundTags(sound: sound),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DivineIconButton(
                    key: const Key('saved_sound_preview'),
                    icon: DivineIconName.play,
                    semanticLabel: context.l10n.savedSoundPreviewAction,
                    size: DivineIconButtonSize.small,
                    type: DivineIconButtonType.secondary,
                    onPressed: onPreview,
                  ),
                  const SizedBox(width: 8),
                  DivineIconButton(
                    key: const Key('saved_sound_edit'),
                    icon: DivineIconName.pencilSimple,
                    semanticLabel: context.l10n.savedSoundEditAction,
                    size: DivineIconButtonSize.small,
                    type: DivineIconButtonType.secondary,
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 8),
                  DivineIconButton(
                    key: const Key('saved_sound_remove'),
                    icon: DivineIconName.trash,
                    semanticLabel: context.l10n.savedSoundRemoveAction,
                    size: DivineIconButtonSize.small,
                    type: DivineIconButtonType.error,
                    onPressed: onRemove,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedSoundThumbnail extends StatelessWidget {
  const _SavedSoundThumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const _SavedSoundThumbnailFallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: VineCachedImage(
        key: const Key('saved_sound_thumbnail'),
        imageUrl: imageUrl,
        width: 88,
        height: 88,
        memCacheWidth: 176,
        memCacheHeight: 176,
        placeholder: (_, _) => const _SavedSoundThumbnailFallback(),
        errorWidget: (_, _, _) => const _SavedSoundThumbnailFallback(),
      ),
    );
  }
}

class _SavedSoundThumbnailFallback extends StatelessWidget {
  const _SavedSoundThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      key: Key('saved_sound_thumbnail_fallback'),
      dimension: 88,
      child: ColoredBox(
        color: VineTheme.surfaceContainer,
        child: Center(
          child: DivineIcon(
            icon: DivineIconName.waveform,
            color: VineTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SavedSoundText extends StatelessWidget {
  const _SavedSoundText({required this.displayTitle, required this.sound});

  final String displayTitle;
  final SavedSound sound;

  @override
  Widget build(BuildContext context) {
    final source = sound.sourceContext;
    final secondaryTitle = sound.personalLabel == null
        ? null
        : source?.title ?? sound.audio.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
        ),
        if (secondaryTitle != null && secondaryTitle != displayTitle)
          Text(
            secondaryTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.bodyMediumFont(
              color: VineTheme.onSurfaceVariant,
            ),
          ),
        if (source?.creatorName case final creator?)
          Text(
            context.l10n.soundCreatorBy(creator),
            style: VineTheme.labelMediumFont(color: VineTheme.vineGreen),
          ),
        if (source?.description case final description?)
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.bodySmallFont(
              color: VineTheme.onSurfaceVariant,
            ),
          ),
        if (source?.transcript case final transcript?) ...[
          const SizedBox(height: 4),
          Text(
            transcript,
            key: const Key('saved_sound_transcript'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.bodySmallFont(
              color: VineTheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SavedSoundWaveform extends StatelessWidget {
  const _SavedSoundWaveform({required this.sound});

  final SavedSound sound;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(
      milliseconds: ((sound.audio.duration ?? 1) * 1000).round(),
    );
    return SizedBox(
      key: const Key('saved_sound_waveform'),
      height: 44,
      width: double.infinity,
      child: CustomPaint(
        painter: StereoWaveformPainter(
          leftChannel: Float32List.fromList(sound.waveformSamples),
          progress: 0,
          activeColor: VineTheme.onSurfaceVariant,
          inactiveColor: VineTheme.onSurfaceVariant,
          audioDuration: duration,
          maxDuration: duration,
        ),
      ),
    );
  }
}

class _SavedSoundTags extends StatelessWidget {
  const _SavedSoundTags({required this.sound});

  final SavedSound sound;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final hashtag in sound.personalHashtags)
          _SavedSoundTag(label: '#$hashtag', isPersonal: true),
        for (final tag in sound.catalogTags)
          _SavedSoundTag(label: tag, isPersonal: false),
      ],
    );
  }
}

class _SavedSoundTag extends StatelessWidget {
  const _SavedSoundTag({required this.label, required this.isPersonal});

  final String label;
  final bool isPersonal;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPersonal
            ? VineTheme.vineGreen.withValues(alpha: 0.16)
            : VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: VineTheme.labelSmallFont(
            color: isPersonal
                ? VineTheme.vineGreen
                : VineTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

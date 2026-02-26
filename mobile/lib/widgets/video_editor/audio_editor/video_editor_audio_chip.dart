import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/providers/sounds_providers.dart';

class VideoEditorAudioChip extends ConsumerWidget {
  const VideoEditorAudioChip({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSound = ref.watch(selectedSoundProvider);
    final hasSelectedSound = selectedSound != null;

    return InkWell(
      onTap: onTap,
      radius: 16,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const .fromLTRB(16, 8, 8, 8),
        decoration: ShapeDecoration(
          color: VineTheme.scrim15,
          shape: RoundedRectangleBorder(borderRadius: .circular(16)),
        ),
        child: Row(
          mainAxisSize: .min,
          mainAxisAlignment: .center,
          children: [
            const Row(
              spacing: 1.5,
              children: [
                _AudioBar(height: 7),
                _AudioBar(height: 16),
                _AudioBar(height: 13),
                _AudioBar(height: 7),
                _AudioBar(height: 10),
              ],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: !hasSelectedSound
                  ? Text(
                      // TODO(l10n): Replace with context.l10n when localization is added.
                      'Add audio',
                      textAlign: .center,
                      style: VineTheme.titleMediumFont(fontSize: 16),
                    )
                  : Text.rich(
                      TextSpan(
                        style: VineTheme.labelLargeFont(),
                        children: [
                          // TODO(l10n): Replace with context.l10n when localization is added.
                          TextSpan(text: selectedSound.title ?? 'Untitled'),
                          if (selectedSound.source != null) ...[
                            const TextSpan(text: ' ∙ '),
                            TextSpan(
                              text: selectedSound.source,
                              style: VineTheme.bodyMediumFont(),
                            ),
                          ],
                        ],
                      ),
                      textAlign: .center,
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
            ),
            if (hasSelectedSound)
              GestureDetector(
                onTap: () => ref.read(selectedSoundProvider.notifier).clear(),
                child: Container(
                  padding: const .all(8),
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(borderRadius: .circular(16)),
                  ),
                  child: SvgPicture.asset(
                    'assets/icon/close.svg',
                    width: 16,
                    height: 16,
                    colorFilter: const .mode(VineTheme.whiteText, .srcIn),
                  ),
                ),
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _AudioBar extends StatelessWidget {
  const _AudioBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 2,
      height: height,
      decoration: BoxDecoration(
        color: VineTheme.whiteText,
        borderRadius: .circular(2),
      ),
    );
  }
}

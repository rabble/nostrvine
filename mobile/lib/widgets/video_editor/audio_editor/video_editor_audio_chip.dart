import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/providers/sounds_providers.dart';

class VideoEditorAudioChip extends ConsumerWidget {
  const VideoEditorAudioChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSound = ref.watch(selectedSoundProvider);
    final hasSelectedSound = selectedSound != null;

    return InkWell(
      onTap: onTap,
      radius: 16,
      child: Container(
        constraints: BoxConstraints(minHeight: 48),
        padding: const .symmetric(horizontal: 16, vertical: 8),
        decoration: ShapeDecoration(
          color: VineTheme.scrim15,
          shape: RoundedRectangleBorder(borderRadius: .circular(16)),
        ),
        child: Row(
          mainAxisSize: .min,
          mainAxisAlignment: .center,
          crossAxisAlignment: .center,
          spacing: 8,
          children: [
            Row(
              spacing: 1.5,
              children: [
                const _AudioBar(height: 7),
                const _AudioBar(height: 16),
                const _AudioBar(height: 13),
                const _AudioBar(height: 7),
                const _AudioBar(height: 10),
              ],
            ),
            Flexible(
              child: !hasSelectedSound
                  ? Text(
                      'Add audio',
                      textAlign: TextAlign.center,
                      style: VineTheme.titleMediumFont(fontSize: 16),
                    )
                  : Text.rich(
                      TextSpan(
                        style: VineTheme.labelLargeFont(),
                        children: [
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
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            if (hasSelectedSound)
              GestureDetector(
                onTap: () => ref.read(selectedSoundProvider.notifier).clear(),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(borderRadius: .circular(16)),
                  ),
                  child: SvgPicture.asset(
                    'assets/icon/close.svg',
                    width: 16,
                    height: 16,
                    colorFilter: .mode(VineTheme.whiteText, .srcIn),
                  ),
                ),
              ),
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
      duration: Duration(milliseconds: 150),
      width: 2,
      height: height,
      decoration: BoxDecoration(
        color: VineTheme.whiteText,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class VideoEditorAudioChip extends StatelessWidget {
  const VideoEditorAudioChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      radius: 16,
      child: Container(
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
              child: Text(
                'Add audio',
                textAlign: TextAlign.center,
                style: VineTheme.titleMediumFont(
                  fontSize: 16,
                  color: Color(0xFFF9F7F6),
                ),
                maxLines: 1,
                overflow: .ellipsis,
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
        color: const Color(0xFFF9F7F6),
        borderRadius: .circular(2),
      ),
    );
  }
}

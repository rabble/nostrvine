import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class VideoEditorAudioChip extends StatelessWidget {
  const VideoEditorAudioChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            width: 24,
            height: 24,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(),
            child: Stack(),
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
    );
  }
}

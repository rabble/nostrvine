// ABOUTME: Report action button for video feed overlay.
// ABOUTME: Displays flag icon with label, shows report dialog.

import 'package:flutter/material.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';
import 'package:openvine/widgets/share_video_menu.dart';

/// Report action button with label for video overlay.
///
/// Shows a flag icon that opens the report content dialog.
class ReportActionButton extends StatelessWidget {
  const ReportActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'report_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'Report video',
          child: CircularIconButton(
            onPressed: () {
              Log.info(
                '🚩 Report button tapped for ${video.id}',
                name: 'ReportActionButton',
                category: LogCategory.ui,
              );
              showDialog<void>(
                context: context,
                builder: (context) => ReportContentDialog(video: video),
              );
            },
            icon: const Icon(
              Icons.flag_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 0),
        const Text(
          'Report',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(offset: Offset(0, 0), blurRadius: 6, color: Colors.black),
              Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
            ],
          ),
        ),
      ],
    );
  }
}

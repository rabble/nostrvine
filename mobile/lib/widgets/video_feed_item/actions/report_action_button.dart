// ABOUTME: Report action button for video feed overlay.
// ABOUTME: Displays flag icon with label, shows report dialog.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';
import 'package:openvine/widgets/report_content_dialog.dart';

/// Report action button with label for video overlay.
///
/// Shows a flag icon that opens the report content dialog.
/// Video playback is automatically paused while the dialog is open via
/// [showVideoPausingDialog] and the overlay visibility provider.
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
              context.showVideoPausingDialog<void>(
                builder: (context) => ReportContentDialog(video: video),
              );
            },
            icon: Icon(
              Icons.flag_outlined,
              color: VineTheme.whiteText,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }
}

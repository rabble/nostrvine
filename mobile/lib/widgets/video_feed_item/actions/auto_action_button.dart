import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

/// Feed-scoped Auto advance rail control.
class AutoActionButton extends StatelessWidget {
  const AutoActionButton({
    required this.isEnabled,
    required this.onPressed,
    super.key,
  });

  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: DivineIconName.queue,
      semanticIdentifier: 'auto_button',
      semanticLabel: isEnabled
          ? context.l10n.videoActionDisableAutoAdvance
          : context.l10n.videoActionEnableAutoAdvance,
      iconColor: isEnabled ? VineTheme.vineGreen : VineTheme.whiteText,
      caption: context.l10n.videoActionAutoLabel,
      onPressed: onPressed,
    );
  }
}

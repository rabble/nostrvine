import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum CenterPlaybackControlState {
  play,
  pause,
}

/// Shared Figma-matched center control used for transient play/pause states.
class CenterPlaybackControl extends StatelessWidget {
  const CenterPlaybackControl({
    required this.state,
    this.semanticsLabel,
    super.key,
  });

  final CenterPlaybackControlState state;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final iconAsset = switch (state) {
      CenterPlaybackControlState.play => DivineIconName.playFill.assetPath,
      CenterPlaybackControlState.pause => DivineIconName.pauseFill.assetPath,
    };

    Widget icon = SvgPicture.asset(
      iconAsset,
      width: 32,
      height: 32,
      colorFilter: const ColorFilter.mode(
        VineTheme.whiteText,
        BlendMode.srcIn,
      ),
    );

    if (semanticsLabel != null) {
      icon = Semantics(
        identifier: 'play_button',
        container: true,
        explicitChildNodes: true,
        label: semanticsLabel,
        child: icon,
      );
    }

    return Center(
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: BorderRadius.circular(24),
        ),
        child: icon,
      ),
    );
  }
}

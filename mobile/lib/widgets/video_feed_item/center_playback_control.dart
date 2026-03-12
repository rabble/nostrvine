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

  static const _buttonShadowColor = Color(0x1A000000);

  @override
  Widget build(BuildContext context) {
    final iconAsset = switch (state) {
      CenterPlaybackControlState.play =>
        'assets/icon/content-controls/play.svg',
      CenterPlaybackControlState.pause =>
        'assets/icon/content-controls/pause.svg',
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
        child: Center(child: icon),
      );
    } else {
      icon = Center(child: icon);
    }

    return Center(
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: BorderRadius.circular(24),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: _buttonShadowColor,
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
              BoxShadow(
                color: _buttonShadowColor,
                offset: Offset(0.4, 0.4),
                blurRadius: 0.6,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: icon,
          ),
        ),
      ),
    );
  }
}

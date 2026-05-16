// ABOUTME: Top-app-bar settings menu for the home video feed.
// ABOUTME: Renders the More icon button and the playback-controls popover
// ABOUTME: that toggles auto-advance, audio mute, and closed captions.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';

/// More icon button + playback-controls popover for feed surfaces.
///
/// Renders a 40 px scrim-15 [DivineIconButton] (48 px tap target). Used on
/// the home feed's top bar (as the trailing sibling of the feed-mode
/// selector) and on the fullscreen video screen (as a `customActions`
/// entry on its [DiVineAppBar]). Tapping opens a popover anchored 16 px
/// below the button's bottom-right corner with three scrim-toggled
/// controls: playback mode (auto-advance), audio mute, and closed captions.
///
/// The popover content is the shared [FeedPlaybackTogglesPill] widget, which
/// reads and writes app-wide state (`FeedAutoAdvanceCubit`,
/// `VideoVolumeCubit`, and the Riverpod `subtitleVisibilityProvider`) so the
/// popover does not need any props from the page — it works as a drop-in
/// child of any feed surface that provides those scopes.
class FeedSettingsMenu extends StatefulWidget {
  const FeedSettingsMenu({super.key});

  @override
  State<FeedSettingsMenu> createState() => _FeedSettingsMenuState();
}

class _FeedSettingsMenuState extends State<FeedSettingsMenu> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();

  /// Mirrors [_controller.isShowing] so the trigger button can rebuild via a
  /// [ValueListenableBuilder] without setState on the whole subtree.
  /// [OverlayPortalController] is not a [Listenable], so we drive this
  /// notifier from the toggle / close callbacks alongside the controller.
  final ValueNotifier<bool> _isShowing = ValueNotifier(false);

  @override
  void dispose() {
    _isShowing.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isShowing) {
      _controller.hide();
      _isShowing.value = false;
    } else {
      _controller.show();
      _isShowing.value = true;
    }
  }

  void _close() {
    if (!_controller.isShowing) return;
    _controller.hide();
    _isShowing.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (_) =>
            _FeedSettingsOverlay(link: _link, onClose: _close),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isShowing,
          builder: (context, isShowing, _) => DivineIconButton(
            icon: isShowing ? DivineIconName.x : DivineIconName.dotsThree,
            size: DivineIconButtonSize.small,
            type: DivineIconButtonType.ghostSecondary,
            semanticLabel: isShowing
                ? context.l10n.videoSettingsMenuClose
                : context.l10n.videoSettingsMenuOpen,
            onPressed: _toggle,
          ),
        ),
      ),
    );
  }
}

/// Overlay rendered while the popover is open: a full-screen tap catcher
/// that dismisses the popover, plus the popover itself anchored 16 px below
/// the trigger button's bottom-right corner.
class _FeedSettingsOverlay extends StatelessWidget {
  const _FeedSettingsOverlay({required this.link, required this.onClose});

  final LayerLink link;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Wrap the *entire* overlay in a [TextFieldTapRegion]. While the
    // popover is open, every tap inside it — the pill (toggling
    // mute / captions / ...), the empty backdrop (which fires
    // [onClose] to dismiss the popover), and the area behind the
    // popover's X-button trigger in the app bar that the backdrop
    // catcher overlays — is treated as part of the focused
    // TextField's tap-region group. That keeps the inline comment
    // composer's keyboard up while the user adjusts playback, and
    // lets them close the popover (via X or backdrop tap) without
    // also losing the keyboard.
    return TextFieldTapRegion(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
            ),
          ),
          CompositedTransformFollower(
            link: link,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 16),
            child: const Material(
              color: VineTheme.transparent,
              child: FeedPlaybackTogglesPill(),
            ),
          ),
        ],
      ),
    );
  }
}

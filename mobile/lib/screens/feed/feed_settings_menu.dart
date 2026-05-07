// ABOUTME: Top-app-bar settings menu for the home video feed.
// ABOUTME: Renders the More icon button and the playback-controls popover
// ABOUTME: that toggles auto-advance, audio mute, and closed captions.

import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';

/// More icon button + playback-controls popover for the home feed top bar.
///
/// Renders a 40 px scrim-15 [DivineIconButton] (48 px tap target) intended
/// to be placed as the trailing sibling of the feed-mode selector inside the
/// home feed's top-bar [Row]. Tapping opens a popover anchored 16 px below
/// the button's bottom-right corner with three scrim-toggled controls:
/// playback mode (auto-advance), audio mute, and closed captions.
///
/// All three toggles read and write app-wide state (`FeedAutoAdvanceCubit`,
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
    return Stack(
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
            child: _PlaybackSettingsPopover(),
          ),
        ),
      ],
    );
  }
}

/// The popover content: scrim-30 background, scrim-15 border, 4 px backdrop
/// blur, 24 px radius, with a single row of three scrim-toggled buttons.
class _PlaybackSettingsPopover extends ConsumerWidget {
  const _PlaybackSettingsPopover();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.scrim30,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: VineTheme.scrim15),
            boxShadow: const [
              BoxShadow(color: VineTheme.shadow25, blurRadius: 4),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                _PlaybackModeToggle(),
                _AudioToggle(),
                _CaptionsToggle(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Auto-advance ("playback mode") toggle. Active state means auto-advance is
/// on (play all). Inactive state means the current video loops indefinitely.
///
/// Hidden when the user has enabled reduced-motion at the OS level —
/// auto-advance is unavailable in that state, matching the previous
/// `AutoActionButton` rail control.
class _PlaybackModeToggle extends StatelessWidget {
  const _PlaybackModeToggle();

  @override
  Widget build(BuildContext context) {
    final autoAdvanceAvailable = !MediaQuery.disableAnimationsOf(context);
    if (!autoAdvanceAvailable) return const SizedBox.shrink();

    final enabled = context.select(
      (FeedAutoAdvanceCubit c) => c.state.enabled,
    );
    return _PopoverToggle(
      isOn: enabled,
      semanticLabel: enabled
          ? context.l10n.videoActionDisableAutoAdvance
          : context.l10n.videoActionEnableAutoAdvance,
      onTap: () {
        final cubit = context.read<FeedAutoAdvanceCubit>();
        cubit.toggle();
        if (!cubit.state.isEffectivelyActive) {
          cubit.clearPendingPaginationAdvance();
        }
        announceAutoAdvanceToggle(context, enabled: cubit.state.enabled);
      },
      child: DivineIcon(
        icon: enabled
            ? DivineIconName.playbackModeOn
            : DivineIconName.playbackModeOff,
        color: VineTheme.onSurface,
      ),
    );
  }
}

/// Audio mute toggle. Active state means audio is muted. Drives
/// [VideoVolumeCubit] directly (the page-level `BlocListener` forwards the
/// new volume to the active [VideoFeedController]) so the toggle works even
/// when no controller is mounted yet.
class _AudioToggle extends StatelessWidget {
  const _AudioToggle();

  @override
  Widget build(BuildContext context) {
    final isMuted = context.select(
      (VideoVolumeCubit c) => c.state.volume == 0,
    );
    return _PopoverToggle(
      isOn: isMuted,
      semanticLabel: isMuted
          ? context.l10n.videoPlayerUnmute
          : context.l10n.videoPlayerMute,
      onTap: () {
        context.read<VideoVolumeCubit>().onPlaybackVolumeChanged(
          isMuted ? 1 : 0,
        );
        SemanticsService.sendAnnouncement(
          View.of(context),
          isMuted
              ? context.l10n.videoPlayerUnmute
              : context.l10n.videoPlayerMute,
          Directionality.of(context),
        );
      },
      child: DivineIcon(
        icon: isMuted
            ? DivineIconName.speakerSimpleSlash
            : DivineIconName.speakerSimpleHigh,
        color: VineTheme.onSurface,
      ),
    );
  }
}

/// Closed-captions toggle. Active state means subtitles are visible.
class _CaptionsToggle extends ConsumerWidget {
  const _CaptionsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(subtitleVisibilityProvider);
    return _PopoverToggle(
      isOn: enabled,
      semanticLabel: enabled
          ? context.l10n.videoSettingsCaptionsDisable
          : context.l10n.videoSettingsCaptionsEnable,
      onTap: () {
        ref.read(subtitleVisibilityProvider.notifier).toggle();
      },
      child: DivineIcon(
        icon: enabled
            ? DivineIconName.closedCaptioningFill
            : DivineIconName.closedCaptioning,
        color: VineTheme.onSurface,
      ),
    );
  }
}

/// 48 px touch target wrapping a 12 px-padded scrim button (40 px visible at
/// 20 px radius). Background flips between scrim-15 (off) and scrim-65 (on).
class _PopoverToggle extends StatelessWidget {
  const _PopoverToggle({
    required this.isOn,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final bool isOn;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bg = isOn ? VineTheme.scrim50 : VineTheme.scrim15;
    return Semantics(
      button: true,
      toggled: isOn,
      label: semanticLabel,
      container: true,
      explicitChildNodes: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox.square(dimension: 24, child: child),
          ),
        ),
      ),
    );
  }
}

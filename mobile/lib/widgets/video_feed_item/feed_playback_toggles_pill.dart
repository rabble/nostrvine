// ABOUTME: Scrim-30 capsule with three playback toggles
// ABOUTME: (compilations / mute / closed-captions). Rendered both as
// ABOUTME: the body of the top-bar settings popover and above the play
// ABOUTME: affordance in the paused-video overlay.

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

/// Scrim-30 backdrop-blurred capsule housing the three playback toggles:
/// auto-advance ("compilations"), audio mute, and closed-captions.
///
/// Each toggle reads and writes app-wide state directly
/// ([FeedAutoAdvanceCubit], [VideoVolumeCubit], `subtitleVisibilityProvider`),
/// so the pill takes no constructor params and works as a drop-in child of
/// any feed surface that provides those scopes.
class FeedPlaybackTogglesPill extends StatelessWidget {
  const FeedPlaybackTogglesPill({super.key});

  @override
  Widget build(BuildContext context) {
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

/// Auto-advance ("compilations") toggle. Hidden when the OS-level
/// reduced-motion preference is set — auto-advance is unavailable in
/// that state. Also hidden when no [FeedAutoAdvanceCubit] is provided
/// in the surrounding scope, so the pill can be rendered in any
/// surface without requiring callers to wire up the cubit when they
/// don't use auto-advance.
class _PlaybackModeToggle extends StatelessWidget {
  const _PlaybackModeToggle();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    final cubit = _maybeReadFeedAutoAdvanceCubit(context);
    if (cubit == null) return const SizedBox.shrink();

    return BlocSelector<FeedAutoAdvanceCubit, FeedAutoAdvanceState, bool>(
      bloc: cubit,
      selector: (state) => state.enabled,
      builder: (context, enabled) {
        return _PopoverToggle(
          isOn: enabled,
          semanticLabel: enabled
              ? context.l10n.videoActionDisableAutoAdvance
              : context.l10n.videoActionEnableAutoAdvance,
          onTap: () {
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
      },
    );
  }
}

/// Audio mute toggle. Drives [VideoVolumeCubit] directly.
class _AudioToggle extends StatelessWidget {
  const _AudioToggle();

  @override
  Widget build(BuildContext context) {
    final isMuted = context.select((VideoVolumeCubit c) => c.state.volume == 0);
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

/// 48 px touch target wrapping a 12 px-padded scrim button (40 px
/// visible at 20 px radius). Background flips between scrim-15 (off)
/// and scrim-50 (on).
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

FeedAutoAdvanceCubit? _maybeReadFeedAutoAdvanceCubit(BuildContext context) =>
    context.read<FeedAutoAdvanceCubit?>();

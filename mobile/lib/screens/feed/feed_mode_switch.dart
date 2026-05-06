// ABOUTME: Feed mode picker overlay widget for video feed
// ABOUTME: Shows current mode (For You/New/Following) with bottom sheet selection

import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Feed mode picker overlay that displays the current feed mode
/// and allows users to switch between modes via a bottom sheet.
///
/// This widget is designed to be used in a [Stack] as an overlay
/// on top of video content. It includes a gradient background
/// that fades from semi-transparent black to transparent.
class FeedModeSwitch extends StatelessWidget {
  const FeedModeSwitch({this.isPreviewMode = false, super.key});

  /// When true, displays a static "For You" label without requiring
  /// [VideoFeedBloc] or feature-flag providers in the widget tree.
  final bool isPreviewMode;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: isPreviewMode
            ? null
            : const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [VineTheme.innerShadowPressed, VineTheme.transparent],
                ),
              ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(
              top: 16,
              bottom: 16,
              left: 20,
              right: 20,
            ),
            child: isPreviewMode
                ? _FeedModeContent(
                    label: _labelForMode(FeedMode.forYou, context.l10n),
                  )
                : BlocBuilder<VideoFeedBloc, VideoFeedState>(
                    buildWhen: (prev, curr) => prev.mode != curr.mode,
                    builder: (context, state) => _FeedModeContent(
                      onTap: () =>
                          _showFeedModeBottomSheet(context, state.mode),
                      label: _labelForMode(state.mode, context.l10n),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showFeedModeBottomSheet(
    BuildContext context,
    FeedMode currentMode,
  ) async {
    final l10n = context.l10n;
    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: currentMode.name,
      options: [
        VineBottomSheetSelectionOptionData(
          label: l10n.feedModeForYou,
          value: 'forYou',
        ),
        VineBottomSheetSelectionOptionData(
          label: l10n.feedModeNew,
          value: 'latest',
        ),
        VineBottomSheetSelectionOptionData(
          label: l10n.feedModeFollowing,
          value: 'following',
        ),
      ],
    );

    if (selected != null && context.mounted) {
      final mode = FeedMode.values.firstWhere((m) => m.name == selected);
      context.read<VideoFeedBloc>().add(VideoFeedModeChanged(mode));
    }
  }
}

String _labelForMode(FeedMode mode, AppLocalizations l10n) => switch (mode) {
  FeedMode.forYou => l10n.feedModeForYou,
  FeedMode.latest => l10n.feedModeNew,
  FeedMode.following => l10n.feedModeFollowing,
};

/// Shared row rendering — label + caret — used for both the live
/// [BlocBuilder]-driven label and the static preview-mode label.
class _FeedModeContent extends StatelessWidget {
  const _FeedModeContent({required this.label, this.onTap});

  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          label: 'Feed mode: $label',
          button: true,
          child: GestureDetector(
            behavior: .opaque,
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                Text(
                  label,
                  style: VineTheme.headlineSmallFont().copyWith(
                    shadows: VineTheme.buttonShadows,
                  ),
                ),
                const _FeedModeCaret(),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

/// Caret icon with the same two drop shadows applied to the feed-mode label
/// text, so the icon matches the label's legibility over video content.
class _FeedModeCaret extends StatelessWidget {
  const _FeedModeCaret();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.center,
      children: [
        _FeedModeCaretShadow(offset: Offset(1, 1), blurSigma: 1),
        _FeedModeCaretShadow(offset: Offset(0.4, 0.4), blurSigma: 0.6),
        DivineIcon(icon: DivineIconName.caretDown, color: VineTheme.whiteText),
      ],
    );
  }
}

/// One of the two drop shadows stacked behind the real caret. Renders the
/// caret glyph tinted in the shadow color, offset, and blurred — mirrors
/// how Text `Shadow`s paint underneath glyphs.
class _FeedModeCaretShadow extends StatelessWidget {
  const _FeedModeCaretShadow({required this.offset, required this.blurSigma});

  final Offset offset;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: const DivineIcon(
          icon: DivineIconName.caretDown,
          color: VineTheme.innerShadow,
        ),
      ),
    );
  }
}

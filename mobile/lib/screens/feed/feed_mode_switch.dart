// ABOUTME: Feed mode picker overlay widget for video feed
// ABOUTME: Shows current mode (For You/New/Following) with bottom sheet selection

import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';

/// Feed mode picker overlay that displays the current feed mode
/// and allows users to switch between modes via a bottom sheet.
///
/// This widget is designed to be used in a [Stack] as an overlay
/// on top of video content. It includes a gradient background
/// that fades from semi-transparent black to transparent.
class FeedModeSwitch extends StatelessWidget {
  const FeedModeSwitch({super.key});

  /// Labels for each feed mode displayed in the UI.
  static const Map<FeedMode, String> feedModeLabels = {
    FeedMode.forYou: 'For You',
    FeedMode.latest: 'New',
    FeedMode.following: 'Following',
  };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
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
            child: BlocBuilder<VideoFeedBloc, VideoFeedState>(
              buildWhen: (prev, curr) => prev.mode != curr.mode,
              builder: (context, state) {
                return Row(
                  children: [
                    Semantics(
                      label:
                          'Feed mode: '
                          '${feedModeLabels[state.mode] ?? state.mode.name}',
                      button: true,
                      child: GestureDetector(
                        onTap: () =>
                            _showFeedModeBottomSheet(context, state.mode),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 12,
                          children: [
                            Text(
                              feedModeLabels[state.mode] ?? state.mode.name,
                              style: VineTheme.headlineSmallFont().copyWith(
                                shadows: [
                                  const Shadow(
                                    color: VineTheme.innerShadow,
                                    offset: Offset(1, 1),
                                    blurRadius: 1,
                                  ),
                                  const Shadow(
                                    color: VineTheme.innerShadow,
                                    offset: Offset(0.4, 0.4),
                                    blurRadius: 0.6,
                                  ),
                                ],
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
              },
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
    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: currentMode.name,
      options: const [
        VineBottomSheetSelectionOptionData(label: 'For You', value: 'forYou'),
        VineBottomSheetSelectionOptionData(label: 'New', value: 'latest'),
        VineBottomSheetSelectionOptionData(
          label: 'Following',
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
        DivineIcon(
          icon: DivineIconName.caretDown,
          color: VineTheme.whiteText,
        ),
      ],
    );
  }
}

/// One of the two drop shadows stacked behind the real caret. Renders the
/// caret glyph tinted in the shadow color, offset, and blurred — mirrors
/// how Text `Shadow`s paint underneath glyphs.
class _FeedModeCaretShadow extends StatelessWidget {
  const _FeedModeCaretShadow({
    required this.offset,
    required this.blurSigma,
  });

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

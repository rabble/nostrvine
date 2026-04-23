// ABOUTME: Feed mode picker overlay widget for video feed
// ABOUTME: Shows current mode (For You/New/Following) with bottom sheet selection

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
  const FeedModeSwitch({this.isPreviewMode = false, super.key});

  /// When true, displays a static "For You" label without requiring
  /// [VideoFeedBloc] or feature-flag providers in the widget tree.
  final bool isPreviewMode;

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
              top: 8,
              bottom: 16,
              left: 20,
              right: 20,
            ),
            child: isPreviewMode
                ? _PreviewContent(
                    label:
                        feedModeLabels[FeedMode.forYou] ?? FeedMode.forYou.name,
                  )
                : BlocBuilder<VideoFeedBloc, VideoFeedState>(
                    buildWhen: (prev, curr) => prev.mode != curr.mode,
                    builder: (context, state) => _PreviewContent(
                      onTap: () =>
                          _showFeedModeBottomSheet(context, state.mode),
                      label: feedModeLabels[state.mode] ?? state.mode.name,
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

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.label, this.onTap});

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
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                Text(
                  label,
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
                const DivineIcon(icon: .caretDown, color: VineTheme.whiteText),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

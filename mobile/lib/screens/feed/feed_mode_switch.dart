// ABOUTME: Feed mode picker overlay widget for video feed
// ABOUTME: Shows current mode (For You/New/Following) with bottom sheet selection

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

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
              top: 8,
              bottom: 16,
              left: 20,
              right: 20,
            ),
            child: BlocBuilder<VideoFeedBloc, VideoFeedState>(
              buildWhen: (prev, curr) => prev.mode != curr.mode,
              builder: (context, state) {
                return Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: () =>
                              _showFeedModeBottomSheet(context, state.mode),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                              const SizedBox(width: 12),
                              SvgPicture.asset(
                                DivineIconName.caretDown.assetPath,
                                width: 24,
                                height: 24,
                                colorFilter: const ColorFilter.mode(
                                  VineTheme.whiteText,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _SearchButton(
                      onTap: () =>
                          context.pushWithVideoPause(SearchScreenPure.path),
                    ),
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

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DiVineAppBarIconButton(
      icon: SvgIconSource(DivineIconName.search.assetPath),
      onPressed: onTap,
      iconSize: 24,
      semanticLabel: 'Search',
      backgroundColor: VineTheme.scrim30,
    );
  }
}

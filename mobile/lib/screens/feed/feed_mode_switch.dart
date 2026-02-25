// ABOUTME: Feed mode picker overlay widget for video feed
// ABOUTME: Shows current mode (New/Popular/Following) with bottom sheet selection

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';

/// Feed mode picker overlay that displays the current feed mode
/// and allows users to switch between modes via a bottom sheet.
///
/// This widget is designed to be used in a [Stack] as an overlay
/// on top of video content. It includes a gradient background
/// that fades from semi-transparent black to transparent.
class FeedModeSwitch extends StatelessWidget {
  const FeedModeSwitch({super.key});

  /// Labels for each feed mode displayed in the UI.
  static const feedModeLabels = {
    FeedMode.forYou: 'For You',
    FeedMode.latest: 'New',
    FeedMode.popular: 'Popular',
    FeedMode.home: 'Following',
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
            colors: [
              Color(0x3D000000), // rgba(0,0,0,0.24)
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(
              top: 18,
              bottom: 16,
              left: 20,
              right: 20,
            ),
            child: BlocBuilder<VideoFeedBloc, VideoFeedState>(
              buildWhen: (prev, curr) => prev.mode != curr.mode,
              builder: (context, state) {
                return Row(
                  children: [
                    _MenuButton(onTap: () => Scaffold.of(context).openDrawer()),
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
                                      color: Color(0x1A000000),
                                      offset: Offset(1, 1),
                                      blurRadius: 1,
                                    ),
                                    const Shadow(
                                      color: Color(0x1A000000),
                                      offset: Offset(0.4, 0.4),
                                      blurRadius: 0.6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SvgPicture.asset(
                                'assets/icon/CaretDown.svg',
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
                      onTap: () => context.push(SearchScreenPure.path),
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
        VineBottomSheetSelectionOptionData(label: 'Popular', value: 'popular'),
        VineBottomSheetSelectionOptionData(label: 'Following', value: 'home'),
      ],
    );

    if (selected != null && context.mounted) {
      final mode = FeedMode.values.firstWhere((m) => m.name == selected);
      context.read<VideoFeedBloc>().add(VideoFeedModeChanged(mode));
    }
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DiVineAppBarIconButton(
      icon: const SvgIconSource('assets/icon/menu.svg'),
      onPressed: onTap,
      iconSize: 24,
      semanticLabel: 'Open menu',
      backgroundColor: VineTheme.scrim30,
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DiVineAppBarIconButton(
      icon: const SvgIconSource('assets/icon/search.svg'),
      onPressed: onTap,
      iconSize: 24,
      semanticLabel: 'Search',
      backgroundColor: VineTheme.scrim30,
    );
  }
}

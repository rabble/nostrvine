// ABOUTME: Top-of-page hashtag line for Following feed (step 6 UX).
// ABOUTME: Sits under [FeedModeSwitch], tracks scroll via [pagePosition].

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';

/// Single-line label for followed-hashtag attribution (matches chip cap: 2 + N).
String followingHashtagTitleForLabels(Set<String> labels) {
  if (labels.isEmpty) return '';
  final sorted = labels.toList()..sort();
  final shown = sorted.take(2).map(formatHashtagForDisplay).join(' ');
  final extra = sorted.length - 2;
  if (extra <= 0) return shown;
  return '$shown +$extra';
}

/// Distance from the top of the screen to the first line under the status bar
/// where the feed mode label ends (see [FeedModeSwitch] padding + text).
double _followingHashtagTitleTop(BuildContext context) {
  final safeTop = MediaQuery.viewPaddingOf(context).top;
  const modePaddingTop = 8.0;
  const modeLineHeight = 28.0;
  const gapBeforeHashtag = 6.0;
  return safeTop + modePaddingTop + modeLineHeight + gapBeforeHashtag;
}

/// Pinned title for the active Following clip's hashtag source(s).
class FollowingHashtagPageTitle extends StatelessWidget {
  const FollowingHashtagPageTitle({required this.pagePosition, super.key});

  final ValueListenable<double> pagePosition;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoFeedBloc, VideoFeedState>(
      buildWhen: (prev, curr) =>
          prev.mode != curr.mode ||
          prev.videos != curr.videos ||
          prev.videoHashtagSources != curr.videoHashtagSources,
      builder: (context, state) {
        return ValueListenableBuilder<double>(
          valueListenable: pagePosition,
          builder: (context, page, _) {
            if (state.mode != FeedMode.following || state.videos.isEmpty) {
              return const SizedBox.shrink();
            }
            final idx = page.round().clamp(0, state.videos.length - 1);
            final labels = state.videoHashtagSources[state.videos[idx].id];
            if (labels == null || labels.isEmpty) {
              return const SizedBox.shrink();
            }
            final titleText = followingHashtagTitleForLabels(labels);
            if (titleText.isEmpty) return const SizedBox.shrink();

            final sorted = labels.toList()..sort();
            final navigateLabel = sorted.first;

            return Positioned(
              left: 16,
              right: 16,
              top: _followingHashtagTitleTop(context),
              child: Align(
                alignment: Alignment.topCenter,
                child: Semantics(
                  button: true,
                  label: 'Open hashtag feed for $titleText',
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => context.push(
                        HashtagScreenRouter.pathForTag(navigateLabel),
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: VineTheme.titleMediumFont().copyWith(
                            color: VineTheme.vineGreen,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                color: VineTheme.innerShadow,
                                offset: Offset(0.5, 0.5),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

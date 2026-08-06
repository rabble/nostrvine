// ABOUTME: Fades a chrome layer out while the feed is in immersive mode.
// ABOUTME: Wraps the feed-mode header, the fullscreen app bar, and the
// ABOUTME: per-item overlay so they all disappear on the same signal.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';

/// How long the chrome takes to fade out and back in.
///
/// Short enough that releasing feels immediate, long enough that the chrome
/// doesn't pop.
const Duration kFeedImmersiveFadeDuration = Duration(milliseconds: 180);

/// Hides [child] while [FeedImmersiveCubit] reports immersive viewing.
///
/// The cubit is looked up nullably, so surfaces that render feed chrome
/// outside a feed page — the video-editor preview's [FeedModeSwitch], widget
/// tests pumping a single overlay — simply never go immersive instead of
/// throwing for a missing provider.
///
/// [child] is passed through untouched on every rebuild, so a fade toggle
/// re-runs only this widget's build, not the (expensive) chrome subtree.
class FeedImmersiveChrome extends StatelessWidget {
  const FeedImmersiveChrome({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isImmersive = context.select<FeedImmersiveCubit?, bool>(
      (cubit) => cubit?.state.isImmersive ?? false,
    );
    return IgnorePointer(
      ignoring: isImmersive,
      child: AnimatedOpacity(
        opacity: isImmersive ? 0.0 : 1.0,
        // Reduced motion gets the same end state without the cross-fade.
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : kFeedImmersiveFadeDuration,
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

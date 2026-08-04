// ABOUTME: Grows late-arriving content into place instead of snapping it in.
// ABOUTME: A null child is the empty state, keeping the box mounted at 0 high.

import 'package:flutter/material.dart';

/// Reveals content that arrives after its surroundings have painted.
///
/// Asynchronous data — a relay round-trip, a profile fetch, a confirmation
/// status — lands on an already-painted screen. Swapping an empty box for the
/// finished widget in a single frame shoves everything below it down. This
/// grows the box into place instead, so its siblings slide rather than jump:
///
/// ```dart
/// AnimatedReveal(
///   child: reposters.isEmpty ? null : RepostersRow(reposters),
/// )
/// ```
///
/// A null [child] is the empty state. Keep this widget mounted while empty
/// rather than dropping it from the tree behind a conditional — one that only
/// appears together with its content mounts at its final size and has nothing
/// to animate from.
///
/// The empty state spans the full available width so only the height
/// animates. Honours [MediaQueryData.disableAnimations].
class AnimatedReveal extends StatelessWidget {
  /// Creates an [AnimatedReveal].
  const AnimatedReveal({
    this.child,
    this.duration = _defaultDuration,
    super.key,
  });

  static const _defaultDuration = Duration(milliseconds: 220);

  /// The content to reveal, or null while there is nothing to show.
  final Widget? child;

  /// How long the reveal takes.
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox(width: .infinity);
    // Drop the animators entirely under reduce motion rather than passing them
    // Duration.zero: a zero-duration AnimatedSize completes its controller
    // synchronously inside performLayout, which re-dirties the render object
    // mid-layout and trips a framework assertion.
    if (MediaQuery.disableAnimationsOf(context)) return content;

    // AnimatedSwitcher alone would not do: it stacks the outgoing and incoming
    // child and adopts the larger size at once, fading the content in while
    // the layout still jumps. The height has to come from AnimatedSize.
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(duration: duration, child: content),
    );
  }
}

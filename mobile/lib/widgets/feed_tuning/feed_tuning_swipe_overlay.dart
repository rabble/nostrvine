import 'package:divine_ui/divine_ui.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:openvine/l10n/l10n.dart';

/// Horizontal-swipe detector over the fullscreen feed that lets the user tune
/// recommendations: swipe right = "more like this", swipe left = "less like
/// this".
///
/// A committing swipe fires [onTuned]; the parent publishes the signal and
/// pages the feed forward. The child follows the finger and a directional
/// indicator brightens with drag progress; crossing [commitThreshold] fires a
/// haptic tick. Releasing before the threshold snaps back and does nothing.
/// Screen-reader users get the same two actions via custom semantic actions.
class FeedTuningSwipeOverlay extends StatefulWidget {
  /// Creates a swipe-to-tune overlay around [child].
  const FeedTuningSwipeOverlay({
    required this.onTuned,
    required this.child,
    this.commitThreshold = 96,
    super.key,
  });

  /// Called when a swipe commits past [commitThreshold].
  final ValueChanged<FeedTuningDirection> onTuned;

  /// The feed content the gesture wraps.
  final Widget child;

  /// Horizontal drag distance (logical pixels) needed to commit a tune.
  final double commitThreshold;

  @override
  State<FeedTuningSwipeOverlay> createState() => _FeedTuningSwipeOverlayState();
}

class _FeedTuningSwipeOverlayState extends State<FeedTuningSwipeOverlay> {
  double _dragExtent = 0;
  bool _passedThreshold = false;

  double get _progress =>
      (_dragExtent.abs() / widget.commitThreshold).clamp(0.0, 1.0);

  FeedTuningDirection? get _direction {
    if (_dragExtent == 0) return null;
    return _dragExtent > 0
        ? FeedTuningDirection.more
        : FeedTuningDirection.less;
  }

  void _onUpdate(DragUpdateDetails details) {
    setState(() => _dragExtent += details.delta.dx);
    final passed = _dragExtent.abs() >= widget.commitThreshold;
    if (passed && !_passedThreshold) {
      HapticFeedback.selectionClick();
    }
    _passedThreshold = passed;
  }

  void _onEnd(DragEndDetails details) {
    final direction = _direction;
    final committed = _passedThreshold && direction != null;
    _reset();
    if (committed) widget.onTuned(direction);
  }

  void _reset() {
    setState(() {
      _dragExtent = 0;
      _passedThreshold = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final direction = _direction;
    return Semantics(
      container: true,
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: l10n.feedTuningMoreLabel): () =>
            widget.onTuned(FeedTuningDirection.more),
        CustomSemanticsAction(label: l10n.feedTuningLessLabel): () =>
            widget.onTuned(FeedTuningDirection.less),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: _onUpdate,
        onHorizontalDragEnd: _onEnd,
        onHorizontalDragCancel: _reset,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Transform.translate(
              offset: Offset(_dragExtent * 0.4, 0),
              child: widget.child,
            ),
            if (direction != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: _TuningIndicator(
                    direction: direction,
                    progress: _progress,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gates [FeedTuningSwipeOverlay] behind a feature flag.
///
/// When [enabled] is false the [child] is returned untouched — no gesture, no
/// indicator, no overlay — so the feed behaves exactly as before. The screen
/// drives [enabled] from `isFeatureEnabledProvider(FeatureFlag.feedTuning)`,
/// which is off by default until the relay and recommendation backend ship.
class FeedTuningSwipeGate extends StatelessWidget {
  /// Creates a feature-gated swipe-to-tune wrapper around [child].
  const FeedTuningSwipeGate({
    required this.enabled,
    required this.onTuned,
    required this.child,
    super.key,
  });

  /// Whether the swipe-to-tune gesture is active.
  final bool enabled;

  /// Called when a swipe commits past the threshold.
  final ValueChanged<FeedTuningDirection> onTuned;

  /// The feed content the gesture wraps when [enabled].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return FeedTuningSwipeOverlay(onTuned: onTuned, child: child);
  }
}

class _TuningIndicator extends StatelessWidget {
  const _TuningIndicator({required this.direction, required this.progress});

  final FeedTuningDirection direction;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isMore = direction == FeedTuningDirection.more;
    final color = isMore ? VineTheme.vineGreen : VineTheme.onSurfaceMuted;
    final label = isMore ? l10n.feedTuningMoreLabel : l10n.feedTuningLessLabel;
    final icon = isMore ? DivineIconName.arrowUp : DivineIconName.arrowDown;

    return Align(
      alignment: isMore ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Opacity(
          opacity: progress,
          child: Transform.scale(
            scale: 0.8 + 0.2 * progress,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: VineTheme.surfaceContainerHigh.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DivineIcon(icon: icon, color: color, size: 28),
                    const SizedBox(height: 4),
                    Text(label, style: VineTheme.labelLargeFont(color: color)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ABOUTME: Animated heart overlay shown on double-tap-to-like gesture.
// ABOUTME: Uses AnimationController with Interval-based scale and opacity
// ABOUTME: animations. Triggered via a Listenable (typically ValueNotifier).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Animation durations for the double-tap heart.
abstract class _HeartAnimation {
  static const totalDuration = Duration(milliseconds: 1000);

  /// Scale animates from 0 to 1 in the first 25% of the timeline.
  static const scaleEnd = 0.25;

  /// Opacity begins fading at 60% and reaches 0 at 100%.
  static const fadeStart = 0.6;
}

/// Animated heart overlay that appears on double-tap-to-like.
///
/// Listens to [trigger] and starts a scale-up + fade-out animation each time
/// the trigger notifies. Wraps itself in [IgnorePointer] so it never consumes
/// tap events.
class DoubleTapHeartOverlay extends StatefulWidget {
  const DoubleTapHeartOverlay({required this.trigger, super.key});

  /// A [Listenable] that triggers the animation when it notifies.
  ///
  /// Typically a `ValueNotifier<int>` incremented on each double-tap.
  final Listenable trigger;

  @override
  State<DoubleTapHeartOverlay> createState() => _DoubleTapHeartOverlayState();
}

class _DoubleTapHeartOverlayState extends State<DoubleTapHeartOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  bool _visible = false;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
          vsync: this,
          duration: _HeartAnimation.totalDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() => _visible = false);
          }
        });

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0,
          _HeartAnimation.scaleEnd,
          curve: Curves.elasticOut,
        ),
      ),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: _HeartAnimation.fadeStart * 100,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: (1 - _HeartAnimation.fadeStart) * 100,
      ),
    ]).animate(_controller);

    widget.trigger.addListener(_onTrigger);
  }

  @override
  void didUpdateWidget(covariant DoubleTapHeartOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger.removeListener(_onTrigger);
      widget.trigger.addListener(_onTrigger);
    }
  }

  void _onTrigger() {
    setState(() => _visible = true);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_onTrigger);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          if (!_visible) return const SizedBox.shrink();
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          );
        },
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: VineTheme.backgroundColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SvgPicture.asset(
              DivineIconName.heartDuo.assetPath,
              width: 120,
              height: 120,
              colorFilter: const ColorFilter.mode(
                VineTheme.whiteText,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

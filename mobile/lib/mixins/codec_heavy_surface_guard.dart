// ABOUTME: State mixin asserting the codec-heavy-surface signal after the
// ABOUTME: entrance transition, so background feeds aren't disposed mid-animation.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/codec_heavy_surface/codec_heavy_surface_cubit.dart';

/// Mixin for codec-heavy screens (camera, video editor, exporter) that asserts
/// [CodecHeavySurfaceCubit] while they are on screen so background feeds release
/// the device's scarce hardware decoders.
///
/// The signal is asserted only **after** the screen's entrance transition
/// completes. Asserting it in `initState` drains background feeds while the push
/// animation is still running, so the previous screen's video visibly
/// disappears behind the incoming one. Waiting for the transition keeps that
/// frame on screen until the new screen fully covers it.
///
/// The matching release fires in `dispose`, but only if the signal was actually
/// asserted — a screen popped mid-transition never entered, so it must not exit
/// (that would leave the reference count unbalanced).
///
/// The cubit is looked up nullably: it is an app-level optimization, so a screen
/// mounted in an isolated/test tree without it simply becomes a no-op.
mixin CodecHeavySurfaceGuard<T extends StatefulWidget> on State<T> {
  CodecHeavySurfaceCubit? _codecHeavySurfaceCubit;
  Animation<double>? _entranceAnimation;
  bool _entered = false;

  /// Whether to wait for the entrance transition before asserting the signal.
  ///
  /// `true` (default) keeps the previous screen's video frame visible during
  /// the push animation. Correct for the **camera**, which does not allocate a
  /// video decoder on open — the preview uses the camera pipeline and the
  /// encoder is created only when recording starts — so there is no codec
  /// contention to race.
  ///
  /// Override to `false` for a surface that allocates a hardware **decoder**
  /// immediately on mount: the **video editor** builds its preview player in
  /// `initState`/the first post-frame, so the background feed must hand back its
  /// decoder before that new one is created — even at the cost of a brief frame
  /// drop behind the incoming screen.
  bool get assertCodecSignalAfterEntranceTransition => true;

  @override
  void initState() {
    super.initState();
    _codecHeavySurfaceCubit = context.read<CodecHeavySurfaceCubit?>();
    if (!assertCodecSignalAfterEntranceTransition) {
      _enterCodecHeavySurface();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _armAfterEntrance();
    });
  }

  void _armAfterEntrance() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _enterCodecHeavySurface();
      return;
    }
    _entranceAnimation = animation..addStatusListener(_onEntranceStatus);
  }

  void _onEntranceStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _detachEntranceListener();
    if (mounted) _enterCodecHeavySurface();
  }

  void _enterCodecHeavySurface() {
    if (_entered) return;
    _entered = true;
    _codecHeavySurfaceCubit?.enter();
  }

  void _detachEntranceListener() {
    _entranceAnimation?.removeStatusListener(_onEntranceStatus);
    _entranceAnimation = null;
  }

  @override
  void dispose() {
    _detachEntranceListener();
    if (_entered) _codecHeavySurfaceCubit?.exit();
    super.dispose();
  }
}

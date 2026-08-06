// ABOUTME: Feed-scoped state for immersive (hold-to-peek) video viewing.
// ABOUTME: While held, every chrome layer over the video fades out so the
// ABOUTME: frame can be seen unobstructed; releasing brings it straight back.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Feed-scoped runtime state for immersive viewing.
///
/// Owned per feed surface (home feed page / fullscreen feed) and provided
/// down the tree via `BlocProvider`, so the page-level chrome (feed mode
/// header, app bar) and the per-item overlay chrome all fade against the
/// same signal.
class FeedImmersiveState extends Equatable {
  const FeedImmersiveState({this.isImmersive = false});

  /// Whether the chrome over the video is currently hidden.
  final bool isImmersive;

  @override
  List<Object?> get props => [isImmersive];
}

/// Feed-scoped Cubit that owns the immersive-viewing flag.
///
/// The flag is transient by design — it is raised while the viewer holds a
/// finger on the video and lowered the moment they let go, so it is never
/// persisted and never survives leaving the feed.
class FeedImmersiveCubit extends Cubit<FeedImmersiveState> {
  FeedImmersiveCubit() : super(const FeedImmersiveState());

  /// Hides the chrome. Idempotent, so the several exit paths that guard
  /// against a stuck overlay can all call it unconditionally.
  void enter() {
    if (state.isImmersive) return;
    emit(const FeedImmersiveState(isImmersive: true));
  }

  /// Restores the chrome. Idempotent — see [enter].
  void exit() {
    if (!state.isImmersive) return;
    emit(const FeedImmersiveState());
  }
}

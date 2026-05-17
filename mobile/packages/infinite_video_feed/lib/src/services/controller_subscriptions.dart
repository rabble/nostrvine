import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';

/// Bundles the four state-stream subscriptions the feed maintains per
/// active player controller (errors, loop enforcement, auto-advance loop
/// detection, dimensions).
///
/// Each `subscribeTo*` call cancels any prior subscription of the same
/// kind for that index. [unsubscribe] cancels all four for one index;
/// [disposeAll] cancels every subscription.
class ControllerSubscriptions {
  final _dimensions = <int, StreamSubscription<DivineVideoPlayerState>>{};
  final _errors = <int, StreamSubscription<DivineVideoPlayerState>>{};
  final _loop = <int, StreamSubscription<DivineVideoPlayerState>>{};
  final _autoAdvance = <int, StreamSubscription<DivineVideoPlayerState>>{};

  /// Subscribes to runtime playback errors. Calls [onError] with the
  /// structured [NativePlayerErrorCode] and raw message (both nullable) the
  /// first time the controller reports `state.hasError`, unless
  /// [isAlreadyError] returns `true` (the index is already in error state).
  void subscribeToPlaybackErrors(
    int index,
    DivineVideoPlayerController controller, {
    required bool Function() isAlreadyError,
    required void Function(
      NativePlayerErrorCode? errorCode,
      String? errorMessage,
    )
    onError,
  }) {
    unawaited(_errors[index]?.cancel());
    _errors[index] = controller.stateStream.listen((state) {
      if (!state.hasError || isAlreadyError()) return;
      onError(state.errorCode, state.errorMessage);
    });
  }

  /// Subscribes to loop enforcement: when the active video crosses
  /// [maxLoopDuration] while playing, [onSeekToZero] is invoked. The
  /// caller is responsible for guarding against repeated triggers
  /// (`isSeekInProgress`/`onSeekStarted`/`onSeekFinished`).
  void subscribeToLoopEnforcement(
    int index,
    DivineVideoPlayerController controller, {
    required Duration maxLoopDuration,
    required bool Function() isCurrent,
    required bool Function() isSeekInProgress,
    required void Function() onSeekStarted,
    required void Function() onPositionBelowMax,
    required void Function() onSeekToZero,
  }) {
    unawaited(_loop[index]?.cancel());
    _loop[index] = controller.stateStream.listen((state) {
      if (!isCurrent()) return;

      if (state.position < maxLoopDuration) {
        onPositionBelowMax();
        return;
      }

      if (!state.isPlaying || isSeekInProgress()) return;

      onSeekStarted();
      onSeekToZero();
    });
  }

  /// Subscribes to loop-completion detection. Fires [onLoopCompleted] when
  /// the playback position resets from near the effective end (min of
  /// [maxLoopDuration] and the natural duration) back to near zero.
  ///
  /// [endThreshold] / [startThreshold] define the windows for "near end"
  /// and "near start".
  void subscribeToAutoAdvance(
    int index,
    DivineVideoPlayerController controller, {
    required Duration? maxLoopDuration,
    required Duration endThreshold,
    required Duration startThreshold,
    required bool Function() isCurrent,
    required void Function() onLoopCompleted,
  }) {
    unawaited(_autoAdvance[index]?.cancel());

    final initialState = controller.state;
    var armed = false;
    var lastPosition = initialState.position;

    Duration? effectiveEnd;
    final initialDuration = initialState.duration;
    if (initialDuration > Duration.zero) {
      effectiveEnd =
          (maxLoopDuration != null && maxLoopDuration < initialDuration)
          ? maxLoopDuration
          : initialDuration;
    } else if (maxLoopDuration != null) {
      effectiveEnd = maxLoopDuration;
    }
    if (isCurrent() &&
        initialState.isPlaying &&
        effectiveEnd != null &&
        effectiveEnd > Duration.zero &&
        lastPosition >= effectiveEnd - endThreshold) {
      armed = true;
    }

    _autoAdvance[index] = controller.stateStream.listen((state) {
      if (!isCurrent() || !state.isPlaying) return;

      final position = state.position;
      final duration = state.duration;

      Duration? effectiveEnd;
      if (duration > Duration.zero) {
        effectiveEnd = (maxLoopDuration != null && maxLoopDuration < duration)
            ? maxLoopDuration
            : duration;
      } else if (maxLoopDuration != null) {
        effectiveEnd = maxLoopDuration;
      }

      if (effectiveEnd != null && effectiveEnd > Duration.zero) {
        if (position >= effectiveEnd - endThreshold) {
          armed = true;
        }
      }

      if (armed && position <= startThreshold && lastPosition > position) {
        armed = false;
        onLoopCompleted();
      }

      lastPosition = position;
    });
  }

  /// Subscribes to the first dimension report (videoWidth/Height > 0) and
  /// auto-cancels itself once dimensions are known. Calls
  /// [onDimensionsReady] once.
  ///
  /// If dimensions are already known on subscribe (e.g. a reused
  /// controller), [onDimensionsReady] fires synchronously and no
  /// stream subscription is created.
  void subscribeToDimensions(
    int index,
    DivineVideoPlayerController controller, {
    required void Function() onDimensionsReady,
  }) {
    final s = controller.state;
    if (s.videoWidth > 0 && s.videoHeight > 0) {
      onDimensionsReady();
      return;
    }

    unawaited(_dimensions[index]?.cancel());
    _dimensions[index] = controller.stateStream.listen((state) {
      if (state.videoWidth > 0 && state.videoHeight > 0) {
        unawaited(_dimensions.remove(index)?.cancel());
        onDimensionsReady();
      }
    });
  }

  /// Cancels all four subscriptions for [index].
  void unsubscribe(int index) {
    unawaited(_dimensions.remove(index)?.cancel());
    unawaited(_errors.remove(index)?.cancel());
    unawaited(_loop.remove(index)?.cancel());
    unawaited(_autoAdvance.remove(index)?.cancel());
  }

  /// Cancels every subscription. Safe to call from `State.dispose`.
  void disposeAll() {
    for (final s in _dimensions.values) {
      unawaited(s.cancel());
    }
    _dimensions.clear();
    for (final s in _errors.values) {
      unawaited(s.cancel());
    }
    _errors.clear();
    for (final s in _loop.values) {
      unawaited(s.cancel());
    }
    _loop.clear();
    for (final s in _autoAdvance.values) {
      unawaited(s.cancel());
    }
    _autoAdvance.clear();
  }
}
